SELECT 
        {target_column}, 
        COUNT(*) OVER (ORDER BY {target_column} ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS from_start,
        COUNT(*) OVER (ORDER BY {target_column} ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING) AS from_end,
        COUNT(*) OVER ()  as num_rows,
        from_start/num_rows AS fraction_less_than_or_equal,
        from_end/num_rows AS fraction_greater_than_or_equal
    FROM read_parquet('{data_file}') 
    WHERE {data_filter}