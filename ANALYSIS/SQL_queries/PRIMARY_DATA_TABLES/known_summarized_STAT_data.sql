SELECT
    IFNULL(parent_tax_id, tax_id) AS tax_id,
    accession AS SRA_accession,
    SUM(total_count) AS num_reads,
    COUNT(*) AS num_predictions,
    
    CASE
        WHEN parent_tax_id IS NOT NULL THEN 'species'
        ELSE taxonomy_info.rank
    END AS rank,
    
    root_taxonomy
FROM 
    STAT_data 
    JOIN
    read_parquet('{data_folder}/species_root_taxonomies.parquet') AS taxonomy_info
    USING (tax_id)
WHERE 
    STAT_data.rank = 'species'
    AND
    root_taxonomy = '{target_taxonomy}'
GROUP BY ALL