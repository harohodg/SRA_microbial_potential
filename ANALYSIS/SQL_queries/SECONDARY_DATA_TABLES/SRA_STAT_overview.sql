SELECT
    '{root_taxonomy}' AS root_taxonomy,
    '{data_label}'    AS data_label,
    COUNT( DISTINCT STAT_tax_id )        AS num_species,
    COUNT( DISTINCT STAT_SRA_accession ) AS num_datasets
FROM read_parquet('{search_table}')
WHERE {data_filter}