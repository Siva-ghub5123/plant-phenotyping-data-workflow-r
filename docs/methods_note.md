# Methods note

This repository demonstrates a transparent phenotyping-data workflow using synthetic data.

## Data status

The dataset is synthetic and is not unpublished thesis data, institutional data, or confidential field data. It is included only to demonstrate reproducible analysis structure.

## Data cleaning

The script checks required columns and identifies missing numeric trait values. Missing values are imputed using trait medians. This is a simple demonstration choice. For real research data, the missing-data strategy should depend on the source of missingness, field notes, plot loss, instrument failure, and the final statistical model.

## Trait correlation

Trait correlations are estimated at the genotype-mean level using Pearson correlation. This helps identify relationships among yield, vigor, chlorophyll index, NDVI proxy, maturity, disease score, and canopy traits.

## PCA

Principal component analysis is run on scaled genotype means. PCA is used here as an exploratory tool to understand the main axes of trait variation. It should not be interpreted as a replacement for biological validation or formal breeding decisions.

## Clustering

Genotypes are clustered using hierarchical clustering with Ward's method on scaled trait means. The workflow cuts the dendrogram into three phenotype groups for demonstration.

## Phenotype index

The phenotype index favors:

- higher marketable yield
- higher chlorophyll index
- higher NDVI proxy
- higher plant vigor
- higher leaf area index

It penalizes:

- later maturity
- higher disease score

The weights are illustrative and should be revised for real breeding objectives, target environments, market class, and stakeholder priorities.

## Interpretation limits

This workflow is intended to show data organization, exploratory phenotyping analysis, and reproducible reporting. It is not a cultivar recommendation and does not claim image-based, UAV-based, or omics-based analysis.

Possible future extensions include:

- multi-environment phenotyping
- mixed-model genotype prediction
- spatial field adjustment
- image-derived canopy traits
- integration with genomic or metabolomic datasets
