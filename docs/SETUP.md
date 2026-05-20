# VSCode Setup

This project is scaffolded for MATLAB development in VSCode.

## What is configured

- `.m` files are associated with MATLAB language mode.
- Temporary MATLAB autosave files are hidden from Explorer and Search.
- A VSCode task named `Run main.m` is available.
- The task uses `scripts/run_matlab.sh`, which first checks `matlab` on PATH and then common Windows install paths under `C/D/E/F`.

## Prerequisite

MATLAB must be installed on your machine.

Supported launch modes:

- `matlab` is available in the VSCode terminal PATH
- MATLAB is installed in a default Windows location such as `C:\Program Files\MATLAB\R20xx\bin\matlab.exe`

If neither is true, the VSCode task will stop with a clear error message.

## Run

Open the command palette in VSCode and run:

`Tasks: Run Task` -> `Run main.m`
