classdef ABS_Utils
methods(Static)
function c = defaultConfig()
c.road = 'Dry asphalt';
c.mode = true;
c.b = 0.050;
c.omega = 10.00;
c.k = 0.75;
c.demodAmp = 1.0;
c.demodPhase = 0;
c.modPhase = 0.0;
c.wh = 1.00;
c.wl = 2.00;
c.lambda0 = 0.15;
c.enableHPF = true;
c.enableLPF = true;
c.lambdaMin = 0.01;
c.lambdaMax = 0.60;
c.Jmin = 0.0;
c.Jmax = 1.20;
c.objectiveGain = 1.0;
c.mq = 375;
c.g = 9.81;
c.Rw = 0.30;
c.Jw = 0.90;
c.v0 = 100/3.6;
c.w0 = c.v0/c.Rw;
c.KpSlip = 16000;
c.KiSlip = 40000;
c.Tmax = 2200;
c.Tmin = 0;
c.Topen = 1500;
c.restV = 0.001;
c.stopV = c.restV;
c.stopTime = inf;
c.maxStep = 0.01;
c.pacingEnabled = true;
c.pacingRate = 1;
[~,c.MF] = ABS_Utils.roadParameters(c.road);
end
function publishVariables(c)
vars = ABS_Utils.simulationVariables(c);
names = fieldnames(vars);
for ii = 1:numel(names)
    assignin('base',names{ii},vars.(names{ii}));
end
end
function vars = simulationVariables(c)
vars.mode = double(c.mode);
vars.MF = c.MF;
vars.b = c.b;
vars.omega = c.omega;
vars.k = c.k;
vars.wh = c.wh;
vars.wl = c.wl;
vars.lambda0 = c.lambda0;
vars.demodAmp = c.demodAmp;
vars.demodPhase = c.demodPhase;
vars.modPhase = c.modPhase;
vars.enableHPF = double(c.enableHPF);
vars.enableLPF = double(c.enableLPF);
vars.lambdaMin = c.lambdaMin;
vars.lambdaMax = c.lambdaMax;
vars.Jmin = c.Jmin;
vars.Jmax = c.Jmax;
vars.objectiveGain = c.objectiveGain;
vars.mq = c.mq;
vars.g = c.g;
vars.Rw = c.Rw;
vars.Jw = c.Jw;
vars.v0 = c.v0;
vars.w0 = c.w0;
vars.KpSlip = c.KpSlip;
vars.KiSlip = c.KiSlip;
vars.Tmax = c.Tmax;
vars.Tmin = c.Tmin;
vars.Topen = c.Topen;
vars.stopV = c.stopV;
vars.stopTime = c.stopTime;
vars.maxStep = c.maxStep;
end
function configureSignalLogging(mdl)
try
    set_param(mdl,'SignalLogging','on','SignalLoggingName','logsout','ReturnWorkspaceOutputs','on');
catch ME
    warning('S4_ESC_Lab:LoggingSetup','Could not configure signal logging: %s',ME.message);
end
end
function block = findBrakeBlock(mdl)
blocks = find_system(mdl,'SearchDepth',1,'BlockType','Constant','Name','Brake Pedal');
if isempty(blocks)
    blocks = find_system(mdl,'LookUnderMasks','all','FollowLinks','on','BlockType','Constant','Name','Brake Pedal');
end
if isempty(blocks)
    error('S4_ESC_Lab:MissingBrakePedal','Could not find the Constant block named "Brake Pedal".');
end
block = blocks{1};
end
function map = buildRuntimeSignalMap(mdl,names)
map = struct();
for ii = 1:numel(names)
    key = matlab.lang.makeValidName(names{ii});
    map.(key) = struct('block','','port',NaN);
    lines = find_system(mdl,'FindAll','on','LookUnderMasks','all','FollowLinks','on','Type','line','Name',names{ii});
    if isempty(lines)
        continue;
    end
    for jj = 1:numel(lines)
        try
            srcPort = get_param(lines(jj),'SrcPortHandle');
            if isempty(srcPort) || srcPort < 0
                continue;
            end
            parent = get_param(srcPort,'Parent');
            portNumber = get_param(srcPort,'PortNumber');
            if ischar(portNumber) || isstring(portNumber)
                portNumber = str2double(portNumber);
            end
            if ~isfinite(portNumber)
                portNumber = 1;
            end
            map.(key) = struct('block',parent,'port',double(portNumber));
            break;
        catch
        end
    end
end
end
function value = readRuntimeSignal(map,name)
value = NaN;
key = matlab.lang.makeValidName(name);
if ~isfield(map,key)
    return;
end
info = map.(key);
if isempty(info.block) || ~isfinite(info.port)
    return;
end
try
    rto = get_param(info.block,'RuntimeObject');
    if isempty(rto) || numel(rto.OutputPort) < info.port
        return;
    end
    data = rto.OutputPort(info.port).Data;
    if isempty(data)
        return;
    end
    data = squeeze(data);
    value = double(data(1));
catch
    value = NaN;
end
end
function t = getSimulationTime(mdl)
t = NaN;
try
    t = get_param(mdl,'SimulationTime');
    if ischar(t) || isstring(t)
        t = str2double(t);
    end
    t = double(t);
catch
end
end
function h = emptyHistory()
h.t = zeros(0,1);
h.slip = zeros(0,1);
h.V = zeros(0,1);
h.Vwheel = zeros(0,1);
h.x = zeros(0,1);
h.lambdaRef = zeros(0,1);
h.lambdaHat = zeros(0,1);
h.Tb = zeros(0,1);
h.J = zeros(0,1);
h.pedal = zeros(0,1);
end
function value = previousOr(x,defaultValue)
if isempty(x)
    value = defaultValue;
else
    value = x(end);
end
end
function [name,MF] = roadParameters(road)
switch lower(strtrim(road))
    case 'dry asphalt'
        name = 'Dry asphalt';
        MF = [10 1.9 1.00 0.97];
    case 'wet asphalt'
        name = 'Wet asphalt';
        MF = [12 2.3 0.82 1.00];
    case 'snow'
        name = 'Snow';
        MF = [5 2.0 0.30 1.00];
    case 'ice'
        name = 'Ice';
        MF = [4 2.0 0.10 1.00];
    otherwise
        error('Unknown road surface: %s',road);
end
end
function mu = magicFormula(lambda,MF)
B = MF(1);
C = MF(2);
D = MF(3);
E = MF(4);
lambda = max(lambda,0);
z = B.*lambda;
mu = D.*sin(C.*atan(z - E.*(z - atan(z))));
end
function lambdaOpt = trueOptimum(MF)
lam = linspace(0,0.65,5000);
mu = ABS_Utils.magicFormula(lam,MF);
[~,idx] = max(mu);
lambdaOpt = lam(idx);
end
function value = tailMean(x,n)
x = x(:);
if isempty(x)
    value = NaN;
    return;
end
n = min(n,numel(x));
value = mean(x(end-n+1:end),'omitnan');
end
function setPair(slider,edit,val)
slider.Value = val;
edit.Value = val;
end
function [X,Y,Z] = discCylinder(radius,thickness,n)
theta = linspace(0,2*pi,n);
[Theta,Y] = meshgrid(theta,[-thickness/2 thickness/2]);
X = radius*cos(Theta);
Z = radius*sin(Theta);
end
function p = cuboidPatch(ax,center,sz,color)
cx = center(1);
cy = center(2);
cz = center(3);
sx = sz(1)/2;
sy = sz(2)/2;
sz2 = sz(3)/2;
V = [cx-sx cy-sy cz-sz2;cx+sx cy-sy cz-sz2;cx+sx cy+sy cz-sz2;cx-sx cy+sy cz-sz2;cx-sx cy-sy cz+sz2;cx+sx cy-sy cz+sz2;cx+sx cy+sy cz+sz2;cx-sx cy+sy cz+sz2];
F = [1 2 3 4;5 8 7 6;1 5 6 2;2 6 7 3;3 7 8 4;5 1 4 8];
p = patch(ax,'Vertices',V,'Faces',F,'FaceColor',color,'EdgeColor',[0.15 0.15 0.15],'FaceAlpha',0.95);
end
function htmlPath = ensureBrakeHTML(cacheFolder)
if ~isfolder(cacheFolder)
    mkdir(cacheFolder);
end
htmlPath = fullfile(cacheFolder,'abs_hold_button.html');
lines = {
'<!DOCTYPE html>'
'<html>'
'<head>'
'<meta charset="utf-8">'
'<style>'
'html,body{width:100%;height:100%;margin:0;padding:0;overflow:hidden;background:transparent;font-family:Arial,sans-serif;}'
'#wrap{width:100%;height:100%;display:flex;align-items:center;justify-content:center;box-sizing:border-box;padding:2px;}'
'#brake{width:100%;height:100%;min-height:52px;border:0;border-radius:7px;background:#d92f2f;color:white;font-size:22px;font-weight:700;cursor:pointer;user-select:none;-webkit-user-select:none;touch-action:none;box-shadow:inset 0 -3px 0 rgba(0,0,0,.18);}'
'#brake:active,.pressed{background:#8f0909!important;transform:translateY(1px);box-shadow:inset 0 2px 0 rgba(0,0,0,.22)!important;}'
'#brake:disabled{background:#bdbdbd;color:#ececec;cursor:not-allowed;box-shadow:none;}'
'</style>'
'<script type="text/javascript">'
'function setup(htmlComponent){'
'  const btn=document.getElementById("brake");'
'  let pressed=false; let seq=0;'
'  function send(v){pressed=v;seq+=1;htmlComponent.Data={kind:"brake",pressed:v,seq:seq};}'
'  function setVisual(v){btn.classList.toggle("pressed",v);btn.textContent=v?"BRAKING...":"HOLD TO BRAKE";}'
'  function press(ev){if(btn.disabled||pressed)return;ev.preventDefault();try{btn.setPointerCapture(ev.pointerId);}catch(e){}setVisual(true);send(true);}'
'  function release(ev){if(!pressed)return;if(ev)ev.preventDefault();setVisual(false);send(false);}'
'  btn.addEventListener("pointerdown",press);'
'  btn.addEventListener("pointerup",release);'
'  btn.addEventListener("pointercancel",release);'
'  btn.addEventListener("lostpointercapture",release);'
'  btn.addEventListener("contextmenu",function(ev){ev.preventDefault();});'
'  window.addEventListener("blur",release);'
'  btn.addEventListener("keydown",function(ev){if((ev.key===" "||ev.key==="Enter")&&!ev.repeat){press(ev);}});'
'  btn.addEventListener("keyup",function(ev){if(ev.key===" "||ev.key==="Enter"){release(ev);}});'
'  htmlComponent.addEventListener("DataChanged",function(){'
'    const d=htmlComponent.Data;'
'    if(d&&Object.prototype.hasOwnProperty.call(d,"enabled")){btn.disabled=!Boolean(d.enabled);if(btn.disabled){pressed=false;setVisual(false);}else if(Object.prototype.hasOwnProperty.call(d,"pressed")){pressed=Boolean(d.pressed);setVisual(pressed);}}'
'  });'
'  btn.disabled=true; setVisual(false);'
'}'
'</script>'
'</head>'
'<body><div id="wrap"><button id="brake" type="button" aria-label="Hold to brake">HOLD TO BRAKE</button></div></body>'
'</html>'};
fid = fopen(htmlPath,'w');
if fid < 0
    error('S4_ESC_Lab:BrakeHTML','Could not create %s.',htmlPath);
end
cleanup = onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',lines{:});
end
end
end
