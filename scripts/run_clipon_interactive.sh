#!/bin/bash
set -e

# Script interactivo para ejecutar el pipeline de ClipON paso a paso

echo "========================================================="
echo "Bienvenido al asistente de ejecución de ClipON"
echo "Este script lo guiará para preparar e iniciar el pipeline."
echo "========================================================="
read -rp "Presione Enter para comenzar" _

echo "\n-- Verificando instalación de Conda --"
if ! command -v conda >/dev/null; then
    echo "No se encontró 'conda' en el sistema."
    read -rp "¿Desea instalar Miniconda? (y/n) " ans
    if [[ $ans =~ ^[Yy]$ ]]; then
        echo "Por favor instale Miniconda desde: https://docs.conda.io/en/latest/miniconda.html"
        echo "Luego vuelva a ejecutar este script."
        exit 1
    else
        echo "No es posible continuar sin conda. Abortando."
        exit 1
    fi
else
    echo "Conda detectado."
fi

# Verificar entornos requeridos
REQUIRED_ENVS=(clipon-prep clipon-qiime clipon-ngs)
for env in "${REQUIRED_ENVS[@]}"; do
    if conda env list | awk '{print $1}' | grep -Fxq "$env"; then
        echo "Entorno '$env' encontrado."
    else
        echo "Entorno '$env' no encontrado."
        read -rp "¿Crear entorno '$env'? (y/n) " create
        if [[ $create =~ ^[Yy]$ ]]; then
            if [ -f "envs/${env}.yml" ]; then
                conda env create -f "envs/${env}.yml"
            else
                echo "Archivo envs/${env}.yml no existe."
            fi
        fi
    fi
    echo
done

while true; do
    read -rp "Ingrese el directorio que contiene los archivos FASTQ: " INPUT_DIR
    if [ ! -d "$INPUT_DIR" ]; then
        echo "El directorio '$INPUT_DIR' no existe o no es accesible. Intente nuevamente."
        continue
    fi
    shopt -s nullglob
    fastqs=("$INPUT_DIR"/*.fastq "$INPUT_DIR"/*.fq)
    shopt -u nullglob
    if [ ${#fastqs[@]} -eq 0 ]; then
        echo "No se encontraron archivos FASTQ en '$INPUT_DIR'. Intente nuevamente."
        continue
    fi
    break
done

read -rp "Ingrese el directorio de trabajo donde se guardarán los resultados: " WORK_DIR
mkdir -p "$WORK_DIR"

# Paso opcional de recorte de secuencias
read -rp "¿Desea recortar las secuencias con cutadapt? (y/n) " do_trim
if [[ $do_trim =~ ^[Yy]$ ]]; then
    read -rp "Número de bases a recortar del inicio: " TRIM_FRONT
    read -rp "Número de bases a recortar del final: " TRIM_BACK
    SKIP_TRIM=0
else
    SKIP_TRIM=1
    TRIM_FRONT=0
    TRIM_BACK=0
fi

echo "\nResumen de configuración:"
echo "  Directorio FASTQ: $INPUT_DIR"
echo "  Directorio de trabajo: $WORK_DIR"
if [ "$SKIP_TRIM" -eq 1 ]; then
    echo "  Recorte: no"
else
    echo "  Recorte: sí (inicio $TRIM_FRONT, final $TRIM_BACK)"
fi
read -rp "¿Continuar con la ejecución del pipeline? (y/n) " go
if [[ ! $go =~ ^[Yy]$ ]]; then
    echo "Operación cancelada por el usuario."
    exit 0
fi

echo "\nIniciando pipeline..."

SKIP_TRIM="$SKIP_TRIM" TRIM_FRONT="$TRIM_FRONT" TRIM_BACK="$TRIM_BACK" \
    scripts/run_clipon_pipeline.sh "$INPUT_DIR" "$WORK_DIR"

echo "Ejecución finalizada. Resultados en: $WORK_DIR"
