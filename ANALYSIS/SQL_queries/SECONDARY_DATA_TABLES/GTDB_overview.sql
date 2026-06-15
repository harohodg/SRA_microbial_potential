SELECT
    gtdb_root_taxonomy,
    COUNT(*) AS num_species,
    SUM( LENGTH(base_genbank_accessions) ) AS num_genomes,
    COUNT( CASE WHEN LENGTH(base_genbank_accessions) = 1 THEN 1 END ) AS num_singletons,
    100*(num_singletons/num_species)::DECIMAL(5,4) AS percent_singletons
FROM read_parquet('{data_table}')
GROUP BY ALL

UNION ALL

SELECT
    'either' AS gtdb_root_taxonomy,
    COUNT(*) AS num_species,
    SUM( LENGTH(base_genbank_accessions) ) AS num_genomes,
    COUNT( CASE WHEN LENGTH(base_genbank_accessions) = 1 THEN 1 END ) AS num_singletons,
    100*(num_singletons/num_species)::DECIMAL(5,4) AS percent_singletons
FROM read_parquet('{data_table}')