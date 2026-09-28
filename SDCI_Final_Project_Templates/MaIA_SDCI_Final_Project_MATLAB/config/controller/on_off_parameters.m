function ON_OFF = on_off_parameters(shared)
% =========================================================================
% MaIA_SDCI Final Project
% Sistemas de Decision y Control Inteligente (SDCI)
% Universidad de los Andes, 2026
%
% Copyright (c) 2026 Leffer Trochez
% =========================================================================
%
% Defines the parameters for the ON/OFF controller.

%% PARAMETERS
ON_OFF = struct;

ON_OFF.sampleTime = shared.sampleTime;
ON_OFF.dMin = shared.dMin;
ON_OFF.dMax = shared.dMax;

ON_OFF.hysteresis = [];

end