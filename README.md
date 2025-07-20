# ClipON

“ClipON: pipeline reproducible para metabarcoding de eDNA (marcador COI) con lecturas Nanopore – limpieza, clustering, clasificación.”
## Descripción general del pipeline

1. **Procesamiento inicial** – se filtran secuencias corruptas con `SeqKit`.
2. **Recorte de cebadores** – `Cutadapt` elimina bases al inicio y fin.
3. **Filtrado de calidad y longitud** – `NanoFilt` descarta lecturas cortas o de baja calidad.
4. **Clustering** – `NGSpeciesID` agrupa secuencias y genera consensos.
5. **Unificación de clusters** – se combinan los consensos de distintos experimentos.
6. **Clasificación opcional** – el script de VSearch/QIIME2 permite asignar taxonomía.


## Uso rápido

Ejecuta todo el flujo con:

```bash
./run_clipon_pipeline.sh <dir_fastq_entrada> <dir_trabajo>
```

Esto creará subdirectorios dentro de `<dir_trabajo>` para cada etapa.
Las rutas de entrada y salida también pueden configurarse manualmente al invocar cada script por separado.
## Requisitos

- SeqKit
- Cutadapt
- NanoFilt
- QIIME2

## Ejemplos de ejecución

### Procesamiento con SeqKit
```bash
./De0_A1_Process_Fastq.4_SeqKit.sh <dir_entrada> <dir_salida>
```

### Recorte con Cutadapt
```bash
./De1_A1.5_Trim_Fastq.sh <dir_entrada> <dir_salida>
```

### Filtrado con NanoFilt
```bash
./De1.5_A2_Filtrado_NanoFilt_1.1.sh <dir_entrada> <dir_salida> <log_file>
```

### Clustering con NGSpeciesID
```bash
./De2_A2.5_NGSpecies_Clustering.sh <dir_entrada> <dir_salida>
```

### Unificación de clusters
```bash
./De2.5_A3_NGSpecies_Unificar_Clusters.sh <dir_base> <dir_salida>
```

### Clasificación con QIIME2
```bash
./De2_A4__VSearch_Procesonuevo2.6.1.sh <manifest.tsv> <prefijo> <dirDB> <email> <cluster_identity> <blast_identity> <maxaccepts>
```

### Ejecución completa
```bash
./run_clipon_pipeline.sh <dir_fastq_entrada> <dir_trabajo>
```
