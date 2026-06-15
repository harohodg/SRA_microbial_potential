WITH intermediate_data AS
(
    SELECT
        {intermediate_columns_to_keep},
        Completeness,
        Contamination,
        Completeness_Model_Used,
        Translation_Table_Used,
        Coding_Density,
        Contig_N50,
        Average_Gene_Length,
        Genome_Size,
        GC_Content,
        Total_Coding_Sequences,
        Total_Contigs,
        Max_Contig_Length,
        Additional_Notes
    FROM read_csv('{data_files}')
)
SELECT
    {columns_to_keep},
    COLUMNS(* EXCLUDE({columns_to_keep}) ) AS 'CHECKM_\0'
FROM intermediate_data