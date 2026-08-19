WITH input_data AS
(
    SELECT
        *
    FROM {data_table}
), intermediate_data AS 
(
    SELECT 
        *,
        root_taxonomy AS data_label,
        ROW_NUMBER() OVER ( PARTITION BY data_label ORDER BY num_SRA_accessions DESC ) AS adjusted_rn 
    FROM input_data

    UNION ALL

    SELECT 
        *,
        root_taxonomy || ' GenBank : ' || genbank_genomes_label AS data_label,
        ROW_NUMBER() OVER ( PARTITION BY data_label ORDER BY num_SRA_accessions DESC ) AS adjusted_rn 
    FROM input_data   

    UNION ALL

    SELECT 
        *,
        root_taxonomy || ' GTDB : ' || gtdb_genomes_label AS data_label,
        ROW_NUMBER() OVER ( PARTITION BY data_label ORDER BY num_SRA_accessions DESC ) AS adjusted_rn 
    FROM input_data  

    UNION ALL

    SELECT 
        *,
        root_taxonomy ||' GenBank|GTDB : ' || genbank_genomes_label || '|' || gtdb_genomes_label AS data_label,
        ROW_NUMBER() OVER ( PARTITION BY data_label ORDER BY num_SRA_accessions DESC ) AS adjusted_rn 
    FROM input_data  
)
SELECT 
    *
FROM intermediate_data
WHERE adjusted_rn <= {TOP_N}
