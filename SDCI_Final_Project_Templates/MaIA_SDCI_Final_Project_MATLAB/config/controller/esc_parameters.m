function ESC = esc_parameters(shared)
% =========================================================================
% MaIA_SDCI Final Project
% Sistemas de Decision y Control Inteligente (SDCI)
% Universidad de los Andes, 2026
%
% Copyright (c) 2026 Leffer Trochez
% =========================================================================
%
% Defines the parameters for the Extremum Seeking Control (ESC) controller.

%% GENERAL PARAMETERS
ESC = struct;

ESC.sampleTime = shared.sampleTime;
ESC.numberOfRooms = 1;
ESC.numberOfParameters = 1;

ESC.dMin = shared.dMin;
ESC.dMax = shared.dMax;

ESC.initialCondition = [];

%% ESC PARAMETERS
ESC.forcingFrequency = [];
ESC.learningRate = [];
ESC.demodulationAmplitude = [];
ESC.demodulationPhase = [];
ESC.modulationAmplitude = [];
ESC.modulationPhase = [];

%% FILTERS
ESC.enableHPF = [];
ESC.hpfFrequency = [];
ESC.enableLPF = [];
ESC.lpfFrequency = [];
ESC.outputEstimatedParameters = [];

end