# Code for summarizing [SRA cloud tables](https://www.ncbi.nlm.nih.gov/sra/docs/sra-cloud-based-examples/) and [summary of GenBank/RefSeq](https://www.ncbi.nlm.nih.gov/datasets/)
A lot of exploratory tables/plots. A very small subset ended up in the publication.

## conda environment
`conda env create -f environment.yaml`

The order in which tables are generated is important as some tables are based on preceeding ones.
## Export primary data tables
`\time -v ./export_primary_data_tables.sh ../EXTRACTED_DATA/2025_01_15-updated/2025_01_15_data-extracted-updated.db PRIMARY_DATA_TABLES`

## Summarize all of the attempted assemblies
This will take awhile. Go enjoy a nice coffee or alternative beverage of choice. Perhaps catch up on some reading.
`\time -v ./summarize_assembly_results.sh ../EXTRACTED_DATA/2025_01_15-updated/2025_01_15_data-extracted-updated.db PRIMARY_DATA_TABLES ASSEMBLY_RESULTS`

Note : Assembly success/failure labels are based on the intermediate files returned by each step of the pipeline. The pipeline summary cannot tell the difference between no mapped reads due to a download failure or when no reads mapped to the reference. Both cases are labeled as a failure due to  `no mapped reads`. Users should check the Nextflow log files to verify all steps exited with code 0.

## And now make some figures
`conda run -n NCBI_coverage_analysis --live-stream python3 create_plots.py`


## Export secondary data tables
More coffee?
`\time -v ./export_secondary_data_tables.sh ../EXTRACTED_DATA/2025_01_15-updated/2025_01_15_data-extracted-updated.db PRIMARY_DATA_TABLES ASSEMBLY_RESULTS SECONDARY_DATA_TABLES`
