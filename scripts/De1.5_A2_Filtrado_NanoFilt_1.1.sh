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

if [ -z "$input_dir" ] || [ -z "$output_dir" ] || [ -z "$log_file" ]; then
    echo "Uso: INPUT_DIR=<dir entrada> OUTPUT_DIR=<dir salida> LOG_FILE=<archivo log> $0"
    echo "   o: $0 <dir entrada> <dir salida> <archivo log>"
    exit 1
fi

# Crear el directorio de salida si no existe
mkdir -p "$output_dir"

# Preparar archivo de estadísticas
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stats_file="$output_dir/read_stats_filtrado.tsv"
echo -e "archivo\tlecturas\tlongitud_media\tcalidad_media" > "$stats_file"

# Limpiar el archivo de log antes de comenzar
echo "Proceso de filtrado comenzado a las $(date)" > "$log_file"

# Filtrar todos los archivos FASTQ en la carpeta de entrada
for file in "$input_dir"/*.fastq; do
    # Obtener el nombre del archivo sin la extensión
    base_name="$(basename "$file" .fastq)"
    output_file="$output_dir/${base_name}_Filt650_750_Q10.fastq"

    # Ejecutar NanoFilt y guardar en formato FASTQ
    echo "Filtrando $file..." >> "$log_file"
    cat "$file" | NanoFilt -l 650 --maxlength 750 -q 10 > "$output_file" 2>> "$log_file"

    # Verificar si el proceso fue exitoso
    if [ $? -eq 0 ]; then
        echo "Filtrado completado para $file" >> "$log_file"
        if [ -s "$output_file" ]; then
            python "$script_dir/collect_read_stats.py" "$output_file" >> "$stats_file"
        fi
    else
        echo "Hubo un error al filtrar $file" >> "$log_file"
    fi
done

echo "Filtrado completado a las $(date)" >> "$log_file"
