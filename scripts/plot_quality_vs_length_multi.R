#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  stop(
    "Usage: plot_quality_vs_length_multi.R <output_png> [--metadata <file>] <tsv1> <tsv2> ..."
  )
}

output_png <- normalizePath(args[1], mustWork = FALSE)
args <- args[-1]

metadata <- NULL
if (length(args) >= 2 && args[1] == "--metadata") {
  metadata <- readr::read_tsv(args[2], show_col_types = FALSE)
  args <- args[-c(1, 2)]
}

map_sample <- NULL
if (!is.null(metadata)) {
  fastq_names <- tools::file_path_sans_ext(basename(metadata$fastq))
  map_sample <- setNames(metadata$experiment, fastq_names)
}

input_files <- args

suppressPackageStartupMessages({
  library(ggplot2)
  library(readr)
})

# Extract sample and dataset information from the filename
parse_file_info <- function(path) {
  fname <- basename(path)
  dataset <- sub("^.*_(raw|processed|filtered)_stats\\.tsv$", "\\1", fname)
  sample <- sub("_(raw|processed|filtered)_stats\\.tsv$", "", fname)
  sample <- sub("^cleaned_", "", sample)
  sample <- sub("_trimmed$", "", sample)
  if (!is.null(map_sample) && sample %in% names(map_sample)) {
    sample <- map_sample[[sample]]
  }
  list(sample = sample, dataset = dataset)
}

# Read each TSV and add sample and dataset columns based on filename
data_list <- lapply(input_files, function(f) {
  df <- readr::read_tsv(f, show_col_types = FALSE)
  info <- parse_file_info(f)
  df$sample <- info$sample
  df$dataset <- info$dataset
  df
})

df <- do.call(rbind, data_list)

p <- ggplot(df, aes(x = length, y = mean_quality, color = sample, shape = dataset)) +
  geom_point(size = 0.05, alpha = 1) +
  labs(x = "Read length", y = "Mean quality score", color = "Sample", shape = "Dataset") +
  theme_minimal()

ggsave(output_png, plot = p, width = 6, height = 4, units = "in")

message("Plot saved to: ", output_png)
cat(output_png, "\n")
