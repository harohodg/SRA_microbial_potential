SELECT 
    acc AS accession, 
    tax_id, 
    rank,
    total_count,
    self_count,
FROM read_parquet('PARQUET_FILE')
WHERE rank = 'species'
ORDER BY tax_id ASC
