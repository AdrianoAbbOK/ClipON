#!/bin/bash
set -e

# Script interactivo para ejecutar el pipeline de ClipON paso a paso
# Nota: la extracción de longitudes y calidades por lectura ya se realiza con
# scripts/collect_read_stats.py

# Determinar la raíz del repositorio y usar rutas relativas
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

echo "========================================================="
echo "Bienvenido al asistente de ejecución de ClipON"
echo "Este script lo guiará para preparar e iniciar el pipeline."
echo "========================================================="
read -rp "Presione Enter para comenzar" _

# Verificar que los entornos requeridos funcionen correctamente
if ! scripts/test_envs.sh; then
    echo "Fallo en la verificación de entornos. Abortando."
    exit 1
fi
echo "========================================================="
echo "Configuración de directorios y bases de datos"
echo "========================================================="

# Elegir entre procesamiento nuevo o reanudación
read -rp "¿Desea iniciar un procesamiento nuevo o reanudar uno previo? (n/r) " run_mode
if [[ $run_mode =~ ^[Rr]$ ]]; then
    MODE="resume"
    while true; do
        read -rp "Ingrese el directorio de trabajo existente: " WORK_DIR
        if [ ! -d "$WORK_DIR" ]; then
            echo "El directorio '$WORK_DIR' no existe o no es accesible. Intente nuevamente."
            continue
        fi
        break
    done
    scripts/check_pipeline_status.sh "$WORK_DIR"
    read -rp "Seleccione el paso de reanudación: " RESUME_STEP
    echo "export RESUME_STEP=\"$RESUME_STEP\"" > "$WORK_DIR/resume_config.sh"
    source "$WORK_DIR/resume_config.sh"
else
    MODE="new"
fi

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

if [ "$MODE" = "new" ]; then
    read -rp "Ingrese el directorio de trabajo donde se guardarán los resultados: " WORK_DIR
    mkdir -p "$WORK_DIR"
fi

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

# Solicitar rutas para bases de datos necesarias
while true; do
    read -rp "Ingrese la ruta al archivo de base de datos BLAST (.qza): " BLAST_DB
    if [ ! -f "$BLAST_DB" ]; then
        echo "El archivo '$BLAST_DB' no existe. Intente nuevamente."
        continue
    fi
    export BLAST_DB
    break
done

while true; do
    read -rp "Ingrese la ruta al archivo de taxonomía (.qza): " TAXONOMY_DB
    if [ ! -f "$TAXONOMY_DB" ]; then
        echo "El archivo '$TAXONOMY_DB' no existe. Intente nuevamente."
        continue
    fi
    export TAXONOMY_DB
    break
done

echo "========================================================="
echo "Resumen de directorios"
echo "========================================================="
echo "  Directorio FASTQ: $INPUT_DIR"
echo "  Directorio de trabajo: $WORK_DIR"
if [ "$MODE" = "resume" ]; then
    echo "  Reanudación desde el paso: $RESUME_STEP"
fi
if [ "$SKIP_TRIM" -eq 1 ]; then
    echo "  Recorte: no"
else
    echo "  Recorte: sí (inicio $TRIM_FRONT, final $TRIM_BACK)"
fi
echo "  Base de datos BLAST: $BLAST_DB"
echo "  Base de datos de taxonomía: $TAXONOMY_DB"
read -rp "¿Continuar con la ejecución del pipeline? (y/n) " go
if [[ ! $go =~ ^[Yy]$ ]]; then
    echo "Operación cancelada por el usuario."
    exit 0
fi

echo "Iniciando pipeline..."

SKIP_TRIM="$SKIP_TRIM" TRIM_FRONT="$TRIM_FRONT" TRIM_BACK="$TRIM_BACK" \
    scripts/run_clipon_pipeline.sh "$INPUT_DIR" "$WORK_DIR"

echo "Ejecución finalizada. Resultados en: $WORK_DIR"
