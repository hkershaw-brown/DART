% Script to generate: 
%   (1) standard reanalysis diagnostics (.ps, .txt, .pdf files)
%   (2) an html directory useful to view everything in one place 

% Uses script "results.m" and function "invoke_diag.m"
% It creates a Diags_MMM-yyyy directory in the current working directory.

% Requirement: 'obs_diag_output.nc' file

% >>> Run  my matlab_norm.csh after this,
%     so that my .pdf and .ps overwrite the ones generated here.

clear
close all
clc

global path

view_format             = 'html';
dont_show_code          = false ;
fig_format              = 'png' ;

<<<<<<< Updated upstream:diagnostics/matlab/gen_rean_diags.m
path.scripts_dir        = '/Users/raeder/DAI/reanalysis_git/diagnostics/matlab';
path.diags_dir          = pwd;

=======
% KDR: This is where it looks for results.m.
%      But is also looks for obs_diag_output.nc there,
%      so it looks like I need to copy results.m to my Diags_NTrS_YYYY-MM.
path.scripts_dir        = pwd;
>>>>>>> Stashed changes:models/cam-fv/matlab/gen_rean_diags.m

path.diags_dir
% Figure which month are we doing:
path.obs_space_diags = strcat (path.diags_dir, '/obs_diag_output.nc');
if exist(path.obs_space_diags, 'file') ~= 2
    error('DART diagnostics file "obs_diag_output.nc" does not exit in this directory.')
end

Time                    = ncread(path.obs_space_diags, 'time');
unit_time               = ncreadatt(path.obs_space_diags, 'time', 'units');

% Some explanation for python novices would be helpful.
origin                  = regexp(unit_time, '\d*', 'Match');
origin                  = datenum(str2double(origin));
current                 = Time + origin;
period                  = datestr(current, 'mmm-yyyy');

reana_month             = period(ceil(length(period)/2), :);
path.web_dir            = strcat(path.diags_dir, '/web_', reana_month);  

path.inflation          = '';
% KDR Looking for the matlab script in the Diags directory where obs_diag_output.nc is.
path.fireoff_script     = strcat(path.scripts_dir, '/results.m');


% Fill in the publishing options
options = struct(   'format'        , view_format       , ...
                    'showCode'      , dont_show_code    , ...
                    'imageFormat'   , fig_format        , ...
                    'outputDir'     , path.web_dir      );
                
publish(path.fireoff_script, options);

