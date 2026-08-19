SELECT
   SRA_assay_type AS assay_type,
   CHECKM_Max_Contig_Length AS max_contig_length,
   log10( max_contig_length ) AS log10_max_Contig_Length
FROM read_parquet('{data_table}')
WHERE {data_filter}