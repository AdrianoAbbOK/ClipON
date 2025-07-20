#!/bin/bash

# Chequeo si NanoFilt está instalado
if ! command -v NanoFilt &> /dev/null
then
    echo "NanoFilt no está instalado. Instalando..."
    # Intentamos instalarlo con conda
    conda install -c bioconda nanofilt -y
    # O si prefieres usar pip
    # pip install NanoFilt
    # Verifica si la instalación fue exitosa
    if ! command -v NanoFilt &> /dev/null
    then
        echo "No se pudo instalar NanoFilt. Por favor, instálalo manualmente." >&2
        exit 1
    else
        echo "NanoFilt instalado correctamente."
    fi
else
    echo "NanoFilt ya está instalado. Se procede al Filtrado"
fi

# Definir los directorios de entrada y salida
input_dir="/home/adriano_abb/Qiime/V2/Juan/Limpieza_Filtrado_DeSecCrudas/Archivos_ejemplo_Mock/parsed/"  # Cambia esta ruta según tu ubicación de entrada
output_dir="/home/adriano_abb/Qiime/V2/Juan/Limpieza_Filtrado_DeSecCrudas/Archivos_ejemplo_Mock/parsed/filtered2/"
log_file="/home/adriano_abb/Qiime/V2/Juan/Limpieza_Filtrado_DeSecCrudas/Archivos_ejemplo_Mock/parsed/filtered2/filtering_process.log"

# Crear el directorio de salida si no existe
mkdir -p "$output_dir"

# Limpiar el archivo de log antes de comenzar
echo "Proceso de filtrado comenzado a las $(date)" > "$log_file"

# Filtrar todos los archivos FASTQ en la carpeta de entrada
for file in "$input_dir"*.fastq; do
    # Obtener el nombre del archivo sin la extensión
    base_name="$(basename "$file" .fastq)"
    
    # Ejecutar NanoFilt y guardar en formato FASTQ
    echo "Filtrando $file..." >> "$log_file"
    cat "$file" | NanoFilt -l 650 --maxlength 750 -q 10 > "$output_dir/${base_name}_Filt650_750_Q10.fastq" 2>> "$log_file"
    
    # Verificar si el proceso fue exitoso
    if [ $? -eq 0 ]; then
        echo "Filtrado completado para $file" >> "$log_file"
    else
        echo "Hubo un error al filtrar $file" >> "$log_file"
    fi
done

echo "Filtrado completado a las $(date)" >> "$log_file"
