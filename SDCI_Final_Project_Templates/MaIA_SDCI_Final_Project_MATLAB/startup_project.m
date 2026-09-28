function startup_project(projectRoot)

% =========================================================================
% MaIA_SDCI Final Project
% Sistemas de Decision y Control Inteligente (SDCI)
% Universidad de los Andes, 2026
%
% Copyright (c) 2026 Leffer Trochez
% =========================================================================
%
% Initializes the project using paths relative to the project root.


%% PROJECT FOLDERS

configFolder = fullfile(projectRoot, 'config');
modelConfigFolder = fullfile(configFolder, 'model');
controllerConfigFolder = fullfile(configFolder, 'controller');
appFolder = fullfile(projectRoot, 'app');
utilitiesFolder = fullfile(projectRoot, 'utilities');
resultsFolder = fullfile(projectRoot, 'results');
cacheFolder = fullfile(projectRoot, 'cache');


%% VALIDATE SOURCE FOLDERS

requiredSourceFolders = { ...
    configFolder; ...
    modelConfigFolder; ...
    controllerConfigFolder; ...
    appFolder; ...
    utilitiesFolder};

for k = 1:numel(requiredSourceFolders)

    if ~isfolder(requiredSourceFolders{k})
        error('MaIA_SDCI:MissingProjectFolder', ...
            'Required project folder was not found: %s', ...
            requiredSourceFolders{k});
    end

end


%% GENERATED-DATA FOLDERS

if ~isfolder(resultsFolder)
    mkdir(resultsFolder);
end

if ~isfolder(cacheFolder)
    mkdir(cacheFolder);
end


%% GENERATED FILES

Simulink.fileGenControl('set', ...
    'CacheFolder', cacheFolder, ...
    'CodeGenFolder', cacheFolder, ...
    'createDir', true);


%% MATLAB PATH

addpath(projectRoot, '-begin');
addpath(configFolder, '-begin');
addpath(modelConfigFolder, '-begin');
addpath(controllerConfigFolder, '-begin');
addpath(appFolder, '-begin');
addpath(utilitiesFolder, '-begin');

rehash path;


%% PROJECT INFORMATION

PROJECT = struct;

PROJECT.name = 'MaIA_SDCI';
PROJECT.root = projectRoot;
PROJECT.configFolder = configFolder;
PROJECT.modelConfigFolder = modelConfigFolder;
PROJECT.controllerConfigFolder = controllerConfigFolder;
PROJECT.appFolder = appFolder;
PROJECT.utilitiesFolder = utilitiesFolder;
PROJECT.resultsFolder = resultsFolder;
PROJECT.cacheFolder = cacheFolder;

assignin('base', 'PROJECT', PROJECT);


%% CONFIGURATION MODULES

CFG = project_config();
MODEL = model_parameters();
ENV = environment_parameters();
SENSOR = sensor_parameters();

[CTRL, CTRL_REPLICATOR, MPC_PLANT, MaIA_SDCI_MPC] = ...
    controller_parameters(MODEL);


%% BASE WORKSPACE

assignin('base', 'CFG', CFG);
assignin('base', 'MODEL', MODEL);
assignin('base', 'ENV', ENV);
assignin('base', 'SENSOR', SENSOR);
assignin('base', 'CTRL', CTRL);
assignin('base', 'CTRL_REPLICATOR', CTRL_REPLICATOR);
assignin('base', 'MPC_PLANT', MPC_PLANT);
assignin('base', 'MaIA_SDCI_MPC', MaIA_SDCI_MPC);


%% DEFAULT SELECTIONS

% Controller IDs: 1 ON/OFF, 2 Fuzzy, 3 MPC, 4 ESC, 5 Replicator.

validControllerID = false;

if evalin('base', 'exist(''CONTROLLER_ID'',''var'')')

    controllerID = evalin('base', 'CONTROLLER_ID');

    validControllerID = isnumeric(controllerID) && ...
        isscalar(controllerID) && isfinite(controllerID) && ...
        controllerID == fix(controllerID) && ismember(controllerID, 1:5);

end

if ~validControllerID
    assignin('base', 'CONTROLLER_ID', 1);
end

% Model IDs: 1 Block-Based, 2 Physics-Based / Simscape.

validModelTypeID = false;

if evalin('base', 'exist(''MODEL_TYPE_ID'',''var'')')

    modelTypeID = evalin('base', 'MODEL_TYPE_ID');

    validModelTypeID = isnumeric(modelTypeID) && ...
        isscalar(modelTypeID) && isfinite(modelTypeID) && ...
        modelTypeID == fix(modelTypeID) && ismember(modelTypeID, 1:2);

end

if ~validModelTypeID
    assignin('base', 'MODEL_TYPE_ID', 1);
end

if ~evalin('base', 'exist(''MaIA_SDCI_RUN_FROM_GUI'',''var'')')
    assignin('base', 'MaIA_SDCI_RUN_FROM_GUI', false);
end


%% DISPLAY

fprintf('Project environment ready.\n');

end