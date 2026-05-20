#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <MATLAB command>"
  exit 1
fi

MATLAB_CMD="$1"

if [ -x "/mnt/d/MATLAB/R2025b/bin/matlab.exe" ]; then
  exec "/mnt/d/MATLAB/R2025b/bin/matlab.exe" -batch "$MATLAB_CMD"
fi

if command -v matlab >/dev/null 2>&1; then
  exec matlab -batch "$MATLAB_CMD"
fi

for drive in c d e f; do
  for matlab_exe in "/mnt/${drive}/Program Files/MATLAB"/*/bin/matlab.exe; do
    if [ -f "$matlab_exe" ]; then
      exec "$matlab_exe" -batch "$MATLAB_CMD"
    fi
  done
done

echo "MATLAB executable not found."
echo "Install MATLAB on Windows or add the 'matlab' command to PATH, then rerun the VSCode task."
exit 1
