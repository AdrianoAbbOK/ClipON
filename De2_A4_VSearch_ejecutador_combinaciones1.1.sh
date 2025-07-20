#!/bin/bash

# Parámetros fijos
manifest_file="SingleFastaPrueba_Filt.tsv"
prefix="SingleFastaPrueba_Filt_Parana"
dirDB="NCBI_Parana_Peces"
email="adriano.abbondanzieri@gmail.com"

# Combinaciones de cluster_identity y blast_identity y maxaccepts
combinaciones=("0.98 0.5 5")

# Recorrer las combinaciones y ejecutar el script con cada par de valores
for combinacion in "${combinaciones[@]}"; do
    cluster_identity=$(echo $combinacion | cut -d ' ' -f 1)
    blast_identity=$(echo $combinacion | cut -d ' ' -f 2)
	maxaccepts=$(echo $combinacion | cut -d ' ' -f 3)

    echo "Ejecutando con cluster_identity=${cluster_identity}; blast_identity=${blast_identity} y maxaccepts=${maxaccepts}..."
    
    # Ejecutar el script con los parámetros correspondientes
    ./nuevo2.6.1.sh "$manifest_file" "$prefix" "$dirDB" "$email" "$cluster_identity" "$blast_identity" "$maxaccepts"
    
    # Verificar si hubo un error
    if [ $? -ne 0 ]; then
        echo "Error en la ejecución con cluster_identity=${cluster_identity} y blast_identity=${blast_identity}."
        exit 1
    fi
done

echo "Todos los procesos han sido completados exitosamente."
