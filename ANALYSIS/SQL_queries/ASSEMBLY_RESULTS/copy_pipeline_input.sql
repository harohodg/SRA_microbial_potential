SELECT 
    {columns_to_keep} 
FROM read_csv('{input_file}')
WHERE {data_filter}
GROUP BY ALL