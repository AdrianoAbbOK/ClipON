# Metadata de FASTQ

El archivo de metadata permite asignar cada archivo FASTQ a un nombre de experimento.
Debe ser un TSV con columnas **fastq** y **experiment**:

fastq	experiment
sample1.fastq	Exp1
sample2.fastq	Exp2

Los nombres en la columna `fastq` pueden incluir rutas; solo se utiliza el nombre
base del archivo. Proporcione la ruta del archivo con `--metadata` al ejecutar los
scripts para que las muestras se renombren con el experimento correspondiente.
