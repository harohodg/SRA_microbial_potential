SELECT 
    tax_id,
    parent_id AS parent_tax_id,
    rank, 
    sci_name
FROM read_parquet('PARQUET_FILE')
ORDER BY tax_id ASC
