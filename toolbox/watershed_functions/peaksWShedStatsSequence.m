function [trim_matr, matr_names, matr_fields, trim_PixelIdxList,trim_PixelList, ... 
    trim_PixelValues, trim_rgn,trim_bndry,seq_time] = peaksWShedStatsSequence(img_data,x,y,num_segment,conn_wshed,merge_thresh,max_merges,trim_vol,trim_shift,conn_trim,conn_stats,bl_thresh,merge_rule,f_verb,verb_pref,f_disp)
%peaksWShedStatsSequence determines the peak regions of a 2D image and 
% extracts a set of features for each. It uses peaksWShed, regionMergeByWeight, 
% trimRegionsWShed, and peaksWShedStats_LData.
%
% INPUTS:
%   data         -- 2D matrix of image data. defaults to peaks(100).
%   x            -- x axis of image data. default 1:size(data,2).
%   y            -- y axis of image data. default 1:size(data,1).
%   num_segment  -- segment number if data comes from larger image. default 1.
%   conn_wshed   -- pixel connection to be used by peaksWShed. default 8. 
%   merge_thresh -- threshold weight value for when to stop merge rule. default 8. 
%   max_merges   -- maximum number of merges to perform. default inf. 
%   trim_vol     -- fraction maximum trimmed volume (from 0 to 1), 
%                   i.e. 1 means no trim. default 0.8. 
%   trim_shift   -- value to be subtracted from image prior to evaulation of trim volume. 
%                   default min(min(img_data)).
%   conn_trim    -- pixel connection to be used by trimRegionsWShed. default 8. 
%   conn_stats   -- pixel connection to be used by peaksWShedStats_LData. default 8. 
%   bl_thresh    -- power threshold used to cut off low power data to speed
%                   up computation. Default = [];
%   merge_rule   --
%   f_verb       -- number indicating depth of output text statements of progress.
%                   0 - no output. 
%                   1 - output current function level.
%                   2 - output within sequence functions. 
%                   3 - output internal progress of merge and trim.
%                   defaults to 0, unless using default data. 
%   verb_pref    -- prefix string for verbose output. defaults to ''.
%   f_disp       -- flag indicator of whether to plot. 
%                   defaults to 0, unless using default data.
% OUTPUTS:
%   peaks_matr   -- matrix of peak features. each row is a peak.
%   matr_names   -- 1D cell array of names for each feature.
%   matr_fields  -- vector indicating number of matrix columns occupied by each feature. 
%   PixelIdxList -- 1D cell array of vector lists of linear idx of all pixels for each region.
%   PixelList    -- 1D cell array of vector lists of row-col idx of all pixels for each region.
%   PixelValues  -- 1D cell array of vector lists of all pixel values for each region.
%   rgn          -- same as PixelIdxList.
%   bndry        -- 1D cell array of vector lists of linear idx of border pixels for each region. 
%
%   Copyright 2022 Prerau Lab - http://www.sleepEEG.org
%   This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
%   (http://creativecommons.org/licenses/by-nc-sa/4.0/)
%      
%   Authors: Patrick Stokes
%
% Created on: 20190214 -- extracted from peaksWShedStatsWrapper.
% Modified: 20190410 -- commented and cleaned up for toolbox.
%

%*************************
% Handle variable inputs *
%*************************
if nargin < 1
    img_data = [];
end
if nargin < 2
    x = [];
end
if nargin < 3
    y = [];
end
if nargin < 4
    num_segment = [];
end
if nargin < 5
    conn_wshed = [];
end
if nargin < 6
    merge_thresh = [];
end
if nargin < 7
    max_merges = [];
end
if nargin < 8
    trim_vol = [];
end
if nargin < 9
    trim_shift = [];
end
if nargin < 10 
    conn_trim = [];
end
if nargin < 11
    conn_stats = [];
end
if nargin < 12
    bl_thresh = [];
end
if nargin < 13
    merge_rule = [];
end
if nargin < 14
    f_verb = [];
end
if nargin < 15
    verb_pref = [];
end
if nargin < 16
    f_disp = [];
end

%************************
% Set default arguments *
%************************
% The 2d matrix to be analyzed
if isempty(img_data)
    img_data = abs(peaks(100))+randn(100)*.5;
    f_verb = 3;
    f_disp = 1;
    merge_thresh = 2;
end
% x-axis
if isempty(x)
    x = 1:size(img_data,2);
end
% y-axis
if isempty(y)
    y = 1:size(img_data,1);
end
% segment number of image data in larger image 
if isempty(num_segment)
    num_segment = 1;
end
% connection parameter in labeling watershed boundaries
if isempty(conn_wshed)
    conn_wshed = 8;
end
% threshold parameter for stopping merge
if isempty(merge_thresh)
    merge_thresh = 8;
end
% maximum number of merges
if isempty(max_merges)
    max_merges = inf;
end
% volume to which regions are trimmed
if isempty(trim_vol)
    trim_vol = 0.8;
end
% floor level from which trim volume is evaluated
if isempty(trim_shift)
    trim_shift = min(min(img_data));
end
% connection parameter used in trimming regions
if isempty(conn_trim)
    conn_trim = 8;
end
% connection parameter used in peak stats evaluation
if isempty(conn_stats)
    conn_stats = 8;
end
if isempty(bl_thresh)
    bl_thresh = [];
end
if isempty(merge_rule)
    merge_rule = 'absolute';
end
% indicator for level of output verbosity
if isempty(f_verb)
    f_verb = 0;
end
% prefix string for verbose outputs
if isempty(verb_pref)
    verb_pref = '';
end
% flag for displaying outputs
if isempty(f_disp)
    f_disp = 0;
end

% Plot data image with thresholded data shown
% figure;
% image_data_show = img_data;
% image_data_show(below_thresh_inds) = 500;
% imagesc(image_data_show);
% axis xy;
% climscale([],[],false);
% colormap jet;
% title('Chunk Data Image Below Threshold');

%*************************************
% Watershed-segment input data image *
%*************************************
t_start = now;
if f_verb > 0 
    disp([verb_pref 'Starting wshed stats sequence...']);
    disp([verb_pref '  Starting wshed...']);
    ttic = tic;
end
[rgn, rgn_lbls, Lborders, amatr] = peaksWShed(img_data,conn_wshed,bl_thresh,f_verb-1,['    ' verb_pref],f_disp); 
if f_verb > 0 
    disp([verb_pref '    wshed took: ' num2str(toc(ttic)) ' seconds.']);
end

%**************************************************
% Merge watershed regions according to merge rule *
%**************************************************
if f_verb > 0
    disp([verb_pref '  Starting merge...']);
    ttic = tic;
end
[rgn, bndry] = regionMergeByWeight(img_data,rgn,rgn_lbls,Lborders,amatr,merge_thresh,max_merges,merge_rule,f_verb-1,['     ' verb_pref],f_disp);
if f_verb > 0 
    disp([verb_pref '    merge took: ' num2str(toc(ttic)) ' seconds.']);
end

%***********************************************************
% Trim merged regions if trim_vol parameter is less than 1 *
%***********************************************************
if trim_vol < 1 && trim_vol > 0
    if f_verb > 0 
        disp([verb_pref '  Starting trim to ' num2str(100*trim_vol) ' percent volume...']);
        ttic = tic;
    end
    [trim_rgn, trim_bndry] = trimRegionsWShed(img_data,rgn,trim_vol,trim_shift,conn_trim,f_verb-1,['    ' verb_pref],f_disp); 
    if f_verb > 0 
        disp([verb_pref '    trim took: ' num2str(toc(ttic)) ' seconds.']);
    end   
else
    if f_verb > 0
        disp([verb_pref '  Trim parameter geq 1 or leq 0. No trimming.']);
    end
    trim_rgn = rgn;
    trim_bndry = bndry;
end

%***********************************
% Computing stats for peak regions *
%***********************************
if f_verb > 0 
    disp([verb_pref '  Starting stats...']);
    ttic = tic;
end
[trim_matr, matr_names, matr_fields, trim_PixelIdxList,trim_PixelList, trim_PixelValues, ...
    trim_rgn,trim_bndry] = peaksWShedStats_LData(trim_rgn,trim_bndry,img_data,x,y,num_segment,conn_stats,f_verb-1,['    ' verb_pref]);
seq_time = (now-t_start)/datenum([0 0 0 0 0 1]);
if f_verb > 0 
    disp([verb_pref '    stats took: ' num2str(toc(ttic)) ' seconds.']);
    disp([verb_pref 'Sequence took ' num2str(seq_time/60) ' minutes.']); 
end

%     catch tmp_error
%         disp(['Chunk ' num2str(ii) ' hit an error: ']);
%         bad_chunks(ii) = true;
%         chunk_error{ii} = tmp_error;
%         disp( tmp_error.identifier);
%     end
%     % end
