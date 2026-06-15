SELECT
    COUNT( DISTINCT STAT_SRA_accession ) AS num_STAT_datasets,
    COUNT( DISTINCT( CASE WHEN meta_data_what_was_sequenced LIKE '%metagenome%' THEN STAT_SRA_accession END ) ) AS num_STAT_metagenomic_datasets,
    COUNT( DISTINCT STAT_species_tax_id ) AS num_species_in_all_STAT_datasets,
    COUNT( DISTINCT( CASE WHEN meta_data_what_was_sequenced LIKE '%metagenome%' THEN STAT_species_tax_id END ) ) AS num_species_in_STAT_metagenomic_datasets,
FROM read_parquet('{search_table}')
