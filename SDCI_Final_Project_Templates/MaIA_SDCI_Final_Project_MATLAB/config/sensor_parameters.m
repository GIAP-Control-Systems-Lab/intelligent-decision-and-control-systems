function SENSOR = sensor_parameters

% =========================================================================
% MaIA_SDCI Final Project
% Sistemas de Decision y Control Inteligente (SDCI)
% Universidad de los Andes, 2026
%
% Copyright (c) 2026 Leffer Trochez
% =========================================================================
%
% Defines the sensor dynamics and measurement parameters.


%% DYNAMICS

SENSOR = struct;

SENSOR.tau = 10;         % [s]
SENSOR.sampleTime = 1;   % [s]


%% INITIAL CONDITION

SENSOR.initialTemperature = 8 * ones(4,1);   % [degC]


%% MEASUREMENT IMPERFECTIONS

SENSOR.bias = zeros(4,1);             % [degC]
SENSOR.noiseStd = 0.05 * ones(4,1);   % [degC]
SENSOR.seed = [101; 202; 303; 404];


%% DISPLAY

fprintf('Sensor parameters loaded.\n');
fprintf('  Time constant: %.2f s\n', SENSOR.tau);
fprintf('  Sample time:   %.2f s\n', SENSOR.sampleTime);
fprintf('  Noise std:     %.3f degC\n', SENSOR.noiseStd(1));

end