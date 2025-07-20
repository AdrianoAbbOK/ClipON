# Example Importing Manifest

The `ImportingManifest_Manual.csv` file is used by QIIME2 for importing FASTQ files. It must contain the following columns:

1. `sample-id` – unique name for the sample
2. `absolute-filepath` – path to the FASTQ file for that sample
3. `direction` – sequencing direction, usually `forward`

Example:
```csv
sample-id,absolute-filepath,direction
example1,/path/to/cleaned_sample1.fastq,forward
example2,/path/to/cleaned_sample2.fastq,forward
```

Paths may be absolute or relative. Update them to point to your cleaned FASTQ files before running the pipeline.
