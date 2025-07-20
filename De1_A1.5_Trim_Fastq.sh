#!/bin/bash

# DEFINIR DIRECTORIOS
INPUT_DIR="/home/adriano_abb/Qiime/V2/ParaPoster/parsed"          # Reemplazá con tu directorio real de entrada
OUTPUT_DIR="/home/adriano_abb/Qiime/V2/ParaPoster/parsed/trimmed"    # Reemplazá con donde querés guardar los recortados

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
