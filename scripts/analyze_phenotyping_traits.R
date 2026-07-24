# Plant Phenotyping Data Workflow in R
# Author: Mokkala Siva Prasad
# Purpose: Demonstration workflow for crop phenotyping trait data
#
# The sample dataset is synthetic and is intended for portfolio demonstration.
# The workflow uses base R only.

options(stringsAsFactors = FALSE)

data_path <- file.path("data", "phenotyping_trait_sample.csv")
output_dir <- "outputs"

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

raw_data <- read.csv(data_path, na.strings = c("", "NA"))

required_columns <- c(
  "genotype",
  "replication",
  "plant_height_cm",
  "canopy_width_cm",
  "leaf_area_index",
  "spad_chlorophyll",
  "ndvi_proxy",
  "days_to_maturity",
  "marketable_yield_t_ha",
  "disease_score_1_9",
  "vigor_score_1_9"
)

missing_columns <- setdiff(required_columns, names(raw_data))
if (length(missing_columns) > 0) {
  stop("Missing required columns: ", paste(missing_columns, collapse = ", "))
}

trait_columns <- setdiff(required_columns, c("genotype", "replication"))

missing_before <- colSums(is.na(raw_data[, trait_columns]))

cleaned_data <- raw_data

for (trait in trait_columns) {
  trait_median <- median(cleaned_data[[trait]], na.rm = TRUE)
  cleaned_data[[trait]][is.na(cleaned_data[[trait]])] <- trait_median
}

missing_after <- colSums(is.na(cleaned_data[, trait_columns]))

write.csv(
  cleaned_data,
  file.path(output_dir, "cleaned_phenotyping_data.csv"),
  row.names = FALSE
)

data_quality_report <- c(
  "# Data quality report",
  "",
  "The dataset used here is synthetic and intended only for demonstration.",
  "",
  "## Missing values before median imputation",
  "",
  "| Trait | Missing values |",
  "|---|---:|",
  sprintf("| %s | %d |", names(missing_before), as.integer(missing_before)),
  "",
  "## Missing values after median imputation",
  "",
  "| Trait | Missing values |",
  "|---|---:|",
  sprintf("| %s | %d |", names(missing_after), as.integer(missing_after))
)

writeLines(data_quality_report, file.path(output_dir, "data_quality_report.md"))

genotype_means <- aggregate(
  cleaned_data[, trait_columns],
  by = list(genotype = cleaned_data$genotype),
  FUN = mean
)

numeric_cols <- vapply(genotype_means, is.numeric, logical(1))
genotype_means[numeric_cols] <- lapply(genotype_means[numeric_cols], round, digits = 3)

write.csv(
  genotype_means,
  file.path(output_dir, "genotype_means.csv"),
  row.names = FALSE
)

trait_matrix <- genotype_means[, trait_columns]
row.names(trait_matrix) <- genotype_means$genotype

correlation_matrix <- round(cor(trait_matrix, use = "pairwise.complete.obs"), 3)

write.csv(
  correlation_matrix,
  file.path(output_dir, "correlation_matrix.csv")
)

scaled_traits <- scale(trait_matrix)
pca_model <- prcomp(scaled_traits, center = TRUE, scale. = TRUE)

pca_scores <- data.frame(
  genotype = row.names(pca_model$x),
  round(pca_model$x[, 1:3], 3)
)

pca_loadings <- data.frame(
  trait = row.names(pca_model$rotation),
  round(pca_model$rotation[, 1:3], 3)
)

pca_variance <- data.frame(
  component = paste0("PC", seq_along(pca_model$sdev)),
  variance_explained_percent = round((pca_model$sdev^2 / sum(pca_model$sdev^2)) * 100, 2)
)

write.csv(pca_scores, file.path(output_dir, "pca_scores.csv"), row.names = FALSE)
write.csv(pca_loadings, file.path(output_dir, "pca_loadings.csv"), row.names = FALSE)
write.csv(pca_variance, file.path(output_dir, "pca_variance_explained.csv"), row.names = FALSE)

distance_matrix <- dist(scaled_traits)
cluster_model <- hclust(distance_matrix, method = "ward.D2")
cluster_id <- cutree(cluster_model, k = 3)

z_score <- function(x) as.numeric(scale(x))

phenotype_index <-
  0.25 * z_score(trait_matrix$marketable_yield_t_ha) +
  0.15 * z_score(trait_matrix$spad_chlorophyll) +
  0.15 * z_score(trait_matrix$ndvi_proxy) +
  0.15 * z_score(trait_matrix$vigor_score_1_9) +
  0.10 * z_score(trait_matrix$leaf_area_index) -
  0.10 * z_score(trait_matrix$days_to_maturity) -
  0.10 * z_score(trait_matrix$disease_score_1_9)

ranked_phenotypes <- data.frame(
  genotype = row.names(trait_matrix),
  phenotype_cluster = cluster_id,
  phenotype_index = round(phenotype_index, 3),
  genotype_means[, trait_columns]
)

ranked_phenotypes <- ranked_phenotypes[
  order(ranked_phenotypes$phenotype_index, decreasing = TRUE),
]

cluster_mean_index <- aggregate(
  phenotype_index ~ phenotype_cluster,
  data = ranked_phenotypes,
  FUN = mean
)

cluster_mean_index <- cluster_mean_index[
  order(cluster_mean_index$phenotype_index, decreasing = TRUE),
]

cluster_labels <- setNames(
  c(
    "high-performing phenotype group",
    "intermediate phenotype group",
    "lower-priority phenotype group"
  ),
  cluster_mean_index$phenotype_cluster
)

ranked_phenotypes$phenotype_group <- unname(cluster_labels[as.character(ranked_phenotypes$phenotype_cluster)])

write.csv(
  ranked_phenotypes,
  file.path(output_dir, "ranked_phenotypes.csv"),
  row.names = FALSE
)

cluster_summary <- aggregate(
  ranked_phenotypes[, trait_columns],
  by = list(phenotype_group = ranked_phenotypes$phenotype_group),
  FUN = mean
)

cluster_summary[names(cluster_summary) != "phenotype_group"] <-
  lapply(cluster_summary[names(cluster_summary) != "phenotype_group"], round, digits = 3)

write.csv(
  cluster_summary,
  file.path(output_dir, "genotype_cluster_summary.csv"),
  row.names = FALSE
)

top_six <- head(ranked_phenotypes, 6)

phenotype_report <- c(
  "# Phenotype grouping report",
  "",
  "This report is generated from a synthetic dataset and is intended only to demonstrate analysis workflow.",
  "",
  "## PCA variance explained",
  "",
  "| Component | Variance explained (%) |",
  "|---|---:|",
  sprintf("| %s | %.2f |", pca_variance$component[1:5], pca_variance$variance_explained_percent[1:5]),
  "",
  "## Top genotypes by demonstration phenotype index",
  "",
  "| Rank | Genotype | Group | Phenotype index | Yield (t/ha) | NDVI proxy | Disease score |",
  "|---:|---|---|---:|---:|---:|---:|",
  sprintf(
    "| %d | %s | %s | %.3f | %.2f | %.3f | %.2f |",
    seq_len(nrow(top_six)),
    top_six$genotype,
    top_six$phenotype_group,
    top_six$phenotype_index,
    top_six$marketable_yield_t_ha,
    top_six$ndvi_proxy,
    top_six$disease_score_1_9
  ),
  "",
  "## Interpretation",
  "",
  "The index favors higher marketable yield, chlorophyll index, NDVI proxy, vigor, and leaf area index, while penalizing later maturity and higher disease score.",
  "",
  "The ranking should be interpreted as a transparent demonstration of trait-based genotype prioritization, not as a real cultivar recommendation."
)

writeLines(phenotype_report, file.path(output_dir, "phenotype_grouping_report.md"))

svg(file.path(output_dir, "correlation_heatmap.svg"), width = 8, height = 7)
par(mar = c(8, 8, 4, 2))
image(
  1:ncol(correlation_matrix),
  1:nrow(correlation_matrix),
  t(correlation_matrix[nrow(correlation_matrix):1, ]),
  axes = FALSE,
  col = colorRampPalette(c("#2166ac", "white", "#b2182b"))(100),
  main = "Trait Correlation Heatmap"
)
axis(1, at = 1:ncol(correlation_matrix), labels = colnames(correlation_matrix), las = 2, cex.axis = 0.75)
axis(2, at = 1:nrow(correlation_matrix), labels = rev(rownames(correlation_matrix)), las = 2, cex.axis = 0.75)
dev.off()

svg(file.path(output_dir, "pca_biplot.svg"), width = 8, height = 6)
cluster_colors <- as.factor(ranked_phenotypes$phenotype_cluster[match(row.names(trait_matrix), ranked_phenotypes$genotype)])
plot(
  pca_model$x[, 1],
  pca_model$x[, 2],
  pch = 19,
  col = as.integer(cluster_colors),
  xlab = paste0("PC1 (", pca_variance$variance_explained_percent[1], "%)"),
  ylab = paste0("PC2 (", pca_variance$variance_explained_percent[2], "%)"),
  main = "PCA of Phenotyping Traits"
)
text(pca_model$x[, 1], pca_model$x[, 2], labels = row.names(trait_matrix), pos = 3, cex = 0.65)
legend("topright", legend = levels(cluster_colors), col = seq_along(levels(cluster_colors)), pch = 19, title = "Cluster")
dev.off()

svg(file.path(output_dir, "dendrogram.svg"), width = 9, height = 6)
plot(cluster_model, main = "Hierarchical Clustering of Genotypes", xlab = "", sub = "")
rect.hclust(cluster_model, k = 3, border = 2:4)
dev.off()

svg(file.path(output_dir, "phenotype_group_profile.svg"), width = 9, height = 6)
profile_traits <- c("marketable_yield_t_ha", "spad_chlorophyll", "ndvi_proxy", "vigor_score_1_9", "disease_score_1_9")
profile_matrix <- as.matrix(cluster_summary[, profile_traits])
row.names(profile_matrix) <- cluster_summary$phenotype_group
scaled_profile <- t(scale(t(profile_matrix)))
barplot(
  t(scaled_profile),
  beside = TRUE,
  col = c("#1b9e77", "#7570b3", "#d95f02", "#66a61e", "#e7298a"),
  las = 2,
  main = "Relative Trait Profile by Phenotype Group",
  ylab = "Within-group standardized trait value"
)
legend("topright", legend = profile_traits, fill = c("#1b9e77", "#7570b3", "#d95f02", "#66a61e", "#e7298a"), cex = 0.7)
dev.off()

cat("Phenotyping workflow complete.\n")
cat("Top genotypes by phenotype index:\n")
print(top_six[, c("genotype", "phenotype_group", "phenotype_index", "marketable_yield_t_ha")])
