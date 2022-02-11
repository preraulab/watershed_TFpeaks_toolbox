function [SO_resized, freqcbins_resize, SO_cbins_resize, TIB] = rebin_histogram(hist_data, TIB_data, freq_cbins, SO_cbins, freq_binsizestep, ...
                                                                           SO_binsizestep, SOtype, conv_type, ispartial, isrepeating, TIB_req)
% Takes in SOpow/phase histogram data and rebins to specified bin size and step
%
% Inputs:
%       hist_data:        MxNxP 3D double - [freq, SO_feature, num_subjs]
%                         histogram data to rebin.  --required
%       TIB_data:         NxP 2D double - [SO_feature, num_subjs] Sleep time spent in each 
%                         SO_feature bin --required
%       freq_cbins:       double vector - frequency bin centers for hist_data.
%                         Must be same size as M in hist_data. --required
%       SO_cbins:         double vector - SO feature bin centers for hist_data.
%                         Must be same size as N in hist_data. --required
%       freq_binsizestep: 1x2 double - 
%       SO_binsizestep:   1x2 double - 
%       SOtype:           char - 'power' or 'phase' indicating default
%                         params for rebinning (conv_type, isrepeating, TIB_req)
%       conv_type:        integer or char - indicates the convolution padding
%                         options. Integer indicates number of 0s to pad with. 'circular' 
%                         indicates bins wrap around. Default = 0 for
%                         'power' and default = 'circular' for 'phase'
%       ispartial:        logical - indicates whether combined bins in columns of
%                         hist_data can be partial. Default = true
%       isrepeating:      logical - indicates whether the first and last columns
%                         of SO_resized should be the same/repeated to show circularity of 
%                         bins. Default = false for 'power' and default =
%                         true for 'phase'
%       TIB_req:          double - minutes required in each y bin. Y bins with <
%                         TIB_req minutes will be tured to NaNs. Default =
%                         1 for 'power' and default = 0 for 'phase'
%
% Outputs:
%       SO_resized:       PxAxB 3D double - [num_subjs, new freqs, new SO_feature] rebinned histograms
%       freqcbins_resize: double vector - new frequency bin centers for SO_resized
%       SO_cbins_resize:  double vector - new SO_feature bin centers for SO_resized
%       TIB:              NxP 2D double - [new_SO_feature, num_subjs] Time spent in each SO_feature 
%                                         bin (minutes).
%
%   Copyright 2020 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%   Last modified:
%       - Created - Tom Possidente 1/03/2022
%%%************************************************************************************%%%


%% Deal with Inputs
assert(nargin >= 7, '7 arguments required (hist_data, TIB_data, freq_cbins, SO_cbins, freq_binsizestep, SO_binsizestep, SOtype)');

switch lower(SOtype)
    case {'pow', 'power'}
        if nargin < 8 || isempty(conv_type)
            conv_type = 0;
        end
        
        if nargin < 9 || isempty(ispartial)
            ispartial = true;
        end
        
        if nargin < 10 || isempty(isrepeating)
            isrepeating = false;
        end
        
        if nargin < 11 || isempty(TIB_req)
            TIB_req = 1;
        end
        
    case {'phase'}
        if nargin < 8 || isempty(conv_type)
            conv_type = 'circular';
        end
        
        if nargin < 9 || isempty(ispartial)
            ispartial = true;
        end
        
        if nargin < 10 || isempty(isrepeating)
            isrepeating = true;
        end
        
        if nargin < 11 || isempty(TIB_req)
            TIB_req = 0;
        end
        
    otherwise
        error('SOtype not recognized')
end

%% Calc small bin sizes
freq_smallbinsize = freq_cbins(2) - freq_cbins(1);
SO_smallbinsize = SO_cbins(2) - SO_cbins(1);

%% Make sure bin sizes and binsteps are divisible by small bin size
assert( all(round(mod(freq_binsizestep, freq_smallbinsize),6) == 0),  ['frequency bin size and bin step need to be divisible by ', num2str(freq_smallbinsize)] )
assert( all(round(mod(SO_binsizestep, SO_smallbinsize),6) == 0),  ['SO bin size and bin step need to be divisible by ', num2str(SO_smallbinsize)] )

%% Calculate number of bins to combine and number of bins to skip
freq_ncomb = round(freq_binsizestep(1) / freq_smallbinsize, 6);
freq_nskip = round(freq_binsizestep(2) / freq_smallbinsize, 6);

SO_ncomb = round(SO_binsizestep(1) / SO_smallbinsize, 6);
SO_nskip = round(SO_binsizestep(2) / SO_smallbinsize, 6);

%% Calculate output shape of hist
N_subj = size(hist_data,3);

if ispartial
    col_start = SO_ncomb;
    row_start = freq_ncomb;
    col_end = length(SO_cbins);
    row_end = length(freq_cbins);
    col_skip = SO_nskip;
    row_skip = freq_nskip;
    
    if mod(SO_ncomb,2)
        col_end = col_end + floor(SO_ncomb/2);
        col_start = col_start - ceil(SO_ncomb/2);
    else
        col_end = col_end + SO_ncomb/2;
        col_start = col_start - SO_ncomb/2;
    end
        
    if mod(freq_ncomb,2)
        row_end = row_end + floor(freq_ncomb/2);
        row_start = row_start - ceil(freq_ncomb/2);
    else
        row_end = (row_end + freq_ncomb/2) - 1;
        row_start = row_start - freq_ncomb/2;
    end
    
    if ~isrepeating
        col_end = col_end - 1;
    end

    if ispartial
        if SO_nskip~=1
            col_inds = sort(unique([SO_ncomb:-SO_nskip:col_start, SO_ncomb:SO_nskip:col_end]));
        else
            col_inds = col_start:col_skip:col_end;
        end
        
        if freq_nskip~=1
            row_inds = sort(unique([freq_ncomb:-freq_nskip:row_start, freq_ncomb:freq_nskip:row_end]));
        else
            row_inds = col_start:row_skip:row_end;
        end
    end

    SO_resized = nan(N_subj, length(row_inds), length(col_inds));
    
end


%% Resize hist data

TIB = nan(N_subj, 5, length(col_inds));

% Loop through and resize
for ii = 1:N_subj
    
    % Resize SO hists and get rates 
    [~, hist_rates, SO_TIB_out, freqcbins_resize, SO_cbins_resize] = SOhist_conv(hist_data(:,:,ii), squeeze(TIB_data(ii,:,:))', freq_cbins, ...
                                                                                   SO_cbins, [freq_ncomb, SO_ncomb], [freq_nskip, SO_nskip],...
                                                                                   conv_type, ispartial, isrepeating, TIB_req, false);
    SO_resized(ii,:,:) = hist_rates;
    TIB(ii,:,:) = SO_TIB_out;
    
    % Normalize SOphase
    if strcmpi(SOtype, 'phase')
        SO_resized(ii,:,:) = squeeze(SO_resized(ii,:,:)) ./ sum(squeeze(SO_resized(ii,:,:)),2);
    end
end



end
