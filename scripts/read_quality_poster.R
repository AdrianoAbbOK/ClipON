#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(ggplot2)
  library(RColorBrewer)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) {
  stop("Uso: read_quality_poster.R <tsv_paths_coma_separadas> <output_png>")
}

# Argumento 1: rutas separadas por comas a los TSV generados por collect_read_stats.py
tsve <- strsplit(args[1], ",")[[1]]
output_png <- args[2]

if (length(tsve) == 0) {
  stop("No se proporcionaron archivos TSV")
}

# Leer y combinar datos, añadiendo una columna con el nombre de la etapa
data_list <- lapply(tsve, function(p) {
  df <- read.table(p, header = TRUE, sep = "\t", stringsAsFactors = FALSE)
  df$mean_quality <- as.numeric(df$mean_quality)
  fname <- basename(p)
  if (grepl("_filtered", fname)) {
    df$dataset <- "filtered"
  } else {
    df$dataset <- "pre_filter"
  }
  df
})

df_all <- do.call(rbind, data_list)

# Límites fijos para hacer comparables los gráficos
max_length <- 2000
max_quality <- 45

p <- ggplot(df_all, aes(x = length, y = mean_quality, color = dataset)) +
  geom_point(alpha = 0.5, size = 0.7) +
  scale_color_manual(
    values = c(pre_filter = "#1f77b4", filtered = "#ff7f0e"),
    labels = c(pre_filter = "Pre-filter", filtered = "Filtered")
  ) +
  coord_cartesian(xlim = c(0, max_length), ylim = c(0, max_quality)) +
  labs(x = "Longitud de lectura", y = "Calidad media", color = "Conjunto") +
  theme_minimal()

# Guardar gráfico
ggsave(output_png, plot = p, width = 8, height = 5, dpi = 300)
