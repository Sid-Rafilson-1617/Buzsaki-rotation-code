function [tracking] = bz_readOptitrackCSV(filenames,varargin)

% INPUTS
%    fbasename   -basename of the recording (this is only used in generating
%                 the .mat output file)
%    <options>      optional list of property-value pairs (see table below)
%
%    =========================================================================
%     Properties    Values
%    -------------------------------------------------------------------------
%     'syncDatFile' name of binary file where sync signal is stored
%                   (default = filebasename_digitalin.dat)
%     'syncSampFq'  sampling freqeuncy of the sync signal (default= 20kHz)
%     'syncChan'    sync channel to read (default = 1)
%     'syncNbCh'    number of channels in the sync file (default = 1)
%     'posSampFq'   sampling frequency of the final pos file (after
%                   interpolation) in Hz
%     'columnOrder' order of output variales in .csv file: frame, time, rx,
%                   ry, rz, rw, x, y, z, error. Vector with postion of each
%                   variable in the order specified here
%     'basepath'    absolute path to folder with .csv optitrack files (default = pwd) 
%
% OUTPUTS
%   tracking - strcutre with data read from csv file and timestamps

%% Parse Inputs

ismethod = @(x) sum(strcmp(x,{'intan','neuropixel'}))==1;

p = inputParser;

addParameter(p,'syncDatFile','digitalin.dat',@ischar)
addParameter(p,'syncSampFq',20000,@isnumeric)
addParameter(p,'syncChan',1,@isnumeric)
addParameter(p,'syncNbCh',1,@isnumeric)
addParameter(p,'posSampFq',120,@isnumeric)
addParameter(p,'columnOrder',1:9,@isnumeric)
addParameter(p,'basepath',pwd,@ischar)
addParameter(p,'method','intan',ismethod)

parse(p,varargin{:});
syncDatFile = p.Results.syncDatFile;
syncSampFq = p.Results.syncSampFq;
syncChan = p.Results.syncChan;
syncNbCh = p.Results.syncNbCh;
posSampFq = p.Results.posSampFq;
columnOrder = p.Results.columnOrder;
basepath = p.Results.basepath;
method = p.Results.method;

%% Import and correct data

nFiles = length(filenames);
pos = cell(nFiles,1);
clear f
for fIdx = 1:nFiles
    filename = filenames{fIdx};
    
    %check file exists
    f(fIdx) = checkFile('basepath',basepath,'filename',filename,'fileType','.csv');
    
    %import data
    dat = importdata([basepath, filesep, filename]);
    dat = bz_scrubTracking(dat);
    pos{fIdx} = dat.data; % all tracking variables
end

[~,fileOrder] = sort(datetime({f.date}));
pos = pos(fileOrder);

% get frame timing in digital input timestamps
switch method
    case 'intan'
        % read optitrack sync channel
        fid = fopen([basepath, filesep, syncDatFile]);
        dig = fread(fid,[syncNbCh inf],'int16=>int16');  % default type for Intan digitalin
        dig = dig(syncChan,:);
        t = (0:length(dig)-1)'/syncSampFq; % time vector in sec
        
        dPos = find(diff(dig)==1);
        dNeg = find(diff(dig)==-1);
        
        if length(dPos) == length(dNeg)+1
            dPos = dPos(1:end-1);
        elseif length(dNeg) == length(dPos)+1
            dNeg = dNeg(1:end-1);
        elseif abs(length(dNeg)-length(dPos)) > 1
            warning('some problem with frames');
            keyboard
        end
        % Frame timing is the middle of shuter opening
        TTLtimes = (t(dPos)+t(dNeg))/2;
        
        
    case 'neuropixel'
        % read timestamps
        allInds = readNPY([basepath,'\experiment1\recording1\events\Neuropix-PXI-100.0\TTL_1\timestamps.npy']);
        
        % read pulse inds
        pulseVal = readNPY([basepath,'\experiment1\recording1\events\Neuropix-PXI-100.0\TTL_1\channel_states.npy']);
        
        TTLInds = double(allInds(pulseVal==1));
        TTLtimes = TTLInds./syncSampFq;
        
end

% Group TTL pulses to find gaps
TTLgroups = groupPulses(TTLtimes,1.5);
if max(TTLgroups)~=length(pos)
    error('number of optitrack tiles not matching groups of pulses')
end

% The system sometimes (rarely) keeps on recording a few frames after software stopped
% recording. So we skip the last frames of the TTL
timestamps = cell(length(pos),1);
TTLtimeGroups = cell(length(pos),1);
for ii = 1:length(pos)
    
    tmpTTLtimes = TTLtimes(TTLgroups==ii);
    nTTL = length(tmpTTLtimes);
    nFrames = size(pos{ii},1);
    
    pos{ii}(pos{ii}==-1) = NaN;
    
    if nTTL < nFrames % more frames than pulses, e.g. intan turned off first

        pos{ii} = pos{ii}(1:nTTL,:);
        
    elseif nTTL > nFrames % more pulses than frames, something weird with optitrack
        
        tmpTTLtimes = tmpTTLtimes(1:nFrames);
    end
    
    TTLtimeGroups{ii} = tmpTTLtimes;
    timestamps{ii} = (tmpTTLtimes(1):(1/posSampFq):tmpTTLtimes(end));
end

timestamps = vertcat(timestamps{:});
TTLtimes = vertcat(TTLtimeGroups{:});
pos = vertcat(pos{:});
newPos = interp1(TTLtimes,pos,timestamps);
newPos = newPos(:,columnOrder);

tracking.timestamps = timestamps;
tracking.data = newPos;

end
