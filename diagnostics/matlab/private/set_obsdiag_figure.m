function figdata = set_obsdiag_figure(orientation,varargin)
%%
%  figure out a page layout
%  extra space at the bottom for the date/file annotation
%  extra space at the top because the titles have multiple lines
%
%% DART software - Copyright UCAR. This open source software is provided
% by UCAR, "as is", without charge, subject to all terms of use at
% http://www.image.ucar.edu/DAReS/DART/DART_download

default_nexp = 1; % The number of experiments
p = inputParser;

addRequired(p,'orientation',@ischar);

if (exist('inputParser/addParameter','file') == 2)
    addParameter(p,'numexp', default_nexp, @isnumeric);
else
    addParamValue(p,'numexp',default_nexp, @isnumeric); %#ok<NVREPL>
end

p.parse(orientation,varargin{:});

nexp = p.Results.numexp;

if ~isempty(fieldnames(p.Unmatched))
    disp('Extra inputs:')
    disp(p.Unmatched)
end

if strncmpi(orientation,'tall',4)
    orientation = 'tall';
    position = [0.15 0.12 0.7 0.75];
    
    if (nexp > 1)   % to replicate the 'two_experiments' behaviour
        ybot        = 0.06 + nexp*0.035;  % room for dates/files
        ytop        = 0.125;              % room for title (always 2 lines)
        dy          = 1.0 - ytop - ybot;
        position    = [0.15 ybot 0.7 dy];
    end
    
else
    orientation = 'landscape';
    position = [0.10 0.15 0.8 0.7];
    
    if (nexp > 1)   % to replicate the 'two_experiments' behaviour
        ybot        = 0.06 + nexp*0.075;  % room for dates/files
        ytop        = 0.125;              % room for title (always 2 lines)
        dy          = 1.0 - ytop - ybot;
        position    = [0.10 ybot 0.8 dy];
    end
    
end

fontsize      = 14;
linewidth     = 2.5;
obs_color     = [215  10  83]/255; % obs_red
ges_color     = [  0 128   0]/255; % prior_green
anl_color     = [  0   0 255]/255; % poste_blue
rmse_color    = [  0   0   0]/255; % black
copy_color    = [  0 128 128]/255; % teal
purple        = [153  51 255]/255;
orange        = [255 153  51]/255;
obs_marker    = 'o';
ges_marker    = '*';
anl_marker    = 'd';
marker1       = 'o';
marker2       = 's';
ges_linestyle = '-';
anl_linestyle = '-';
dashed        = '--';
solid         = '-';

% from https://www.rapidtables.com/web/color/RGB_Color.html, mostly
x.white       = [255 255 255]/255;
x.background  = [225 225 225]/255;
x.black       = [  0   0   0]/255;
x.blue        = [  0   0 255]/255;
x.navy        = [  0   0 128]/255;
x.teal        = [  0 128 128]/255;
x.lightblue   = [173 235 255]/255;
x.cyan        = [  0 255 255]/255;
x.magenta     = [255   0 255]/255;
x.green       = [  0 128   0]/255;
x.olive       = [128 128   0]/255;
x.lime        = [  0 255   0]/255;
x.yellow      = [255 255   0]/255;
x.orange      = [255 153  51]/255;
x.red         = [215  10  83]/255;
x.maroon      = [128   0   0]/255;
x.purple      = [153  51 255]/255;

%   'expcolors',  {{'k','b','m','g','c','y','r'}}, ...
figdata = struct( ...
    'expcolors',  {{[x.purple], [x.black], [x.blue  ], [x.magenta], [x.green ], [x.cyan], ...
                    [x.red   ], [x.olive], [x.purple], [x.orange ], [x.maroon], [x.teal]}}, ...
    'expsymbols', {{'o','s','d','p','h','s','*'}}, ...
    'prpolines',  {{'-','--'}}, ...
    'position'     , position, ...
    'fontsize'     , fontsize, ...
    'orientation'  , orientation, ...
    'linewidth'    , linewidth, ...
    'obs_color'    , obs_color, ...
    'ges_color'    , ges_color, ...
    'anl_color'    , anl_color, ...
    'rmse_color'   , rmse_color, ...
    'copy_color'   , copy_color, ...
    'obs_marker'   , obs_marker, ...
    'ges_marker'   , ges_marker, ...
    'anl_marker'   , anl_marker, ...
    'marker1'      , marker1, ...
    'marker2'      , marker2, ...
    'ges_linestyle', ges_linestyle, ...
    'anl_linestyle', anl_linestyle, ...
    'dashed'       , dashed, ...
    'solid'        , solid );

