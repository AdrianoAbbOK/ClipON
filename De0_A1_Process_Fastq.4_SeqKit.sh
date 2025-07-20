#!/bin/bash

# Verificar si seqkit está instalado
if ! command -v seqkit &> /dev/null
then
    echo "SeqKit no está instalado. Por favor, instálalo antes de continuar."
    exit 1
fi

# Definir los directorios de entrada y salida
INPUT_DIR="/home/adriano_abb/Qiime/V2/Juan/Limpieza_Filtrado_DeSecCrudas/Archivos_ejemplo_Mock"
OUTPUT_DIR="/home/adriano_abb/Qiime/V2/Juan/Limpieza_Filtrado_DeSecCrudas/Archivos_ejemplo_Mock/parsed"

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
