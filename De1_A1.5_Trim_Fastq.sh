#!/bin/bash

#Abrir en carpeta de archivos parseados

#HacerDirectorio
mkdir trimmed_fastq

#Trimmear y guardar
for file in *.fastq; do
    cutadapt -u 30 -u -30 -o trimmed_fastq/${file%.fastq}_trimmed.fastq $file
done