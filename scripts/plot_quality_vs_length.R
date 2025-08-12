#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2) {
  stop("Usage: plot_quality_vs_length.R <stats_tsv> <output_png>")
}
input_tsv <- args[1]
output_png <- args[2]

suppressPackageStartupMessages(library(ggplot2))

df <- read.table(input_tsv, header = TRUE, sep = "\t")

p <- ggplot(df, aes(x = length, y = mean_quality)) +
  geom_point(alpha = 0.4) +
  labs(x = "Read length", y = "Mean quality score") +
  theme_minimal()

ggsave(output_png, plot = p, width = 6, height = 4)
