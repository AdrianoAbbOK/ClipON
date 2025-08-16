#!/usr/bin/env bash
set -euo pipefail

# Script to install ClipON environments using mamba
# Checks for conda and mamba availability, installs Miniconda and mamba if requested,
# and creates missing environments from the YAML files in ../envs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="$SCRIPT_DIR/../envs"

# Ensure conda is available, install Miniconda if missing
if ! command -v conda >/dev/null 2>&1; then
  read -rp "Conda no se encontró. ¿Desea instalar Miniconda? [y/N] " resp
  if [[ $resp =~ ^[Yy]$ ]]; then
    installer=/tmp/miniconda.sh
    echo "Descargando Miniconda..."
    if ! wget -O "$installer" https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh; then
      echo "No se pudo descargar Miniconda" >&2
      exit 1
    fi
    echo "Instalando Miniconda en $HOME/miniconda..."
    if ! bash "$installer" -b -p "$HOME/miniconda"; then
      echo "La instalación de Miniconda falló" >&2
      exit 1
    fi
    rm -f "$installer"
    # Habilitar conda en la sesión actual
    if [ -f "$HOME/miniconda/etc/profile.d/conda.sh" ]; then
      . "$HOME/miniconda/etc/profile.d/conda.sh"
    else
      export PATH="$HOME/miniconda/bin:$PATH"
    fi
  else
    echo "Abortando instalación de entornos."
    exit 1
  fi
fi

# Ensure mamba is available
if ! command -v mamba >/dev/null 2>&1; then
  echo "Instalando mamba en el entorno base..."
  if ! conda install -y mamba -n base -c conda-forge; then
    echo "No se pudo instalar mamba" >&2
    exit 1
  fi
fi

# Iterate over YAML files and create missing environments
for yml in "$ENV_DIR"/*.yml; do
  env_name="$(basename "$yml" .yml)"
  if mamba env list | awk '{print $1}' | grep -Fxq "$env_name"; then
    echo "El entorno '$env_name' ya existe."
  else
    read -rp "El entorno '$env_name' no existe. ¿Desea crearlo? [y/N] " ans
    if [[ $ans =~ ^[Yy]$ ]]; then
      mamba env create -f "$yml"
    else
      echo "Omitiendo '$env_name'."
    fi
  fi
  echo
done
