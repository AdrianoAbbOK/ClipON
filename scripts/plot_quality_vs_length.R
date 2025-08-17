#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) {
  stop("Usage: plot_quality_vs_length.R <work_dir>")
}

work_dir <- args[1]
file_cleaned <- file.path(work_dir, "read_stats_cleaned.tsv")
file_filtered <- file.path(work_dir, "read_stats_650_750_Q10.tsv")
output_png <- normalizePath(file.path(work_dir, "read_quality_vs_length.png"),
                             mustWork = FALSE)

suppressPackageStartupMessages({
  library(ggplot2)
  library(readr)
})

cleaned <- readr::read_tsv(file_cleaned, show_col_types = FALSE)
filtered <- readr::read_tsv(file_filtered, show_col_types = FALSE)

p <- ggplot() +
  geom_point(
    data = cleaned,
    aes(x = length, y = mean_quality, color = "raw"),
    alpha = 0.4
  ) +
  geom_point(
    data = filtered,
    aes(x = length, y = mean_quality, color = "filtered"),
    alpha = 0.4
  ) +
  labs(x = "Read length", y = "Mean quality score") +
  scale_color_manual(
    values = c(raw = "#1f77b4", filtered = "#ff7f0e"),
    name = "Dataset"
  ) +
  theme_minimal()

ggsave(output_png, plot = p, width = 6, height = 4, units = "in")

message("Plot saved to: ", output_png)
cat(output_png, "\n")
