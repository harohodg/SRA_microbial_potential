WITH random_data AS 
( 
    SELECT * FROM read_parquet('{random_data_file}') 
), top_n_data AS 
(
    SELECT * FROM read_parquet('{top_n_data_file}') 
    WHERE (SRA_accession,reference_accession) NOT IN (SELECT (SRA_accession, reference_accession) FROM random_data ) 
), tarantellae_data AS
(
   SELECT * FROM read_parquet('{tarantellae_data_file}')  
) 
SELECT 
    * 
FROM tarantellae_data 

UNION ALL 

SELECT 
    * 
FROM random_data 

UNION ALL 

SELECT 
    * 
FROM top_n_data
