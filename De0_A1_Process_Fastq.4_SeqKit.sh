#!/bin/bash
set -e
set -u

# Verificar si seqkit está instalado
if ! command -v seqkit &> /dev/null
then
    echo "SeqKit no está instalado. Por favor, instálalo antes de continuar."
    exit 1
fi

# Uso:
#   INPUT_DIR=/ruta/a/fastq OUTPUT_DIR=/ruta/a/salida ./De0_A1_Process_Fastq.4_SeqKit.sh
#   o bien
#   ./De0_A1_Process_Fastq.4_SeqKit.sh /ruta/a/fastq /ruta/a/salida

# Directorios de entrada y salida configurables por variables o argumentos
INPUT_DIR="${INPUT_DIR:-$1}"
OUTPUT_DIR="${OUTPUT_DIR:-$2}"

# Comprobar que se proporcionaron las rutas
if [ -z "$INPUT_DIR" ] || [ -z "$OUTPUT_DIR" ]; then
    echo "Uso: INPUT_DIR=<dir entrada> OUTPUT_DIR=<dir salida> $0"
    echo "   o: $0 <dir entrada> <dir salida>"
    exit 1
fi

# Verificar si los directorios existen
if [ ! -d "$INPUT_DIR" ]; then
    echo "El directorio de entrada no existe: $INPUT_DIR"
    exit 1
fi

if [ ! -d "$OUTPUT_DIR" ]; then
    echo "El directorio de salida no existe, creando..."
    mkdir -p "$OUTPUT_DIR"
fi

# Procesar cada archivo FASTQ en el directorio de entrada
for file in "$INPUT_DIR"/*.fastq; do
    if [ -f "$file" ]; then
        echo "Procesando archivo: $file"

        # Filtrar secuencias mal formateadas con seqkit sana
        CLEANED_FILE="${OUTPUT_DIR}/cleaned_$(basename "$file")"
        echo "Filtrando secuencias mal formateadas con seqkit sana: $CLEANED_FILE"
        
        # Filtrar las secuencias mal formateadas
        seqkit sana "$file" -o "$CLEANED_FILE"

        # Verificar si el archivo tiene contenido después del filtrado
        if [ ! -s "$CLEANED_FILE" ]; then
            echo "Advertencia: El archivo $file no tiene secuencias válidas después del filtrado. Se omite."
            continue
        fi

        echo "Archivo limpio guardado en: $CLEANED_FILE"
    fi
done

echo "Proceso completado. Los archivos filtrados están en: $OUTPUT_DIR"
