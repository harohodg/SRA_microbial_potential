WITH intermediate_data AS
(
    SELECT 
        *
    FROM read_parquet('{data_file}') 
    WHERE {data_filter}
)
(
    SELECT 
        STAT_root_taxonomy, 
        assembly_status = 'assembled' AS assembled, 
        COUNT(*) AS num_assemblies, 
        COUNT(DISTINCT reference_accession) AS num_species, 
        COUNT( DISTINCT SRA_accession ) AS num_SRA_accessions,
    FROM intermediate_data 
    GROUP BY ALL
)
UNION ALL
(
    SELECT 
        'ANY' AS STAT_root_taxonomy, 
        assembly_status = 'assembled' AS assembled, 
        COUNT(*) AS num_assemblies, 
        COUNT(DISTINCT reference_accession) AS num_species, 
        COUNT( DISTINCT SRA_accession ) AS num_SRA_accessions 
    FROM intermediate_data 
    GROUP BY ALL
)