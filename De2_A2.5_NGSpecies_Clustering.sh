#!/bin/bash

# Uso:
#   INPUT_DIR=/ruta/a/fastq OUTPUT_DIR=/ruta/a/salida ./De2_A2.5_NGSpecies_Clustering.sh
#   o: ./De2_A2.5_NGSpecies_Clustering.sh <dir_entrada> <dir_salida>

# Directorio que contiene los archivos .fastq y salida configurables
input_dir="${INPUT_DIR:-$1}"
output_dir="${OUTPUT_DIR:-$2}"

if [ -z "$input_dir" ] || [ -z "$output_dir" ]; then
    echo "Uso: INPUT_DIR=<dir entrada> OUTPUT_DIR=<dir salida> $0"
    echo "   o: $0 <dir entrada> <dir salida>"
    exit 1
fi

# Crear el directorio de salida si no existe
mkdir -p "$output_dir"

# Iterar sobre todos los archivos .fastq en el directorio
for fastq_file in "$input_dir"/*.fastq; do
    # Extraer el nombre base del archivo (sin la ruta ni la extensión)
    base_name=$(basename "$fastq_file" .fastq)
    
    # Mostrar mensaje indicando el archivo que se está procesando
    echo "Procesando archivo: $base_name.fastq"
    
    # Ejecutar el comando para cada archivo .fastq
    NGSpeciesID --ont --consensus --m 700 --s 150 --medaka --t 16 --q 10 \
                --rc_identity_threshold 0.98 --abundance_ratio 0.01 \
                --fastq "$fastq_file" --outfolder "$output_dir/$base_name"
    
    # Verificar si el comando fue exitoso
    if [ $? -ne 0 ]; then
        echo "Error al procesar el archivo: $base_name.fastq. Saliendo."
        exit 1
    fi
done

echo "Procesamiento completado para todos los archivos .fastq."
