SELECT
    DISTINCT sample AS SRA_accession
FROM read_csv('{sandpiper_data}')
WHERE sample IN ( SELECT SRA_accession FROM read_parquet('{microbial_STAT_data}') )