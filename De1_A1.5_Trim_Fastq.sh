#!/bin/bash

# Uso:
#   INPUT_DIR=/ruta/a/fastq OUTPUT_DIR=/ruta/a/salida ./De1_A1.5_Trim_Fastq.sh
#   o: ./De1_A1.5_Trim_Fastq.sh <dir_entrada> <dir_salida>

# Directorios de entrada y salida configurables
INPUT_DIR="${INPUT_DIR:-$1}"
OUTPUT_DIR="${OUTPUT_DIR:-$2}"

if [ -z "$INPUT_DIR" ] || [ -z "$OUTPUT_DIR" ]; then
    echo "Uso: INPUT_DIR=<dir entrada> OUTPUT_DIR=<dir salida> $0"
    echo "   o: $0 <dir entrada> <dir salida>"
    exit 1
fi

# CREAR CARPETA DE SALIDA SI NO EXISTE
mkdir -p "$OUTPUT_DIR"

# RECORRER ARCHIVOS FASTQ EN EL DIRECTORIO DE ENTRADA
for file in "$INPUT_DIR"/*.fastq; do
    filename=$(basename "$file")
    cutadapt -u 30 -u -30 -o "$OUTPUT_DIR/${filename%.fastq}_trimmed.fastq" "$file"
done

# INFORMAR FINALIZACIÓN
echo "Recorte finalizado."
echo "Archivos trimmed guardados en: $(realpath "$OUTPUT_DIR")"
