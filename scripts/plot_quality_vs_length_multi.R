#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: plot_quality_vs_length_multi.R <output_png> [--metadata <file>] <tsv1> <tsv2> ...")
}

output_png <- normalizePath(args[1], mustWork = FALSE)
args <- args[-1]

if (length(args) >= 2 && args[1] == "--metadata") {
  # Metadata argument kept for backward compatibility; sample origin is ignored
  args <- args[-c(1, 2)]
}

input_files <- args

suppressPackageStartupMessages({
  library(ggplot2)
  library(readr)
})

parse_dataset <- function(path) {
  fname <- basename(path)
  if (grepl("_filtered_stats\\.tsv$", fname)) {
    "filtered"
  } else {
    "pre_filter"
  }
}

data_list <- lapply(input_files, function(f) {
  df <- readr::read_tsv(f, show_col_types = FALSE)
  df$dataset <- parse_dataset(f)
  df
})

df <- do.call(rbind, data_list)

p <- ggplot(df, aes(x = length, y = mean_quality, color = dataset)) +
  geom_point(size = 0.05, alpha = 1) +
  labs(x = "Read length", y = "Mean quality score", color = "Dataset") +
  scale_color_manual(
    values = c(pre_filter = "#1f77b4", filtered = "#ff7f0e"),
    labels = c(pre_filter = "Pre-filter", filtered = "Filtered")
  ) +
  theme_minimal()

ggsave(output_png, plot = p, width = 6, height = 4, units = "in")

message("Plot saved to: ", output_png)
cat(output_png, "\n")

