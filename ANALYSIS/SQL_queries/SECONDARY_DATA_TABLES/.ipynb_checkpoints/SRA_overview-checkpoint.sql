SELECT 
    'all datasets' AS data_source,
    column_name, 
    min, 
    max, 
    approx_unique, 
    avg, 
    std, 
    q25, 
    q50, 
    q75, 
    "count", 
    null_percentage 
FROM (SUMMARIZE SRA_meta_data)

UNION ALL

SELECT 
    'metagenomic datasets' AS data_source,
    column_name, 
    min, 
    max, 
    approx_unique, 
    avg, 
    std, 
    q25, 
    q50, 
    q75, 
    "count", 
    null_percentage 
FROM (SUMMARIZE (SELECT * FROM SRA_meta_data WHERE organism LIKE '%metagenome%') );