%% Bombcell workflow
function [qMetric, unitType] = bombcell_spikeGLX(basepath, filename, metaDir)

% Set paths
ephysKilosortPath = [basepath, filesep, 'KS4_', filename, filesep];
ephysRawFile      = [basepath, filesep, filename, '.dat']; % path to .bin or .dat data
savePath          = [ephysKilosortPath, 'qMetrics']; 

if isempty(metaDir) % path to .meta or .oebin meta file
   ephysMetaDir   = dir(fullfile(basepath, [filename, '*.meta'])); 
else
   ephysMetaDir   = checkFile('basepath', metaDir, 'fileType', '.meta');
end

% Parameters
kilosortVersion = 4; 
gain_to_uV = NaN;  % specify analog to uV conversion factor if NOT using SpikeGLX or OpenEphys

%% Load data
% Recommended to use this function rather than any custom one because it handles 
% 0-indexed values in a particular way.
[spikeTimes_samples, spikeClusters, templateWaveforms, templateAmplitudes, pcFeatures, ...
    pcFeatureIdx, channelPositions] = bc.load.loadEphysData(ephysKilosortPath, savePath);

%% Run quality metrics
param = bc.qm.qualityParamValues(ephysMetaDir, ephysRawFile, ephysKilosortPath, gain_to_uV, kilosortVersion);

param.nChannels = 385; % include sync channel!
param.nSyncChannels = 1;

% if using SpikeGLX, should use this function to read meta file: 
if ~isempty(ephysMetaDir)
    if endsWith(ephysMetaDir.name, '.ap.meta') % SpikeGLX file-naming convention
        meta = bc.dependencies.SGLX_readMeta.ReadMeta(ephysMetaDir.name, ephysMetaDir.folder);
        [AP, ~, SY] = bc.dependencies.SGLX_readMeta.ChannelCountsIM(meta);
        param.nChannels = AP + SY;
        param.nSyncChannels = SY;
    end
end

[qMetric, unitType] = bc.qm.runAllQualityMetrics(param, spikeTimes_samples, spikeClusters, ...
        templateWaveforms, templateAmplitudes, pcFeatures, pcFeatureIdx, channelPositions, savePath);

%% Run ephys properties
% rerunEP = 0;
% region = ''; % options include 'Striatum' and 'Cortex'
% [ephysProperties, unitClassif] = bc.ep.runAllEphysProperties(ephysKilosortPath, savePath, rerunEP, region);

end