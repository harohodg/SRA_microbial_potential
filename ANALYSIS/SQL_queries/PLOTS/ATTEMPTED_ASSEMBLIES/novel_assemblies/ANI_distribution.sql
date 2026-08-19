SELECT
    CASE 
        WHEN assembly_data_label = 'RANDOM_SINGLETONS' THEN 'Random'
        WHEN assembly_data_label = 'TOP_N_SINGLETONS' THEN '1000X'
    END AS assembly_data_label,
    global_ANI
FROM read_parquet('{data_table}')
WHERE 
    assembly_quality = '{target_quality}' AND ({successful_assembly})
    AND ({novel_assembly})
    AND  assembly_data_label != 'TARANTELLAE_ANALYSIS' 

UNION ALL

SELECT
    'Is the sequencing project' AS assembly_data_label,
    global_ANI
FROM read_parquet('{data_table}')
WHERE 
    assembly_quality = '{target_quality}' AND ({successful_assembly})
    AND data_source = 'is the sequencing project'
    AND  assembly_data_label != 'TARANTELLAE_ANALYSIS' 
