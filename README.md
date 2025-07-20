# ClipON

“ClipON: pipeline reproducible para metabarcoding de eDNA (marcador COI) con lecturas Nanopore – limpieza, clustering, clasificación.”

## Uso rápido

Ejecuta todo el flujo con:

```bash
./run_clipon_pipeline.sh <dir_fastq_entrada> <dir_trabajo>
```

Esto creará subdirectorios dentro de `<dir_trabajo>` para cada etapa.
Las rutas de entrada y salida también pueden configurarse manualmente al invocar cada script por separado.

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

