#!/usr/bin/env Rscript

# Genera un gráfico de barras apiladas por taxón para cada muestra
# Uso: Rscript scripts/plot_taxon_bar.R <archivo_taxonomia.tsv> <salida.png>

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) {
  stop("Se requieren los parámetros: <archivo_taxonomia.tsv> <salida.png>")
}

input_file <- args[1]
output_file <- args[2]

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(ggplot2)
})

# Leer el archivo de taxonomía
# Se espera que contenga al menos las columnas: Sample, Taxon y Reads
data <- read_tsv(input_file, show_col_types = FALSE)

plot_data <- data %>%
  select(Sample, Taxon, Reads) %>%
  group_by(Sample, Taxon) %>%
  summarise(Reads = sum(Reads), .groups = "drop") %>%
  group_by(Sample) %>%
  mutate(Percent = Reads / sum(Reads))

p <- ggplot(plot_data, aes(x = Sample, y = Percent, fill = Taxon)) +
  geom_col() +
  ylab("Proporción de lecturas") +
  xlab("Muestra") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(output_file, p, width = 8, height = 5, dpi = 300)

# Imprimir la ruta absoluta del archivo generado
output_path <- normalizePath(output_file)
cat(output_path, "\n")
