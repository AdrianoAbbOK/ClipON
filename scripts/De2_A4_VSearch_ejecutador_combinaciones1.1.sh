#!/bin/bash
set -e
set -u

# Parámetros pasados por variables de entorno o argumentos
manifest_file="${MANIFEST_FILE:-${1-}}"
prefix="${PREFIX:-${2-}}"
dirDB="${DIRDB:-${3-}}"
email="${EMAIL:-${4-}}"

# Mostrar mensaje de uso si faltan argumentos
if [[ -z "$manifest_file" || -z "$prefix" || -z "$dirDB" || -z "$email" ]]; then
    echo "Uso: $0 <manifest_file> <prefijo> <dirDB> <email>" >&2
    echo "O defina las variables de entorno MANIFEST_FILE, PREFIX, DIRDB y EMAIL" >&2
    exit 1
fi

# Combinaciones de cluster_identity y blast_identity y maxaccepts
combinaciones=("0.98 0.5 5")

# Recorrer las combinaciones y ejecutar el script con cada par de valores
script_dir="$(dirname "$0")"

for combinacion in "${combinaciones[@]}"; do
    cluster_identity=$(echo $combinacion | cut -d ' ' -f 1)
    blast_identity=$(echo $combinacion | cut -d ' ' -f 2)
	maxaccepts=$(echo $combinacion | cut -d ' ' -f 3)

    echo "Ejecutando con cluster_identity=${cluster_identity}; blast_identity=${blast_identity} y maxaccepts=${maxaccepts}..."
    
    # Ejecutar el script con los parámetros correspondientes
    "$script_dir/De2_A4__VSearch_Procesonuevo2.6.1.sh" "$manifest_file" "$prefix" "$dirDB" "$email" "$cluster_identity" "$blast_identity" "$maxaccepts"
    
    # Verificar si hubo un error
    if [ $? -ne 0 ]; then
        echo "Error en la ejecución con cluster_identity=${cluster_identity} y blast_identity=${blast_identity}."
        exit 1
    fi
done

echo "Todos los procesos han sido completados exitosamente."
