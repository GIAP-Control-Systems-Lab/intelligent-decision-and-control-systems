# =========================================================================
# MaIA_SDCI - Semana 4: Extremum Seeking Control
# Sistemas de Decision y Control Inteligente
# Universidad de los Andes, 2026
#
# Copyright (c) 2026 Leffer Trochez
# =========================================================================

# Quarter-Car ABS | Interactive Extremum Seeking Control Laboratory

Laboratorio interactivo para estudiar **Extremum Seeking Control (ESC)** aplicado a un sistema de frenado antibloqueo (**ABS**) de un cuarto de vehículo, utilizando MATLAB, Simulink y Simscape.

El laboratorio permite comparar el comportamiento del sistema en **Open Loop** y **Closed Loop (ESC)**, aplicar el freno de manera interactiva durante la simulación y observar en tiempo real la evolución del deslizamiento de la rueda, la velocidad del vehículo, el torque de frenado y la búsqueda del punto de máxima fricción.

## Archivos principales

- `S4_ESC_Lab.slx`: modelo Simulink/Simscape del sistema ABS de un cuarto de vehículo.
- `run_ABS.m`: punto de entrada para iniciar el laboratorio.
- `ABS_Live.m`: interfaz gráfica, visualización y manejo de la simulación interactiva.
- `ABS_LiveDataCallback.m`: recepción de señales en tiempo real desde Simulink.
- `ABS_Utils.m`: configuración, parámetros, modelo de fricción y funciones auxiliares.
- `README.md`: descripción y guía de uso del laboratorio.

La carpeta `cache/` y los archivos generados por Simulink no son necesarios para distribuir el laboratorio y pueden regenerarse automáticamente.

## Requisitos

El proyecto fue desarrollado para **MATLAB R2025b** y utiliza:

- MATLAB
- Simulink
- Simscape
- Simscape Driveline
- Simulink Control Design

## Ejecución

Ubique todos los archivos principales en la misma carpeta. En MATLAB, seleccione esa carpeta como `Current Folder` y ejecute:

```matlab
run_ABS
```

La interfaz gráfica se abrirá automáticamente.

También puede utilizar el botón **Open Simulink** para inspeccionar directamente la planta y la arquitectura de control.

## Planta

El modelo representa un sistema longitudinal simplificado de **un cuarto de vehículo** compuesto por:

- masa equivalente del vehículo,
- dinámica rotacional de una rueda,
- fuente de torque de frenado,
- modelo de neumático **Tire (Magic Formula)**,
- medición de velocidad del vehículo,
- medición de velocidad periférica de la rueda,
- cálculo del deslizamiento longitudinal.

El deslizamiento de la rueda se interpreta como:

```text
lambda = 0    rodadura sin deslizamiento longitudinal
lambda -> 1   rueda cercana al bloqueo durante el frenado
```

La velocidad inicial del vehículo es **100 km/h**.

## Open Loop

En **Open Loop**, el pedal aplica directamente un torque de frenado fijo y no existe regulación del deslizamiento:

```text
Brake pedal -> fixed brake torque -> quarter-car plant
```

El torque de frenado por defecto es:

```text
Topen = 1500 N m
```

Este modo permite observar cómo una acción de frenado suficientemente alta puede llevar la rueda hacia el bloqueo mientras el vehículo todavía mantiene velocidad longitudinal.

## Closed Loop (ESC)

En **Closed Loop**, el sistema utiliza dos niveles de control:

```text
actual slip
    |
    v
Road Friction Objective: J = mu(lambda)
    |
    v
Extremum Seeking Control
    |
    v
theta_hat + modulation
    |
    v
lambda_ref
    |
    v
Inner PI Slip Controller
    |
    v
Brake Torque
    |
    v
Quarter-Car Plant
```

El **Extremum Seeking Control** busca en línea el valor de deslizamiento que maximiza el coeficiente de fricción neumático-carretera.

El controlador PI interno regula el torque de frenado para que el deslizamiento físico de la rueda siga la referencia calculada por el ESC.

## Condición de carretera

La versión utilizada para esta actividad trabaja con una única condición:

**Dry asphalt**

Los parámetros Magic Formula utilizados son:

| Parámetro | Valor |
|---|---:|
| B | 10 |
| C | 1.9 |
| D | 1.00 |
| E | 0.97 |

Para esta curva, el máximo de fricción ocurre aproximadamente en:

```text
lambda* ~= 0.180
```

Este valor se muestra en la interfaz únicamente como referencia para evaluar el comportamiento del ESC.

## Parámetros del Extremum Seeking Control

La interfaz permite modificar seis parámetros del ESC.

### Modulation amplitude `b`

Define la amplitud de la perturbación sinusoidal utilizada para explorar el entorno de la estimación actual.

Un valor mayor produce una exploración más amplia, pero también incrementa la oscilación de `lambda_ref`.

### Forcing frequency `omega`

Define la frecuencia de la señal de excitación del ESC en rad/s.

Controla qué tan rápidamente se realiza la exploración alrededor de `theta_hat`.

### Learning rate `k`

Define la velocidad de adaptación de la estimación.

Valores mayores pueden producir una búsqueda más rápida, pero también una respuesta más agresiva u oscilatoria.

### HPF cutoff `wh`

Frecuencia de corte del filtro pasa-altas utilizado dentro del proceso de demodulación del ESC.

### LPF cutoff `wl`

Frecuencia de corte del filtro pasa-bajas utilizado para extraer la componente útil de la señal demodulada.

### Initial `theta_hat`

Valor inicial de la estimación del deslizamiento óptimo.

## Valores por defecto

La configuración inicial del ESC es:

```matlab
b       = 0.050;
omega   = 10.00;
k       = 0.75;
wh      = 1.00;
wl      = 2.00;
lambda0 = 0.15;
```

El controlador PI interno permanece fijo durante la actividad:

```matlab
KpSlip = 16000;
KiSlip = 40000;
Tmax   = 2200;
```

De esta manera, el análisis de la Semana 4 se concentra en el comportamiento del **Extremum Seeking Control**.

## Uso interactivo del freno

Después de iniciar la simulación con **Start / Restart**, el vehículo comienza a desplazarse sin aplicar el freno.

El usuario puede mantener presionado **BRAKE** en cualquier momento para iniciar un evento de frenado y soltarlo para terminarlo.

Durante cada evento, la interfaz calcula:

- duración del frenado,
- reducción de velocidad,
- distancia recorrida durante el evento,
- máximo deslizamiento observado,
- **Slip tracking score [%]**.

El **Slip tracking score [%]** evalúa qué tan bien el deslizamiento real de la rueda sigue el valor óptimo de deslizamiento durante el frenado. El score se obtiene a partir del error RMS relativo entre el deslizamiento real y el óptimo de la curva de fricción. Un valor mayor indica mejor seguimiento, mientras que desviaciones persistentes u oscilaciones alejadas del óptimo reducen el score.

## Visualizaciones

La interfaz incluye cuatro áreas principales.

### Live wheel / brake assembly

Visualización de la rueda y del estado del freno durante la simulación.

### Road friction curve and ESC search

Muestra la curva:

```text
mu(lambda)
```

junto con:

- el máximo real de la curva,
- la estimación `theta_hat` del ESC,
- el deslizamiento físico actual.

### Live wheel slip and ESC outputs

Permite comparar:

- **Actual slip `lambda`**: deslizamiento físico de la rueda.
- **`lambda_ref`**: referencia enviada al controlador PI interno.
- **`theta_hat`**: estimación del punto de máxima fricción.
- **True optimum**: valor de referencia correspondiente al máximo de la curva.

La oscilación visible en `lambda_ref` es una consecuencia esperada de la señal de modulación utilizada por el ESC.

### Live vehicle / wheel speeds and brake torque

Muestra simultáneamente:

- velocidad longitudinal del vehículo,
- velocidad periférica de la rueda,
- torque de frenado aplicado.

## Simulation pacing

La interfaz permite activar o desactivar **Simulation pacing**.

Cuando está activado, la tasa puede ajustarse entre:

```text
0.1x y 1.0x
```

Esto permite observar con mayor facilidad el comportamiento interactivo del sistema y las señales en tiempo real.

Desactivar pacing permite ejecutar la simulación tan rápido como sea posible.

## Secuencia sugerida

1. Ejecute `run_ABS`.
2. Seleccione **Open Loop**.
3. Presione **Start / Restart**.
4. Mantenga **BRAKE** y observe el comportamiento de la rueda, el slip y las velocidades.
5. Detenga o reinicie la simulación.
6. Seleccione **Closed Loop (ESC)**.
7. Ejecute nuevamente el frenado con los parámetros por defecto.
8. Observe la evolución de `theta_hat`, `lambda_ref` y el deslizamiento real.
9. Modifique los parámetros del ESC y compare el efecto sobre la búsqueda del máximo de fricción.

Para comparar diferentes configuraciones, cambie **un parámetro a la vez** y mantenga condiciones de ensayo similares.

## Reto

En **Closed Loop (ESC)** y bajo la condición **Dry asphalt**, ajuste los parámetros del Extremum Seeking Control para obtener el mayor **Slip tracking score [%]** posible durante el evento de frenado.

El objetivo es mejorar el seguimiento del deslizamiento óptimo sin modificar la planta ni el controlador PI interno. Compare distintas combinaciones de parámetros del ESC y analice cómo afectan la búsqueda del óptimo y las oscilaciones del deslizamiento.

## Referencias

La arquitectura educativa del laboratorio fue desarrollada a partir de documentación y ejemplos de MathWorks.

1. **Anti-Lock Braking Using Extremum Seeking Control**, Simulink Control Design, MathWorks, R2025b.  
   https://www.mathworks.com/help/releases/R2025b/slcontrol/ug/anti-lock-braking-using-extremum-seeking-control.html

2. **Extremum Seeking Control**, Simulink Control Design, MathWorks, R2025b.  
   https://www.mathworks.com/help/releases/R2025b/slcontrol/ug/extremumseekingcontrol.html

3. **Anti-Lock Braking System (ABS)**, Simscape Driveline, MathWorks.  
   https://www.mathworks.com/help/sdl/ug/antilock-braking-system-sdl.html

4. **Tire (Magic Formula)**, Simscape Driveline, MathWorks.  
   https://www.mathworks.com/help/sdl/ref/tiremagicformula.html

Este laboratorio es un modelo académico simplificado destinado al estudio de conceptos de control. No representa un sistema ABS automotriz de producción ni un controlador destinado a aplicaciones de seguridad reales.
