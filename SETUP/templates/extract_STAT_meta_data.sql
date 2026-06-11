SELECT
    acc AS accession,
    analyzed_spot_count,
    total_spot_count
FROM read_parquet('PARQUET_FILE')
ORDER BY accession ASC
