# =========================================================================
# MaIA_SDCI - Semana 2: PID
# Sistemas de Decision y Control Inteligente
# Universidad de los Andes, 2026
#
# Copyright (c) 2026 Leffer Trochez
# =========================================================================

# Mass-Spring-Damper | Interactive PID Laboratory

Laboratorio interactivo para estudiar el comportamiento de un controlador PID aplicado a un sistema masa-resorte-amortiguador modelado físicamente en Simscape.

## Archivos principales

- `SMD_System.slx`: modelo Simulink/Simscape del sistema.
- `run_SMD.m`: interfaz gráfica interactiva.
- `Retos.pdf`: guía asociada a los retos de la actividad.
- `cache/`: carpeta utilizada para archivos temporales generados por Simulink y Simscape. Si no existe, el script la crea automáticamente.

## Ejecución

Ubique `SMD_System.slx` y `run_SMD.m` en la misma carpeta.

En MATLAB, seleccione esa carpeta como `Current Folder` y ejecute:

```matlab
run_SMD
```

La interfaz gráfica se abrirá automáticamente.

## Funcionamiento

La planta corresponde a un sistema masa-resorte-amortiguador con los parámetros:

- Masa: `m = 3.6 kg`
- Amortiguamiento: `b = 100 N·s/m`
- Rigidez: `k = 400 N/m`

El controlador PID genera la fuerza aplicada sobre la masa y la posición medida se utiliza como señal de realimentación.

La referencia de posición y los parámetros del PID pueden modificarse directamente desde la interfaz mientras la simulación se encuentra en ejecución.

## Parámetros del controlador

La interfaz permite modificar:

- `Kp`: ganancia proporcional.
- `Ki`: ganancia integral.
- `Kd`: ganancia derivativa.
- `N`: coeficiente del filtro derivativo.

En esta actividad, `N = 100` puede mantenerse fijo mientras se estudia principalmente el efecto de `Kp`, `Ki` y `Kd`.

## Visualización

La interfaz incluye:

- Animación 2-D del sistema masa-resorte-amortiguador.
- Referencia de posición entre `-2 m` y `2 m`.
- Respuesta temporal de la posición.
- Controles interactivos para el PID.
- Indicador del estado de la simulación.

## Métricas

Después de cada cambio de referencia se calculan automáticamente:

- Overshoot [%]
- Peak time [s]
- Settling time [s]
- Steady-state error [m]

El tiempo de establecimiento utiliza una banda del `±2 %`.

Para comparar resultados entre experimentos y desarrollar los retos, utilice siempre el mismo cambio de referencia:

```text
0 m -> 1 m
```

## Modelo físico

El sistema masa-resorte-amortiguador satisface:

\[
m\ddot{x}(t)+b\dot{x}(t)+kx(t)=F(t)
\]

donde:

- \(m\) es la masa.
- \(b\) es el coeficiente de amortiguamiento.
- \(k\) es la rigidez del resorte.
- \(F(t)\) es la fuerza aplicada por el controlador.
- \(x(t)\) es la posición de la masa.

## Referencia del modelo base

El modelo de planta en Simscape fue adaptado de:

R. Abbas, "Modeling and Simulation of Spring Mass Damper System (SMD),"  
MATLAB Central File Exchange, version 1.0.0, Sep. 2, 2021.  
Available: https://www.mathworks.com/matlabcentral/fileexchange/98689-modeling-and-simulation-of-spring-mass-damper-system-smd  
Accessed: Sep. 27, 2026.
