function [SO_resized, SOpow_resize_counts, freqcbins_resize, SO_cbins_resize, TIB] = rebin_histogram(hist_data, TIB_data,...
                                    freq_cbins, SO_cbins, freq_binsizestep,SO_binsizestep, SOtype, freq_smallbinsizestep,...
                                    SO_smallbinsizestep, SOpow_col_norm, conv_type, ispartial, isrepeating, edge_correct, TIB_req)

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
%       freq_binsizestep: 1x2 double - [binsize, binstep] - desired frequency bin size and 
%                         bin step --required
%       SO_binsizestep:   1x2 double - [binsize, binstep] - desired frequency bin size and 
%                         bin step --required
%       SOtype:           char - 'power' or 'phase' indicating default --required
%                         params for rebinning (conv_type, isrepeating, TIB_req)
%       freq_smallbinsizestep: 1x2 double - [binsize, binstep] - frequency
%                         bin size and bin step of smallbin data. Default = [0.05,0.05]
%       SO_smallbinsizestep: 1x2 double - [binsize, binstep] - SO bin size
%                         and bin step of smallbin data. Default = [0.005,0.005] for power
%                         and [(2*pi)/400, (2*pi)/400] for phase.
%       SOpow_col_norm:   logical - whether or not to normalize SOpow so that columns add 
%                         to 1. Default = false
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
%       edge_correct: logical - correct for edge effects introduced by imfilter. 
%                     Default = true
%       TIB_req:          double - minutes required in each y bin. Y bins with <
%                         TIB_req minutes will be tured to NaNs. Default =
%                         1 for 'power' and default = 0 for 'phase'
%
% Outputs:
%       SO_resized:       PxAxB 3D double - [num_subjs, new freqs, new_SO_feature] rebinned 
%                         histograms rates
%       SOpow_resize_counts: PxAxB 3D double - [num_subjs, new_freqs, new_SO_feature] rebinned 
%                            histograms counts
%       freqcbins_resize: double vector - new frequency bin centers for SO_resized
%       SO_cbins_resize:  double vector - new SO_feature bin centers for SO_resized
%       TIB:              NxP 2D double - [new_SO_feature, num_subjs] Time spent in each SO_feature 
%                                         bin (minutes).
%
%   Copyright 2022 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%
%   Authors: Thomas Possidnete, Michael Prerau
%
%   Last modified:
%       - Created - Tom Possidente 1/03/2022
%%%************************************************************************************%%%


%% Deal with Inputs
assert(nargin >= 7, '7 arguments required (hist_data, TIB_data, freq_cbins, SO_cbins, freq_binsizestep, SO_binsizestep, SOtype)');

switch lower(SOtype)
    case {'pow', 'power'}
        if nargin < 8 || isempty(freq_smallbinsizestep)
            freq_smallbinsizestep = [0.05, 0.05]; %standard freq bin size/step used in this analysis
        end
        
        if nargin < 9 || isempty(SO_smallbinsizestep)
            SO_smallbinsizestep = [0.005, 0.005]; %standard SO bin size/step used in this analysis
        end
        
        if nargin < 10 || isempty(SOpow_col_norm)
            SOpow_col_norm = false;
        end
        
        if nargin < 11 || isempty(conv_type)
            conv_type = 0;
        end
        
        if nargin < 12 || isempty(ispartial)
            ispartial = true;
        end
        
        if nargin < 13 || isempty(isrepeating)
            isrepeating = false;
        end
        
        if nargin < 14 || isempty(edge_correct)
            edge_correct = true;
        end
        
        if nargin < 15 || isempty(TIB_req)
            TIB_req = 1;
        end
        
    case {'phase'}
        if nargin < 8 || isempty(freq_smallbinsizestep)
            freq_smallbinsizestep = [0.05, 0.05]; %standard freq bin size/step used in this analysis
        end
        
        if nargin < 9 || isempty(SO_smallbinsizestep)
            SO_smallbinsizestep = [(2*pi)/400, (2*pi)/400]; %standard SO bin size/step used in this analysis
        end
        
        if nargin < 10 || isempty(SOpow_col_norm)
            SOpow_col_norm = false;
        end
        
        if nargin < 11 || isempty(conv_type)
            conv_type = 'circular';
        end
        
        if nargin < 12 || isempty(ispartial)
            ispartial = true;
        end
        
        if nargin < 13 || isempty(isrepeating)
            isrepeating = true;
        end
        
        if nargin < 14 || isempty(edge_correct)
            edge_correct = true;
        end
        
        if nargin < 15 || isempty(TIB_req)
            TIB_req = 0;
        end
        
    otherwise
        error('SOtype not recognized')
end

%% Calc small bin sizes
freq_smallbinsize_test = freq_cbins(2) - freq_cbins(1);
SO_smallbinsize_test = SO_cbins(2) - SO_cbins(1);

% Make sure inputs for small bin sizes are correct
assert(abs(freq_smallbinsize_test - freq_smallbinsizestep(1)) <= 1e-6, 'Small bin size from freq_smallbinsizestep is not the same as caluclated small bin size');
assert(abs(SO_smallbinsize_test - SO_smallbinsizestep(1)) <= 1e-6, 'Small bin size from SO_smallbinsizestep is not the same as caluclated small bin size');

%% Make sure bin sizes and binsteps are divisible by small bin size

if mod(freq_binsizestep(1), freq_smallbinsizestep(1)) ~= 0
   error('Desired frequency bin size is not divisible by small bin data binsize.')
end

if mod(freq_binsizestep(2), freq_smallbinsizestep(1)) ~= 0
   error('Desired frequency bin step is not divisible by small bin data binstep.')
end

if mod(SO_binsizestep(1), SO_smallbinsizestep(1)) ~= 0
   error('Desired SO feature bin size is not divisible by small bin data binsize.')
end

if mod(SO_binsizestep(2), SO_smallbinsizestep(1)) ~= 0
   error('Desired SO feature bin step is not divisible by small bin data binstep.')
end

%% Calculate number of bins to combine and number of bins to skip
freq_ncomb = round(freq_binsizestep(1) / freq_smallbinsizestep(1), 6);
freq_nskip = round(freq_binsizestep(2) / freq_smallbinsizestep(1), 6);

SO_ncomb = round(SO_binsizestep(1) / SO_smallbinsizestep(1), 6);
SO_nskip = round(SO_binsizestep(2) / SO_smallbinsizestep(1), 6);

%% Calculate output shape of hist for preallocation
N_subj = size(hist_data,3);

col_start = SO_ncomb;
row_start = freq_ncomb;
col_end = length(SO_cbins); 
row_end = length(freq_cbins);
col_skip = SO_nskip;
row_skip = freq_nskip;

if ispartial %if partial bins desired, add half of ncomb to end and subtract from start
    
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
    
    if ~isrepeating % if not repeating final bin at beginning, subtract a bin
        col_end = col_end - 1;
    end

    if SO_nskip~=1
        col_inds = sort(unique([SO_ncomb:-SO_nskip:col_start, SO_ncomb:SO_nskip:col_end])); % ensures that there is a bin center exactly at SO_ncomb
    else
        col_inds = col_start:col_skip:col_end;
    end

    if freq_nskip~=1
        row_inds = sort(unique([freq_ncomb:-freq_nskip:row_start, freq_ncomb:freq_nskip:row_end]));
    else
        row_inds = col_start:row_skip:row_end;
    end
    
else
    col_inds = col_start:col_skip:col_end;
    row_inds = col_start:row_skip:row_end;
end

% Finally preallocate resized hist output sizes
SO_resized = nan(N_subj, length(row_inds), length(col_inds));
SOpow_resize_counts = nan(N_subj, length(row_inds), length(col_inds));


% Initialize storage var for TIB
TIB = nan(N_subj, 5, length(col_inds));

%% Resize hist data
for ii = 1:N_subj
    
    % Resize SO hists
    [hist_counts, hist_rates, SO_TIB_out, freqcbins_resize, SO_cbins_resize] = ...
                        SOhist_conv(hist_data(:,:,ii), squeeze(TIB_data(ii,:,:))', freq_cbins, SO_cbins, ...
                        [freq_ncomb, SO_ncomb], [freq_nskip, SO_nskip], conv_type, ispartial, isrepeating, TIB_req,...
                        edge_correct, false);
    SO_resized(ii,:,:) = hist_rates;
    SOpow_resize_counts(ii,:,:) = hist_counts;
    TIB(ii,:,:) = SO_TIB_out;
    
    % Normalize
    if strcmpi(SOtype, 'phase') % if phase, always normalize rows to add to 1
        SO_resized(ii,:,:) = squeeze(SO_resized(ii,:,:)) ./ sum(squeeze(SO_resized(ii,:,:)),2);
    elseif SOpow_col_norm % if pow, and column normalization is desired, normalize cols to add to 1
        SO_resized(ii,:,:) = squeeze(SO_resized(ii,:,:)) ./ sum(squeeze(SO_resized(ii,:,:)),1);
    end
end


end