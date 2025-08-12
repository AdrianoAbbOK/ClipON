#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) {
  stop("Usage: plot_quality_vs_length.R <work_dir>")
}

work_dir <- args[1]
file_cleaned <- file.path(work_dir, "read_stats_cleaned.tsv")
file_filtered <- file.path(work_dir, "read_stats_650_750_Q10.tsv")
output_png <- file.path(work_dir, "read_quality_vs_length.png")

suppressPackageStartupMessages(library(ggplot2))

cleaned <- read.table(file_cleaned, header = TRUE, sep = "\t")
cleaned$dataset <- "cleaned"

filtered <- read.table(file_filtered, header = TRUE, sep = "\t")
filtered$dataset <- "filtered"

df <- rbind(cleaned, filtered)

p <- ggplot(df, aes(x = length, y = mean_quality, color = dataset)) +
  geom_point(alpha = 0.4) +
  labs(x = "Read length", y = "Mean quality score", color = "Dataset") +
  theme_minimal()

ggsave(output_png, plot = p, width = 6, height = 4)

cat(output_png, "\n")
