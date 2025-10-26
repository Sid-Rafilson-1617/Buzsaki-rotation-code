
function [behavior] = getSessionTracking_km(varargin)
%
% Gets position trackign for each sub-session and concatenate all of them so they are 
% aligned with LFP and spikes. Default is recording with Basler, and requiere avi videos 
% and at least one tracking LED. There is an alternative in case OptiTrack was used. 
% Needs to be run in main session folder. 
%
% USAGE
%
%   [tracking] = getSessionTracking(varargin)
%
% INPUTS
%   basePath       -(default: pwd) basePath for the recording file, in buzcode format:
%   roiTracking    - 2 x R, where 1C is x and 2C is y. By default it
%                   considers the whole video. With the option 'manual' allows to draw
%                   a ROI.
%   roiLED         - 2 x R. 'manual' for drawing the ROI.
%   roisPath       - provide a path with ROI mat files ('roiTRacking.mat'
%                   and 'roiLED.mat'). By default try to find it in
%                   basePath or upper folder.
%   convFact       - Spatial conversion factor (cm/px). If not provide,
%                   normalize maze size.
%   saveMat        - default true
%   forceReload    - default false
%
% OUTPUT
%       - tracking.behaviour output structure, with the fields:
%   position.x               - x position in cm/ normalize
%   position.y               - y position in cm/ normalize
%   timestamps      - in seconds, if Basler ttl detected, sync by them
%   folder          - 
%   sync.sync       - Rx1 LED luminance.
%   sync.timestamps - 2xC with start stops of sync LED.
%       only for OptiTrack
%   position.z 
%   orientation.x
%   orientation.y
%   orientation.z

%   HISTORY:
%     - Manuel Valero 2019
%     - Added OptiTrack support: 5/20, AntonioFR (STILL NEEDS TESTING)
%
% unsure what to do with multiple csv's in one recording...
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Defaults and Params

ismethod = @(x) sum(strcmp(x,{'intan','neuropixel'}));

p = inputParser;
addParameter(p,'basepath',pwd,@isstr);
addParameter(p,'saveMat',true,@islogical)
addParameter(p,'forceReload',false,@islogical)
addParameter(p,'method','intan',ismethod)

parse(p,varargin{:});
basepath = p.Results.basepath;
saveMat = p.Results.saveMat;
forceReload = p.Results.forceReload;
method = p.Results.method;

%% In case tracking already exists 
if ~isempty(dir([basepath filesep '*Tracking.Behavior.mat'])) || forceReload
    disp('Trajectory already detected! Loading file.');
    file = dir([basepath filesep '*Tracking.Behavior.mat']);
    load(file.name);
    return
end

%% Get session info
session = bz_getSession('basepath',basepath);
digitFq = session.extracellular.sr;

%% OptiTrack 

% Load merge point info to correct times
mergeFile = checkFile('basepath',basepath,'fileType','.MergePoints.events.mat');
load([mergeFile.folder,filesep,mergeFile.name]);

% Get csv file locations
trackingFiles = checkFile('basepath',basepath,'fileType','.csv','searchSubDirs',true);

% Load data from each file with proper time
clear trackData;

separateFolders = unique({trackingFiles.folder},'stable');
nFolders = length(separateFolders);
t0 = zeros(nFolders,1);

for fIdx = 1:nFolders
    tmpFolder = separateFolders{fIdx};
    tmpFiles = trackingFiles(strcmp(trackingFiles.folder,tmpFolder));
    trackData.folder(fIdx) = bz_readOptitrackCSV({tmpFiles.name},'basepath',tmpFolder,'syncSampFq',digitFq,'method',method); % these values chosen for this session, need to fix
    subDirIdx = strcmp(tmpFolder,MergePoints.foldernames);
    t0(fIdx) = MergePoints.timestamps(subDirIdx,1);
    trackData.folder(fIdx).timestamps = trackData.folder(fIdx).timestamps + t0(fIdx);
end


% sort subdirectories by start time
[~,timeOrder] = sort(t0);

% Stick data together in order
data = vertcat(trackData.folder(timeOrder).data);
timestamps = vertcat(trackData.folder(timeOrder).timestamps);

behavior = struct();
behavior.timestamps = timestamps;
behavior.frameCount = data(:,1);
behavior.samplingRate = 1/(mode(diff(timestamps)));
behavior.orientation.rx = data(:,3);
behavior.orientation.ry = data(:,4);
behavior.orientation.rz = data(:,5);
behavior.orientation.rw = data(:,6);

behavior.position.x = data(:,7);
behavior.position.y = data(:,8);
behavior.position.z = data(:,9);

if size(data,2)==10
    behavior.errorPerMarker = data(:,10);
end

%% save tracking 
if saveMat
    save([basepath filesep session.general.name '.behavior.mat'],'behavior');
end

end

