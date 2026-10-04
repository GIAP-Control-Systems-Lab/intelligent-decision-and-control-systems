function app = run_ABS
% =========================================================================
% MaIA_SDCI - Semana 4: Extremum Seeking Control
% Sistemas de Decision y Control Inteligente
% Universidad de los Andes, 2026
%
% Copyright (c) 2026 Leffer Trochez
%
% Quarter-car ABS plant adapted from:
% MathWorks, "Anti-Lock Braking System (ABS)," Simscape Driveline
% Documentation.
% Available: https://www.mathworks.com/help/sdl/ug/antilock-braking-system-sdl.html
% Accessed: Oct. 1, 2026.
%
% Extremum Seeking Control implementation based on:
% MathWorks, "Anti-Lock Braking Using Extremum Seeking Control,"
% Simulink Control Design Documentation, R2025b.
% Available: https://www.mathworks.com/help/releases/R2025b/slcontrol/ug/anti-lock-braking-using-extremum-seeking-control.html
% Accessed: Oct. 1, 2026.
%
% Tire model:
% MathWorks, "Tire (Magic Formula)," Simscape Driveline Documentation.
% Available: https://www.mathworks.com/help/sdl/ref/tiremagicformula.html
% Accessed: Oct. 1, 2026.
% =========================================================================
% RUN_ABS launches the modular interactive ABS/ESC laboratory.
%
% Keep these files in the same folder:
%   run_ABS.m
%   ABS_Live.m
%   ABS_LiveDataCallback.m
%   ABS_Utils.m
%   S4_ESC_Lab.slx
% =========================================================================

app = ABS_Live();

end