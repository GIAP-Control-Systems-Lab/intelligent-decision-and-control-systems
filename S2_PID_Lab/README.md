# =========================================================================
# MaIA_SDCI - Semana 2: PID
# Sistemas de Decision y Control Inteligente
# Universidad de los Andes, 2026
#
# Copyright (c) 2026 Leffer Trochez
# =========================================================================

# Mass-Spring-Damper | Interactive PID Laboratory

Laboratorio interactivo para estudiar un sistema masa-resorte-amortiguador en **lazo abierto** y **lazo cerrado con PID**, usando una planta física en Simscape.

## Archivos principales

- `SMD_System.slx`: modelo Simulink/Simscape del sistema.
- `run_SMD.m`: interfaz gráfica interactiva y configuración Open/Closed Loop.
- `Retos.pdf`: guía asociada a los retos de la actividad.
- `cache/`: carpeta utilizada para archivos temporales generados por Simulink y Simscape. Si no existe, el script la crea automáticamente.

## Ejecución

Ubique `SMD_System.slx` y `run_SMD.m` en la misma carpeta. En MATLAB, seleccione esa carpeta como `Current Folder` y ejecute:

```matlab
run_SMD
```

La interfaz gráfica se abrirá automáticamente.

## Planta

El modelo satisface

\[
m\ddot{x}(t)+b\dot{x}(t)+kx(t)=F(t).
\]

Valores iniciales:

- `m = 3.6 kg`
- `b = 100 N·s/m`
- `k = 400 N/m`

## Open Loop

Al seleccionar **Open Loop**:

- El PID queda completamente bypassed.
- `Kp`, `Ki`, `Kd` y `N` quedan bloqueados en la interfaz.
- La referencia de posición no se utiliza para excitar la planta.
- El usuario puede definir `F` en el panel superior de la vista mecánica.
- Al iniciar o reiniciar la simulación se aplica un **pulso corto de fuerza** desde `t = 0` hasta `t = 0.10 s`.
- Después de `0.10 s`, la fuerza externa pasa a `0 N` y la planta evoluciona libremente según `m`, `b` y `k`.
- El valor inicial por defecto es `F = 500 N`.

El pulso corto se usa como una aproximación práctica a una excitación impulsiva manteniendo `F` expresada en newtons. Si se cambia `F` después de que el pulso ya terminó, se debe usar **Run / Restart** para aplicar el nuevo valor desde `t = 0`.

> Con los valores iniciales `m = 3.6`, `b = 100` y `k = 400`, el sistema es fuertemente amortiguado. La masa se desplaza y regresa al equilibrio, pero no necesariamente mostrará varias oscilaciones. Para observar una respuesta oscilatoria más clara puede reducirse `b`.

## Closed Loop

Al seleccionar **Closed Loop**:

- La trayectoria vuelve a ser referencia → error → PID → planta.
- Los parámetros del PID quedan habilitados y se pueden modificar en vivo.
- La fuerza aplicada a la planta es exactamente la salida del controlador:

\[
F(t)=u(t).
\]

Los valores del PID se conservan al alternar temporalmente entre Open Loop y Closed Loop.

## Indicador de fuerza en tiempo real

La vista mecánica 2-D incluye ahora:

- Una **flecha roja** sobre la masa que muestra la dirección de la fuerza aplicada.
- Un indicador en la esquina superior derecha con el valor instantáneo `F(t)` en newtons.
- En Open Loop, `F(t)` corresponde al pulso externo y luego vuelve a `0 N`.
- En Closed Loop, `F(t)` corresponde a la salida instantánea `u(t)` del PID.

La longitud de la flecha está saturada únicamente para fines de visualización; el valor numérico mostrado corresponde a la fuerza real de la simulación.

## Métricas

Las métricas de respuesta al escalón se calculan únicamente en **Closed Loop**, donde existe una referencia de posición que debe seguirse:

- Overshoot [%]
- Peak time [s]
- Settling time [s]
- Steady-state error [m]

El tiempo de establecimiento utiliza una banda de `±2 %`.

## Parámetros del PID

La interfaz permite modificar:

- `Kp`: ganancia proporcional.
- `Ki`: ganancia integral.
- `Kd`: ganancia derivativa.
- `N`: coeficiente del filtro derivativo.

## Referencia del modelo base

El modelo de planta en Simscape fue adaptado de:

R. Abbas, "Modeling and Simulation of Spring Mass Damper System (SMD),"  
MATLAB Central File Exchange, version 1.0.0, Sep. 2, 2021.  
Available: https://www.mathworks.com/matlabcentral/fileexchange/98689-modeling-and-simulation-of-spring-mass-damper-system-smd  
Accessed: Sep. 27, 2026.
