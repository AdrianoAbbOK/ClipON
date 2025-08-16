#!/bin/bash
set -e
set -u
set -o pipefail

# Chequeo si NanoFilt está instalado
if ! command -v NanoFilt >/dev/null; then
    echo "Error: NanoFilt no encontrado. Instálalo antes de ejecutar este script." >&2
    exit 1
else
    echo "NanoFilt encontrado. Se procede al filtrado"
fi

# Uso:
#   INPUT_DIR=dir_de_entrada OUTPUT_DIR=dir_de_salida LOG_FILE=registro.log ./De1.5_A2_Filtrado_NanoFilt_1.1.sh
#   o bien
#   ./De1.5_A2_Filtrado_NanoFilt_1.1.sh <dir_entrada> <dir_salida> <archivo_log>

# Directorios y archivo de log configurables
input_dir="${INPUT_DIR:-$1}"
output_dir="${OUTPUT_DIR:-$2}"
log_file="${LOG_FILE:-$3}"

# Parámetros de filtrado con valores por defecto
MIN_LEN="${MIN_LEN:-650}"
MAX_LEN="${MAX_LEN:-750}"
MIN_QUAL="${MIN_QUAL:-10}"

if [ -z "$input_dir" ] || [ -z "$output_dir" ] || [ -z "$log_file" ]; then
    echo "Uso: INPUT_DIR=<dir entrada> OUTPUT_DIR=<dir salida> LOG_FILE=<archivo log> $0"
    echo "   o: $0 <dir entrada> <dir salida> <archivo log>"
    exit 1
fi

# Crear el directorio de salida si no existe
mkdir -p "$output_dir"

# Limpiar el archivo de log antes de comenzar
echo "Proceso de filtrado comenzado a las $(date)" > "$log_file"

# Filtrar todos los archivos FASTQ en la carpeta de entrada
for file in "$input_dir"/*.fastq; do
    # Obtener el nombre del archivo sin la extensión
    base_name="$(basename "$file" .fastq)"

    # Ejecutar NanoFilt y guardar en formato FASTQ
    echo "Filtrando $file..." >> "$log_file"
    output_file="$output_dir/${base_name}_Filt${MIN_LEN}_${MAX_LEN}_Q${MIN_QUAL}.fastq"
    cat "$file" | NanoFilt -l "$MIN_LEN" --maxlength "$MAX_LEN" -q "$MIN_QUAL" > "$output_file" 2>> "$log_file"

    # Verificar si el proceso fue exitoso
    if [ $? -eq 0 ]; then
        echo "Filtrado completado para $file" >> "$log_file"
        python3 scripts/collect_read_stats.py "$output_file" "$output_dir/${base_name}_filtered_stats.tsv" >> "$log_file" 2>&1
    else
        echo "Hubo un error al filtrar $file" >> "$log_file"
    fi
done

echo "Filtrado completado a las $(date)" >> "$log_file"
