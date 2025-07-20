#!/bin/bash

# Directorio base donde están las carpetas
BASE_DIR="/home/adriano_abb/Qiime/Res_Experim/expCOI/clustered"

# Directorio de salida donde se guardarán los archivos unificados
DIR_SALIDA="$BASE_DIR/Consensos_unificado"

# Crear el directorio de salida si no existe
mkdir -p "$DIR_SALIDA"

# Archivo maestro que contendrá todas las secuencias con el identificador de experimento
archivo_maestro="$DIR_SALIDA/consensos_todos.fasta"

# Inicializar una variable para verificar si se han procesado secuencias
se_agregaron_secuencias=false

# Recorrer todas las carpetas dentro del directorio base
for carpeta in "$BASE_DIR"/*; do
  if [ -d "$carpeta" ]; then
    # Extraer el nombre de la carpeta
    nombre_carpeta=$(basename "$carpeta")

    # Extraer la parte entre el primer y segundo "_"
    identificador=$(echo "$nombre_carpeta" | cut -d'_' -f2)

    # Archivo de salida individual
    archivo_salida="$DIR_SALIDA/consensos_${identificador}.fasta"

    # Inicializar el archivo individual vacío
    > "$archivo_salida"

    # Unificar los archivos .fasta dentro de la carpeta y modificar los IDs
    for fasta in "$carpeta"/*.fasta; do
      if [ -f "$fasta" ]; then
        awk -v id="$identificador" '/^>/ {print $0 "_" id} !/^>/ {print $0}' "$fasta" >> "$archivo_salida"
      fi
    done

    # Verificar si el archivo individual no está vacío
    if [ -s "$archivo_salida" ]; then
      echo "Se creó el archivo: $archivo_salida"

      # Añadir las secuencias procesadas al archivo maestro
      cat "$archivo_salida" >> "$archivo_maestro"
      se_agregaron_secuencias=true
    else
      echo "No se encontraron secuencias en la carpeta: $carpeta"
      rm "$archivo_salida"  # Eliminar archivos vacíos
    fi
  fi
done

# Verificar si se agregaron secuencias al archivo maestro
if [ "$se_agregaron_secuencias" = true ]; then
  echo "Se creó el archivo maestro con todas las secuencias: $archivo_maestro"
else
  echo "No se encontraron secuencias en ninguna carpeta. No se creó el archivo maestro."
fi
