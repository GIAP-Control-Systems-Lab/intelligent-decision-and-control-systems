function MODEL = model_parameters

% =========================================================================
% MaIA_SDCI Final Project
% Sistemas de Decision y Control Inteligente (SDCI)
% Universidad de los Andes, 2026
%
% Copyright (c) 2026 Leffer Trochez
% =========================================================================
%
% Loads the parameters for the Block-Based and Simscape model backends.


%% CONFIGURATION FOLDER

thisFile = mfilename('fullpath');
configFolder = fileparts(thisFile);
modelFolder = fullfile(configFolder, 'model');

if ~isfolder(modelFolder)
    error('MaIA_SDCI:MissingModelFolder', ...
        'Model configuration folder was not found: %s', modelFolder);
end

addpath(modelFolder);


%% MODEL PARAMETERS

MODEL = struct;

MODEL.BLOCK_BASED = struct;
MODEL.SIMSCAPE = struct;

MODEL.BLOCK_BASED.ACTUATOR = block_based_actuator_parameters();
MODEL.BLOCK_BASED.PLANT = block_based_plant_parameters();

MODEL.SIMSCAPE.ACTUATOR = simscape_actuator_parameters();
MODEL.SIMSCAPE.PLANT = simscape_plant_parameters();


%% DISPLAY

fprintf('Model parameters loaded.\n');
fprintf('  BLOCK_BASED: actuator + plant\n');
fprintf('  SIMSCAPE:    actuator + plant parameter structures\n');

end