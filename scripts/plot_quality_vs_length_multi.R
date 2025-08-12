#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  stop("Usage: plot_quality_vs_length_multi.R <output_png> <tsv1> <tsv2> [<tsv3> ...]")
}

output_png <- normalizePath(args[1], mustWork = FALSE)
input_files <- args[-1]

suppressPackageStartupMessages({
  library(ggplot2)
  library(readr)
})

# Read each TSV and add a group column based on filename
get_group <- function(path) {
  fname <- basename(path)
  m <- regmatches(fname, regexpr("(processed|filtered)_stats\\.tsv$", fname))
  if (length(m) == 1) {
    sub("_stats.tsv", "", m)
  } else {
    tools::file_path_sans_ext(fname)
  }
}

data_list <- lapply(input_files, function(f) {
  df <- readr::read_tsv(f, show_col_types = FALSE)
  df$group <- get_group(f)
  df
})

df <- do.call(rbind, data_list)

p <- ggplot(df, aes(x = length, y = mean_quality, color = group, shape = group)) +
  geom_point(alpha = 0.4) +
  labs(x = "Read length", y = "Mean quality score", color = "Group", shape = "Group") +
  theme_minimal()

ggsave(output_png, plot = p, width = 6, height = 4, units = "in")

message("Plot saved to: ", output_png)
cat(output_png, "\n")
