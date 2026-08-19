SELECT
    CHECKM_Completeness,
    CHECKM_Contamination,
    global_ANI,
    assembly_quality,
    ANI_similarity,
    {coverage_equation} AS genome_coverage
FROM read_parquet('{data_table}')
WHERE 
    ({novel_assembly_equation}) = true 
    AND 
    ({succesfull_assembly_equation}) = true 
    AND assembly_data_label != 'TARANTELLAE_ANALYSIS'