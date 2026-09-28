function ENV = environment_parameters

% =========================================================================
% MaIA_SDCI Final Project
% Sistemas de Decision y Control Inteligente (SDCI)
% Universidad de los Andes, 2026
%
% Copyright (c) 2026 Leffer Trochez
% =========================================================================
%
% Defines the ambient temperature and external disturbance parameters.


%% AMBIENT TEMPERATURE

ENV = struct;

ENV.T_a = 8;   % [degC]


%% TEMPERATURE DISTURBANCE

ENV.disturbance = struct;

ENV.disturbance.enabled = false;
ENV.disturbance.amplitude = 13;   % [degC]

ENV.disturbance.startTime = 5;    % [min]
ENV.disturbance.endTime = 8;      % [min]

% Rooms affected: [Room 1; Room 2; Room 3; Room 4]
ENV.disturbance.roomMask = [
    1
    1
    1
    1
];


%% VALIDATION

if ~isscalar(ENV.T_a) || ~isfinite(ENV.T_a)
    error('MaIA_SDCI:InvalidAmbientTemperature', ...
        'Ambient temperature must be a finite scalar value.');
end

if ~isscalar(ENV.disturbance.enabled)
    error('MaIA_SDCI:InvalidDisturbanceEnabled', ...
        'Disturbance enabled flag must be a scalar logical value.');
end

ENV.disturbance.enabled = logical(ENV.disturbance.enabled);

if ~isscalar(ENV.disturbance.amplitude) || ~isfinite(ENV.disturbance.amplitude)
    error('MaIA_SDCI:InvalidDisturbanceAmplitude', ...
        'Disturbance amplitude must be a finite scalar value.');
end

if ~isscalar(ENV.disturbance.startTime) || ~isfinite(ENV.disturbance.startTime) || ...
        ENV.disturbance.startTime < 0
    error('MaIA_SDCI:InvalidDisturbanceStartTime', ...
        'Disturbance start time must be a nonnegative finite scalar in minutes.');
end

if ~isscalar(ENV.disturbance.endTime) || ~isfinite(ENV.disturbance.endTime) || ...
        ENV.disturbance.endTime < 0
    error('MaIA_SDCI:InvalidDisturbanceEndTime', ...
        'Disturbance end time must be a nonnegative finite scalar in minutes.');
end

if ENV.disturbance.endTime <= ENV.disturbance.startTime
    error('MaIA_SDCI:InvalidDisturbanceWindow', ...
        'Disturbance end time must be greater than start time.');
end

if numel(ENV.disturbance.roomMask) ~= 4
    error('MaIA_SDCI:InvalidDisturbanceMask', ...
        'Disturbance room mask must contain four elements.');
end

ENV.disturbance.roomMask = ENV.disturbance.roomMask(:);

if any(~ismember(ENV.disturbance.roomMask, [0 1]))
    error('MaIA_SDCI:InvalidDisturbanceMaskValues', ...
        'Disturbance room mask values must be either 0 or 1.');
end


%% DISPLAY

fprintf('Environment parameters loaded.\n');
fprintf('  Ambient temperature:     %.1f degC\n', ENV.T_a);
fprintf('  Disturbance enabled:     %d\n', ENV.disturbance.enabled);
fprintf('  Disturbance amplitude:   %.1f degC\n', ENV.disturbance.amplitude);
fprintf('  Disturbance start time:  %.1f min\n', ENV.disturbance.startTime);
fprintf('  Disturbance end time:    %.1f min\n', ENV.disturbance.endTime);
fprintf('  Disturbance room mask:   [%d %d %d %d]\n', ...
    ENV.disturbance.roomMask(1), ENV.disturbance.roomMask(2), ...
    ENV.disturbance.roomMask(3), ENV.disturbance.roomMask(4));

end