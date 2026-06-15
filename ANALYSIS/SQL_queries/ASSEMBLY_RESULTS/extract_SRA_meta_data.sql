WITH input_data AS
(
    SELECT 
        DISTINCT SRA_accession
    FROM read_csv('{input_file}')
)
SELECT
    *
FROM read_parquet('{SRA_meta_data}')
JOIN input_data USING (SRA_accession)