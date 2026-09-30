# =========================================================================
# MaIA_SDCI - Semana 3: Fuzzy Logic
# Sistemas de Decision y Control Inteligente
# Universidad de los Andes, 2026
#
# Copyright (c) 2026 Leffer Trochez
# =========================================================================

# Mass-Spring-Damper | Interactive Fuzzy Logic Laboratory

Laboratorio interactivo para estudiar un sistema masa-resorte-amortiguador en **lazo abierto** y **lazo cerrado con un controlador difuso**, usando una planta física en Simscape.

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
- `b = 20 N·s/m`
- `k = 400 N/m`

## Open Loop

Al seleccionar **Open Loop**:

- El controlador difuso queda completamente bypassed.
- La referencia de posición no se utiliza para excitar la planta.
- El usuario puede definir `F` en el panel superior de la vista mecánica.
- Al iniciar o reiniciar la simulación se aplica un **pulso corto de fuerza** desde `t = 0` hasta `t = 0.03 s`.
- Después de `0.03 s`, la fuerza externa pasa a `0 N` y la planta evoluciona libremente según `m`, `b` y `k`.
- El valor inicial por defecto es `F = 500 N`.

El pulso corto se usa como una aproximación práctica a una excitación impulsiva manteniendo `F` expresada en newtons. Si se cambia `F` después de que el pulso ya terminó, se debe usar **Run / Restart** para aplicar el nuevo valor desde `t = 0`.

> Con los valores iniciales `m = 3.6`, `b = 20` y `k = 400`, la planta es subamortiguada y permite observar una respuesta oscilatoria en lazo abierto.

## Closed Loop

Al seleccionar **Closed Loop**, la trayectoria de control es:

\[
r(t)\rightarrow e(t)\rightarrow \text{Fuzzy Logic Controller}\rightarrow u(t)\rightarrow \text{Planta}\rightarrow y(t)
\]

con

\[
e(t)=r(t)-y(t).
\]

La salida del controlador corresponde a la fuerza aplicada a la planta:

\[
F(t)=u(t).
\]

La posición medida `y(t)` se retroalimenta para calcular continuamente el error respecto a la referencia.

## Controlador Fuzzy Logic

El controlador difuso se implementa dentro del subsistema **Fuzzy Logic Controller** del modelo Simulink.

El sistema de inferencia difusa debe diseñarse utilizando **Fuzzy Logic Designer**.

El flujo de trabajo general es:

1. Diseñar el FIS en **Fuzzy Logic Designer**.
2. Definir las variables de entrada y salida.
3. Crear las funciones de membresía.
4. Definir la base de reglas.
5. Configurar los métodos de inferencia y defuzzificación.
6. Exportar o guardar el FIS.
7. Cargar el FIS en el bloque **Fuzzy Logic Controller** del modelo.
8. Ejecutar el laboratorio y analizar la respuesta del sistema.

Para una implementación sencilla, el controlador puede utilizar como entrada el error de posición:

\[
e(t)=r(t)-y(t).
\]

La estructura interna del controlador puede definirse y modificarse como parte de la actividad.

## Indicador de fuerza en tiempo real

La vista mecánica 2-D incluye:

- Una **flecha roja** sobre la masa que muestra la dirección de la fuerza aplicada.
- Un indicador con el valor instantáneo `F(t)` en newtons.
- En Open Loop, `F(t)` corresponde al pulso externo y luego vuelve a `0 N`.
- En Closed Loop, `F(t)` corresponde a la salida instantánea `u(t)` del controlador difuso.

La longitud de la flecha está saturada únicamente para fines de visualización; el valor numérico mostrado corresponde a la fuerza real de la simulación.

## Métricas

Las métricas de respuesta al escalón se calculan únicamente en **Closed Loop**, donde existe una referencia de posición que debe seguirse:

- Overshoot [%]
- Peak time [s]
- Settling time [s]
- Steady-state error [m]

El tiempo de establecimiento utiliza una banda de `±2 %`.

También se calcula una medida del esfuerzo de control:

\[
J_u=\int u^2(t)\,dt.
\]

Esta métrica permite comparar el desempeño del controlador considerando no solo la respuesta de posición, sino también la magnitud de la acción de control utilizada.

## Fuzzy Logic Designer

El diseño del controlador se realiza utilizando la herramienta **Fuzzy Logic Designer** de MATLAB.

Desde allí pueden modificarse:

- Variables de entrada y salida.
- Funciones de membresía.
- Base de reglas.
- Operadores AND y OR.
- Método de implicación.
- Método de agregación.
- Método de defuzzificación.

El FIS resultante debe cargarse posteriormente en el bloque **Fuzzy Logic Controller** ubicado dentro del subsistema correspondiente del modelo.

## Referencia del modelo base

El modelo de planta en Simscape fue adaptado de:

R. Abbas, "Modeling and Simulation of Spring Mass Damper System (SMD),"  
MATLAB Central File Exchange, version 1.0.0, Sep. 2, 2021.  
Available: https://www.mathworks.com/matlabcentral/fileexchange/98689-modeling-and-simulation-of-spring-mass-damper-system-smd  
Accessed: Sep. 27, 2026.
