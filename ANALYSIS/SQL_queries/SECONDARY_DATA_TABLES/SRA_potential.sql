SELECT 
    {columns_to_group},
    
    COUNT( DISTINCT STAT_tax_id )  AS num_species,
    COUNT( DISTINCT STAT_SRA_accession )  AS num_datasets,
    COUNT(*)                            AS num_assemblies,
    
    MIN( {coverage_equation} )        AS min_estimated_genome_coverage,
    MAX( {coverage_equation} )        AS max_estimated_genome_coverage,
    MEAN( {coverage_equation} )       AS mean_estimated_genome_coverage,
    STDDEV( {coverage_equation} )     AS estimated_genome_coverage_std
FROM read_parquet('{data_table}') AS data_table
WHERE {data_filter}
GROUP BY ALL