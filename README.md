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

### codex/crear-archivos-environment.yml-para-entornos
## Entornos Conda

El repositorio incluye tres archivos de entorno en `envs/` para mantener
pequeñas dependencias por etapa.

```text
envs/clipon-prep.yml   # QC y recorte
envs/clipon-qiime.yml  # clustering con VSEARCH y clasificación
envs/clipon-ngs.yml    # pipeline con NGSpeciesID
```

Cree cada entorno con `mamba` (o `conda` si no utiliza mamba):

```bash
mamba env create -f envs/clipon-prep.yml
mamba env create -f envs/clipon-qiime.yml
mamba env create -f envs/clipon-ngs.yml
```

Active el entorno correspondiente antes de ejecutar los scripts. Por ejemplo,
para los pasos de preparación:

```bash
conda activate clipon-prep
./De0_A1_Process_Fastq.4_SeqKit.sh
```

El entorno `clipon-qiime` también se reutiliza para el módulo **Classifier**.

=======
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
Para ejecutar todas las combinaciones de parámetros de forma automática puede usarse
`De2_A4_VSearch_ejecutador_combinaciones1.1.sh`. Los valores de manifiesto, prefijo,
base de datos y correo pueden pasarse como argumentos o mediante variables de entorno:
```bash
MANIFEST_FILE=manifest.tsv PREFIX=prueba DIRDB=NCBI_DB EMAIL=me@example.com \
./De2_A4_VSearch_ejecutador_combinaciones1.1.sh
```

### Ejecución completa
```bash
./run_clipon_pipeline.sh <dir_fastq_entrada> <dir_trabajo>
```
