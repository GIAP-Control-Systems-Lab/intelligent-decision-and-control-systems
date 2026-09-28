# MaIA_SDCI Final Project — Python

Sistemas de Decision y Control Inteligente (SDCI)  
Universidad de los Andes, 2026

Copyright (c) 2026 Leffer Trochez

## Purpose

This is the Python implementation of the MaIA_SDCI temperature-control final project.

The Python version preserves the same project concepts and controller interface used in the MATLAB/Simulink version while remaining fully independent of MATLAB.

All project source code is stored in Jupyter notebooks (`.ipynb`). The same notebooks are intended to run locally in VS Code/Jupyter and online in Google Colab.

No MATLAB-specific files are required, including:

```text
.m
.slx
.fis
.mat
```

## Course architecture

The project infrastructure is provided to the students.

Students should work only in the five controller implementation notebooks inside:

```text
config/controller/
```

The student-editable notebooks are:

```text
on_off_parameters.ipynb
fuzzy_parameters.ipynb
mpc_parameters.ipynb
esc_parameters.ipynb
replicator_parameters.ipynb
```

`controller_parameters.ipynb` is project infrastructure and should not be modified by students.

All controller parameters, states, algorithms, optimization, fuzzy inference, filters, and other controller-specific logic must remain inside the controller folder.

The plant model, actuator, sensors, disturbances, GUI, metrics, and project startup must not contain controller algorithms.

### Fixed controller interface

Every controller uses exactly the same runtime interface:

```python
duty_cycle = controller.step(
    T_ref,
    T_error,
    T_meas,
)
```

Inputs:

```text
T_ref    -> 4-element temperature-reference vector
T_error  -> 4-element error vector, T_ref - T_meas
T_meas   -> 4-element measured-temperature vector
```

Output:

```text
duty_cycle -> 4-element vector in [0, 1]
```

Each controller must also provide:

```python
controller.reset()
```

`reset()` is called at the beginning of every new simulation so that controller states do not carry over from a previous run.

For the ESC experiment, the isolated Room 5 experiment uses the first channel of the common four-channel software interface. The GUI displays that channel as Room 5.

## Project structure

```text
MaIA_SDCI_Final_Project_Python/
│
├── MaIA_SDCI_Temperature_Control.ipynb
├── startup_project.ipynb
├── requirements.txt
├── README.md
├── PROJECT_STRUCTURE.txt
│
├── app/
│   ├── Control_App.ipynb
│   ├── launch_app.ipynb
│   └── configure_logging.ipynb
│
├── config/
│   ├── project_config.ipynb
│   ├── environment_parameters.ipynb
│   ├── sensor_parameters.ipynb
│   ├── model_parameters.ipynb
│   │
│   ├── model/
│   │   ├── actuator_parameters.ipynb
│   │   └── plant_parameters.ipynb
│   │
│   └── controller/
│       ├── controller_parameters.ipynb
│       ├── on_off_parameters.ipynb
│       ├── fuzzy_parameters.ipynb
│       ├── mpc_parameters.ipynb
│       ├── esc_parameters.ipynb
│       └── replicator_parameters.ipynb
│
├── utilities/
│   ├── compute_metrics.ipynb
│   └── save_results.ipynb
│
└── results/
```

`results/` is created automatically if it does not exist.


## Main files

### `startup_project.ipynb`

This is the main entry point.

It:

- locates the project root;
- checks the required Python dependencies;
- validates the required source folders;
- creates `results/` when necessary;
- loads the project notebooks in the required order;
- creates the configuration structures;
- launches the GUI.

Always start the project from this notebook.

### `MaIA_SDCI_Temperature_Control.ipynb`

This is the equation-based simulation engine that functionally replaces the Simulink execution layer.

It contains:

- actuator execution;
- thermal plant dynamics;
- sensor dynamics;
- disturbances;
- numerical integration;
- project signal generation;
- generic communication with the selected controller.

It does not implement ON/OFF, Fuzzy, MPC, ESC, or Replicator algorithms.

The simulation engine only communicates with the selected controller through:

```python
duty_cycle = controller.step(
    T_ref,
    T_error,
    T_meas,
)
```

### `app/Control_App.ipynb`

This notebook contains the interactive `ipywidgets` GUI.

It provides:

- experiment name;
- controller selection;
- temperature references;
- ambient temperature;
- disturbance configuration;
- simulation stop time;
- pacing configuration;
- START / PAUSE / STOP;
- Clear Plots;
- Save Metrics;
- temperature and heater-power plots;
- status information.

The interface automatically uses the available notebook width.

When metrics are saved, the PNG contains a representation of the complete GUI, including the control panel and both plots.

### `app/launch_app.ipynb`

Creates or redisplays the GUI application.

### `app/configure_logging.ipynb`

Defines and validates the stable project signal names used by the GUI.

### `config/project_config.ipynb`

Contains shared project configuration such as:

- project name;
- stop time;
- pacing;
- four-room temperature references;
- ESC / Room 5 reference;
- logged signals.

### `config/environment_parameters.ipynb`

Contains:

- ambient temperature;
- disturbance enable state;
- disturbance amplitude;
- disturbance start and end times;
- affected rooms.

### `config/sensor_parameters.ipynb`

Contains sensor dynamics and measurement parameters.

### `config/model_parameters.ipynb`

Creates the complete plant/actuator model parameter structure.

### `config/model/actuator_parameters.ipynb`

Contains heater and actuator parameters.

### `config/model/plant_parameters.ipynb`

Contains the analytical four-room and single-room thermal models.

### `config/controller/controller_parameters.ipynb`

Registers the controllers and defines the common controller contract.

This file contains no individual controller algorithm.

### Controller notebooks

The complete implementation of each controller is contained in its corresponding notebook:

```text
config/controller/on_off_parameters.ipynb
config/controller/fuzzy_parameters.ipynb
config/controller/mpc_parameters.ipynb
config/controller/esc_parameters.ipynb
config/controller/replicator_parameters.ipynb
```

For the student version, these notebooks can be distributed as templates containing the required input/output interface and the code structure to complete.

No part of a controller algorithm should be moved into the plant model, GUI, utilities, or other project notebooks.

### `utilities/compute_metrics.ipynb`

Computes the project performance metrics, including:

- RMSE;
- IAE;
- ISE;
- steady-state error;
- settling time;
- overshoot;
- energy;
- peak power.

### `utilities/save_results.ipynb`

Saves:

- the metrics table as CSV;
- the complete GUI snapshot as PNG.

Files are written to:

```text
results/
```

## Python version

Python 3.11 is recommended.

Python 3.10 is also supported.

## Local use with VS Code

### 1. Install Python

Install Python 3.11 or Python 3.10 from:

```text
https://www.python.org/
```

On Windows, you can check the installed versions with:

```powershell
py -0p
```

For example:

```powershell
py -3.10 --version
```

### 2. Install Visual Studio Code

Install Visual Studio Code from:

```text
https://code.visualstudio.com/
```

### 3. Install the VS Code extensions

Install the Microsoft extensions:

- Python
- Jupyter

### 4. Open the complete project folder

In VS Code:

```text
File → Open Folder...
```

Open:

```text
MaIA_SDCI_Final_Project_Python
```

Do not open only an individual notebook.

### 5. Install the requirements

Open a terminal in the project root.

Windows with Python 3.11:

```powershell
py -3.11 -m pip install -r requirements.txt
```

Windows with Python 3.10:

```powershell
py -3.10 -m pip install -r requirements.txt
```

macOS / Linux:

```bash
python3 -m pip install -r requirements.txt
```

### 6. Open the startup notebook

Open:

```text
startup_project.ipynb
```

### 7. Select the Python kernel

At the upper-right corner of the notebook, select:

```text
Select Kernel → Python Environments
```

Choose the same Python installation where the requirements were installed.

### 8. Run the project

Select:

```text
Run All
```

The GUI will appear directly inside the notebook.

### 9. VS Code widget downloads

The first time the GUI is displayed, VS Code may show:

```text
Widgets require us to download supporting files from a 3rd party website.
```

If this message appears, click:

```text
Enable Downloads
```

Wait a few seconds.

If the GUI does not appear automatically, run:

```text
Run All
```

again.

No project source file needs to be changed.

### 10. Larger / full-screen workspace

The GUI is embedded in the notebook rather than opened in a separate desktop window.

In VS Code, use:

```text
F11
```

for full-screen mode.

You can also use Zen Mode:

```text
Ctrl + K, then Z
```

The GUI automatically expands to the available notebook width.

## Google Colab

The same project notebooks are used in Google Colab.

No separate Colab implementation is required.

### 1. Upload the complete project

Place the complete project folder either:

- in `/content`, or
- in Google Drive.

### 2. Open `startup_project.ipynb`

Open the same startup notebook in Colab.

### 3. Install requirements if necessary

For a project in `/content`:

```python
!pip install -r /content/MaIA_SDCI_Final_Project_Python/requirements.txt
```

For a project in the root of Google Drive:

```python
!pip install -r /content/drive/MyDrive/MaIA_SDCI_Final_Project_Python/requirements.txt
```

### 4. Run all cells

Use:

```text
Runtime → Run all
```

The startup notebook locates the project and launches the same `ipywidgets` GUI.

## Generated files

The only project output folder is:

```text
results/
```

It may be deleted at any time.

`startup_project.ipynb` recreates it automatically when required.

## Portability

All runtime paths are derived from the detected project root.

No user-specific or computer-specific absolute paths are stored in the project.

The same source notebooks are intended to run without modification in:

- VS Code with Jupyter;
- local Jupyter environments;
- Google Colab.
