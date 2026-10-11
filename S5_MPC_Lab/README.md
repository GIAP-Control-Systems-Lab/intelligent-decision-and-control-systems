# =========================================================================
# MaIA_SDCI - Semana 5: Model Predictive Control
# Sistemas de Decisión y Control Inteligente
# Universidad de los Andes, 2026
#
# Copyright (c) 2026 Leffer Trochez
# =========================================================================

# Two Coupled Tanks | Interactive Model Predictive Control Laboratory

Laboratorio interactivo para estudiar **Model Predictive Control (MPC)** aplicado a un sistema de **dos tanques hidráulicos acoplados**, implementado con MATLAB, Simulink y Simscape.

El laboratorio permite modificar la configuración del MPC, observar los niveles de agua y el caudal de la bomba, explorar las predicciones del controlador y analizar el efecto de las referencias, los pesos, los horizontes y las restricciones sobre el comportamiento del sistema.

## Archivos principales

- `S5_MPC_Lab.slx`: modelo Simulink/Simscape de la planta de dos tanques y su controlador.
- `run_TwoTank.m`: punto de entrada, configuración e interfaz gráfica interactiva.
- `TwoTank_LiveDataCallback.m`: recepción de señales durante la simulación.
- `MPC_TwoTank_Controller.mat`: controlador MPC que se carga automáticamente.
- `TwoTank_LinearizedPlant.mat`: modelo linealizado empleado como base para el diseño del MPC.
- `README.md`: descripción y guía de uso del laboratorio.

La carpeta `cache/` y otros archivos temporales de Simulink pueden regenerarse y no son necesarios para distribuir el proyecto.

## Requisitos

El laboratorio se desarrolló para **MATLAB R2025b** y utiliza:

- MATLAB
- Simulink
- Simscape
- Simscape Fluids
- Model Predictive Control Toolbox

## Ejecución

Ubique los archivos principales en una misma carpeta y selecciónela como **Current Folder** en MATLAB. Ejecute:

```matlab
run_TwoTank
```

La GUI se abrirá automáticamente. No es necesario cargar manualmente el controlador MPC ni los archivos `.mat`.

Para inspeccionar el diagrama de bloques, utilice **Open Simulink**.

## Planta: dos tanques acoplados

La planta representa un sistema hidráulico con una bomba, dos tanques, conexiones de fluido y un reservorio.

- **Entrada manipulada (`q_in`)**: caudal total suministrado por la bomba.
- **Salidas medidas (`h1`, `h2`)**: niveles de agua en los tanques.
- **Acoplamiento hidráulico**: el movimiento del agua entre los tanques depende de la dinámica física y de sus niveles.
- **Restricciones**: los niveles y el caudal deben permanecer dentro de los límites establecidos.

La configuración simulada distribuye el caudal de entrada entre los tanques y considera el flujo por gravedad desde el tanque superior hacia el inferior y la descarga hacia el reservorio.

Es un sistema **SIMO (Single Input, Multiple Outputs)**: dispone de una entrada manipulada y dos salidas que responden a ella. Por estar acopladas, las salidas no pueden ajustarse de forma completamente independiente con la bomba disponible.

> **Nota:** el esquema de la GUI es una representación didáctica. La válvula de drenaje adicional mostrada como cerrada es una referencia visual de hardware y no constituye una entrada de control ajustable en este laboratorio.

## Control predictivo (MPC)

El MPC utiliza un modelo de la planta para predecir su comportamiento futuro y calcular una secuencia de acciones de control que busque cumplir las referencias y respetar las restricciones.

En cada instante de control, el MPC:

1. Utiliza la información disponible sobre los niveles.
2. Predice cómo podrían evolucionar las salidas.
3. Optimiza las acciones futuras de la bomba.
4. Aplica la acción de control correspondiente y repite el proceso.

Este mecanismo se conoce como **horizonte deslizante** (*receding horizon*).

## Parámetros disponibles en la GUI

### Referencias — LIVE

- **Tank 1 reference (`h1_ref`)**: nivel deseado para el tanque superior.
- **Tank 2 reference (`h2_ref`)**: nivel deseado para el tanque inferior.

Las referencias pueden modificarse durante la simulación.

### Horizontes MPC — Run / Restart

- **Prediction horizon (`P`)**: intervalo futuro que el controlador considera en sus predicciones.
- **Control horizon (`M`)**: intervalo de acciones de control futuras que optimiza directamente.

### Pesos MPC — Run / Restart

- **`Wy1` y `Wy2`**: importancia de los errores de seguimiento de cada tanque.
- **`Wu`**: penalización asociada a la magnitud del caudal de control.
- **`Wdu`**: penalización asociada a las variaciones del caudal de control.

Estos pesos permiten explorar diferentes compromisos entre seguimiento, esfuerzo de control y suavidad.

### Restricciones — Run / Restart

- **`q_min`, `q_max`**: límites del caudal de la bomba.
- **`h1_max`, `h2_max`**: límites superiores configurados para los niveles.

Los cambios en horizontes, pesos y restricciones se aplican al presionar **Run / Restart**.

## Interfaz y visualizaciones

### Live two-tank system

Esquema hidráulico animado que presenta los niveles de los tanques, las referencias y la dirección ilustrativa del flujo de agua.

### MPC signals — past behavior and receding prediction horizon

Gráfica que reúne:

- historial de `h1` y `h2`,
- referencias de ambos tanques,
- historial del caudal `q_in`,
- predicciones futuras de los niveles (`y.seq`),
- secuencia óptima de caudal (`mv.seq`),
- instante actual y zona sombreada del horizonte de predicción,
- límites máximos de nivel.

Las predicciones representan la evolución calculada por el controlador; no son mediciones futuras.

### Live MPC information

El panel presenta los niveles, el caudal actual y los indicadores del controlador:

- **Optimal cost**: valor de la función de costo utilizada por el MPC.
- **QP status**: información sobre el estado del problema de optimización.
- **Tank 1 absolute error**: diferencia absoluta entre el nivel medido y su referencia.
- **Tank 2 absolute error**: diferencia absoluta entre el nivel medido y su referencia.
- **Total absolute error**: suma de los errores absolutos de ambos tanques.

Los errores se actualizan a partir de las mediciones y conservan sus valores finales al terminar la ejecución. El **Optimal cost** no debe compararse directamente entre configuraciones que utilizan pesos diferentes.

## Controles de simulación

- **Run / Restart**: inicia o reinicia la simulación con la configuración seleccionada.
- **Pause / Continue**: pausa o reanuda la ejecución.
- **Stop**: detiene la simulación.
- **Open Simulink**: abre el modelo.
- **Defaults**: restaura los ajustes iniciales de la interfaz.
- **Clear Plots**: limpia el historial gráfico.
- **Enable pacing / Speed**: limita o modifica la velocidad de reproducción de la simulación.
- **Stop time**: define el tiempo final de simulación y se aplica en el siguiente **Run / Restart**.

Con **pacing** desactivado, Simulink ejecuta el modelo sin limitar la velocidad; la GUI puede recuperar las señales registradas al finalizar, aunque no se visualice cada instante durante la ejecución.

## Secuencia sugerida

1. Ejecute `run_TwoTank` e identifique la planta y las variables de la interfaz.
2. Inicie la simulación con la configuración inicial.
3. Observe la respuesta de los tanques, el caudal y las predicciones.
4. Modifique una referencia durante la ejecución y analice la respuesta.
5. Reinicie la simulación para ensayar distintos horizontes, pesos o restricciones.
6. Compare las curvas, los errores y la acción de control entre configuraciones.
7. Registre sus observaciones y explique los compromisos encontrados.

Para facilitar las comparaciones, modifique **un parámetro a la vez** durante los experimentos exploratorios y utilice condiciones de simulación equivalentes.

## Reto: MPC Precision Challenge

Diseñe una configuración del MPC que consiga **acercar ambos niveles a sus respectivas referencias**, evitando concentrar el desempeño únicamente en uno de los tanques.

El reto se evalúa con los **errores absolutos finales** de los dos niveles. El criterio principal es minimizar el **mayor error individual**; el error absoluto total sirve como criterio secundario de comparación.

Los equipos deben entregar una **captura final de la GUI**, sus parámetros de ajuste y una explicación breve de los resultados.

Durante la competencia, mantenga las condiciones comunes establecidas por el docente y **no modifique la planta, el código, el tiempo del reto ni las referencias de evaluación**. La solución debe encontrarse experimentalmente mediante los controles permitidos en la interfaz.

## Alcance

Este es un modelo académico simplificado para estudiar MPC, predicción, restricciones y acoplamiento hidráulico. Su objetivo es facilitar la exploración de conceptos de control, no reproducir todos los detalles de una instalación industrial.
