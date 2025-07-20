#!/bin/bash

# Directorio que contiene los archivos .fastq
input_dir="/home/adriano_abb/Qiime/V2/Juan/Clust_By_NGSpecies/Archivos_Ejemplo/Test"
output_dir="/home/adriano_abb/Qiime/V2/Juan/Clust_By_NGSpecies/Archivos_Ejemplo/Test/clustered/" 

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
