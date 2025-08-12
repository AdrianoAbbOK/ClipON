#!/bin/bash
set -e
set -u
set -o pipefail

# Verificar si seqkit está instalado
if ! command -v seqkit &> /dev/null; then
    echo "SeqKit no está instalado. Por favor, instálalo antes de continuar." >&2
    exit 1
fi

# Uso:
#   INPUT_DIR=/ruta/a/fastq OUTPUT_DIR=/ruta/a/salida ./De0_A1_Process_Fastq.4_SeqKit.sh
#   o bien
#   ./De0_A1_Process_Fastq.4_SeqKit.sh /ruta/a/fastq /ruta/a/salida

# Directorios de entrada y salida configurables por variables o argumentos
INPUT_DIR="${INPUT_DIR:-$1}"
OUTPUT_DIR="${OUTPUT_DIR:-$2}"
LOG_FILE="${LOG_FILE:-"$OUTPUT_DIR/process_fastq.log"}"

# Comprobar que se proporcionaron las rutas
if [ -z "$INPUT_DIR" ] || [ -z "$OUTPUT_DIR" ]; then
    echo "Uso: INPUT_DIR=<dir entrada> OUTPUT_DIR=<dir salida> $0" >&2
    echo "   o: $0 <dir entrada> <dir salida>" >&2
    exit 1
fi

# Verificar si los directorios existen
if [ ! -d "$INPUT_DIR" ]; then
    echo "El directorio de entrada no existe: $INPUT_DIR" >&2
    exit 1
fi

if [ ! -d "$OUTPUT_DIR" ]; then
    mkdir -p "$OUTPUT_DIR"
fi

# Preparar rutas para el script de estadísticas
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAW_STATS_FILE="$OUTPUT_DIR/read_stats_crudo.tsv"
PROC_STATS_FILE="$OUTPUT_DIR/read_stats_procesado.tsv"
echo -e "archivo\tlecturas\tlongitud_media\tcalidad_media" > "$RAW_STATS_FILE"
echo -e "archivo\tlecturas\tlongitud_media\tcalidad_media" > "$PROC_STATS_FILE"

# Crear o vaciar archivo de log
printf "Log de De0_A1_Process_Fastq.4_SeqKit.sh - %s\n" "$(date)" > "$LOG_FILE"

# Procesar cada archivo FASTQ en el directorio de entrada
files_processed=0
for file in "$INPUT_DIR"/*.fastq; do
    if [ -f "$file" ]; then
        python "$script_dir/collect_read_stats.py" "$file" >> "$RAW_STATS_FILE"
        files_processed=$((files_processed + 1))
        CLEANED_FILE="${OUTPUT_DIR}/cleaned_$(basename "$file")"
        {
            echo "Procesando archivo: $file"
            echo "Filtrando secuencias mal formateadas con seqkit sana: $CLEANED_FILE"
            seqkit sana "$file" -o "$CLEANED_FILE"
            if [ ! -s "$CLEANED_FILE" ]; then
                echo "Advertencia: El archivo $file no tiene secuencias válidas después del filtrado. Se omite."
            else
                echo "Archivo limpio guardado en: $CLEANED_FILE"
            fi
        } >> "$LOG_FILE" 2>&1
        if [ -s "$CLEANED_FILE" ]; then
            python "$script_dir/collect_read_stats.py" "$CLEANED_FILE" >> "$PROC_STATS_FILE"
        fi
    fi
done

echo "Proceso completado. Se procesaron $files_processed archivos. Detalles en $LOG_FILE. Los archivos filtrados están en: $OUTPUT_DIR"
