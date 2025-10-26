%% Bombcell workflow

%% Set paths
%ephysKilosortPath = [pwd '/kilosort4/'];
ephysKilosortPath = [pwd,filesep,'KS4_UDS_R01_20250217_gluc_imec2'];
ephysRawFile = [pwd, filesep, 'UDS_R01_20250217_gluc_imec2.dat']; % path to .bin or .dat data

% Deal with SpikeGLX output file naming convention
%fileName = bz_BasenameFromBasepath(ephysKilosortPath);
%fileName = fileName(1:end-5); % remove imec# suffix to insert t0 below
%ephysMetaDir = dir([fileName 't0.imec*.*ap*.*meta']); % path to .meta or .oebin meta file
ephysMetaDir = dir(fullfile(pwd, '*.meta'));
savePath = [ephysKilosortPath, filesep, 'qMetrics']; 

kilosortVersion = 4; 
gain_to_uV = NaN;  % specify if NOT using SpikeGLX or OpenEphys

%% Load data
% Recommended to use this function rather than any custom one because it handles 
% 0-indexed values in a particular way.
[spikeTimes_samples, spikeClusters, templateWaveforms, templateAmplitudes, pcFeatures, ...
    pcFeatureIdx, channelPositions] = bc.load.loadEphysData(ephysKilosortPath, savePath);

%% Run quality metrics
param = bc.qm.qualityParamValues(ephysMetaDir, ephysRawFile, ephysKilosortPath, gain_to_uV, kilosortVersion);

param.nChannels = 385; % include sync channel!
param.nSyncChannels = 1;

% if using SpikeGLX, you can use this function: 
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

% Inspect results
bc.load.loadMetricsForGUI;

unitQualityGuiHandle = bc.viz.unitQualityGUI_synced(memMapData, ephysData, qMetric, forGUI, rawWaveforms, ...
    param, probeLocation, unitType, loadRawTraces);

%% Get unit labels
goodUnits = unitType == 1;
muaUnits = unitType == 2;
noiseUnits = unitType == 0;
nonSomaticUnits = unitType == 3; 

% example: get all good units number of spikes
all_good_units_number_of_spikes = qMetric.nSpikes(goodUnits);

% (for use with another language: output a .tsv file of labels. You can then simply load this) 
label_table = table(unitType);
writetable(label_table,[savePath filesep 'templates._bc_unit_labels.tsv'],'FileType', 'text','Delimiter','\t');  

%% Run ephys properties
% rerunEP = 0;
% region = ''; % options include 'Striatum' and 'Cortex'
% [ephysProperties, unitClassif] = bc.ep.runAllEphysProperties(ephysKilosortPath, savePath, rerunEP, region);