library(tidyverse)
library(plotly)
library(pheatmap)


# read data ---------------------------------------------------------------

targets <- read_tsv("data/targets.tsv")

df <- read_tsv("data/counts_UMI1.tsv") %>%
  mutate(sample = str_remove(sample, "_S\\d+_L\\d+_R\\d_\\d+")) %>%
  filter(
    sample != "Undetermined",  # remove undetermined samples
    locus != "unmatched"  # remove unmatched loci
  ) %>%
  left_join(targets, by = c("locus" = "id"))

# plot spike-ins ----------------------------------------------------------

df %>%
  filter(type == "spike_in") %>%
  ggplot(aes(sample, molecule_count)) +
  geom_boxplot() +
  geom_point(aes(color = locus)) +
  labs(title = "ERCC spike-ins", subtitle = "raw molecule counts", y = "molecule count") +
  theme(axis.text.x = element_text(vjust = 0.5, angle = 90))

# plot housekeeper --------------------------------------------------------

df %>%
  filter(type == "housekeeper") %>%
  ggplot(aes(sample, molecule_count)) +
  geom_boxplot() +
  geom_point(aes(color = locus)) +
  labs(title = "Housekeeping genes", subtitle = "raw molecule counts", y = "molecule count") +
  theme(axis.text.x = element_text(vjust = 0.5, angle = 90))

# normalize molecule counts -----------------------------------------------

lst <- df %>%
  select(sample, locus, molecule_count, type) %>%
  spread(sample, molecule_count) %>%
  split(.$type) %>%
  map(select, -type) %>%
  map(column_to_rownames, "locus") %>%
  map(as.matrix)

bm <- lst$biomarker
hk <- lst$housekeeper

hk_geo_means <- exp(apply(log(hk), 2, mean))
norm_counts <- sweep(bm, 2, hk_geo_means, "/")

# remove housekeeper outliers ---------------------------------------------

hk_zeros <- which(hk_geo_means == 0)
if (length(hk_zeros) > 0) {
  norm_counts <- norm_counts[, -hk_zeros]
  cat("removed sample(s) where geometric mean of housekeeping genes is zero:", names(hk_zeros), sep = "\n")
}

# plot PCA ----------------------------------------------------------------

pca_norm <- t(norm_counts) %>%
  prcomp(scale. = T)

pca_norm$x %>%
  as_tibble(rownames = "sample") %>%
  ggplot(aes(PC1, PC2, color = sample)) +
  geom_point() +
  labs(title = "Biomarkers", subtitle = "normalized molecule counts")
ggplotly()

# plot heatmap ------------------------------------------------------------

norm_counts[norm_counts == 0] <- NA  # replace 0 with NA
pheatmap(log(norm_counts), scale = "row", main = "Biomarkers", treeheight_row = 0)