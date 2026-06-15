SELECT
    tax_id,
    accession AS SRA_accession,
    SUM(total_count) AS num_reads,
    COUNT(*) AS num_predictions,
    NULL AS rank,
    'UNKNOWN' AS root_taxonomy
FROM 
    STAT_data 
WHERE 
    STAT_data.rank = 'species'
    AND
    tax_id NOT IN ( SELECT tax_id FROM TAXONOMY_data )
GROUP BY ALL