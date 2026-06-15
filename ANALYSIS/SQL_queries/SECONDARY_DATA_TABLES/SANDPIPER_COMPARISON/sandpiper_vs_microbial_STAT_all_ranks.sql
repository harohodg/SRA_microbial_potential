SELECT 
    'all ranks|raw_data' AS data_label,
    'Sandpiper' AS data_source,
    COUNT( DISTINCT sample ) AS num_SRA_accessions,
    COUNT( * ) AS num_predictions,
    COUNT( DISTINCT taxonomy ) AS num_taxonomy
FROM read_csv('{sandpiper_data}')

UNION ALL

SELECT 
    'all ranks|raw_data'  AS data_label,
    'microbial STAT' AS data_source,
    COUNT( DISTINCT SRA_accession ) AS num_SRA_accessions,
    COUNT( * ) AS num_predictions,
    COUNT( DISTINCT tax_id ) AS num_taxonomy
FROM read_parquet('{microbial_STAT_data}')

UNION ALL

SELECT 
    'all ranks|overlap' AS data_label,
    'Sandpiper' AS data_source,
    COUNT( DISTINCT sample ) AS num_SRA_accessions,
    COUNT( * ) AS num_predictions,
    COUNT( DISTINCT taxonomy ) AS num_taxonomy
FROM read_csv('{sandpiper_data}')
WHERE sample IN ( SELECT SRA_accession FROM read_parquet('{overlapping_accessions}') )

UNION ALL

SELECT 
    'all ranks|overlap'  AS data_label,
    'microbial STAT' AS data_source,
    COUNT( DISTINCT SRA_accession ) AS num_SRA_accessions,
    COUNT( * ) AS num_predictions,
    COUNT( DISTINCT tax_id ) AS num_taxonomy
FROM read_parquet('{microbial_STAT_data}')
WHERE SRA_accession IN ( SELECT SRA_accession FROM read_parquet('{overlapping_accessions}') )