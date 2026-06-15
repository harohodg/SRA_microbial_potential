WITH assembly_data AS
(
    SELECT 
        parse_path(filename)[-2] AS batch_num, 
        parse_path(filename)[-3] AS root_taxonomy, 
        parse_path(filename)[-4] AS assembly_type,

        *
    FROM  read_parquet('{results_files}', filename:=true) 
    WHERE length(grouped_SRA_accession) != 1
)
SELECT
    assembly_data.*,
    CASE
        WHEN reference_genome_biosample IN grouped_SRA_biosample THEN 'one of the datasets is the sequencing project'
        WHEN sequencing_projects.biosample IS NOT NULL AND reference_genome_species_tax_id NOT IN sequencing_projects.tax_ids THEN 
            concat_ws(' ', 'is a', array_to_string( array_distinct( assembly_data.grouped_SRA_what_was_sequenced_root_taxonomy_labels ),'|'), 'sequencing project') 
        ELSE 'is NOT a known sequencing project'
    END AS data_source,

    CASE 
        WHEN IFNULL(mapped_reads_num_seqs, 0) = 0 THEN 'no mapped reads'
        WHEN IFNULL(megahit_contigs_num_seqs, 0) = 0 THEN 'no assembled contigs'
        WHEN IFNULL(size_filtered_pipeline_num_seqs, 0) = 0 THEN 'no size filtered contigs'
        WHEN IFNULL(binned_contigs_pipeline_num_seqs, 0) = 0 THEN 'no binned contigs'
        WHEN CHECKM_Completeness IS NULL AND global_ANI IS NOT NULL THEN 'no Checkm results, has global ANI'
        WHEN CHECKM_Completeness IS NOT NULL AND global_ANI IS NULL THEN 'no global ANI, has Checkm results'
        WHEN CHECKM_Completeness IS NULL AND global_ANI IS NULL THEN 'no Checkm results AND no global ANI'
        ELSE 'assembled'
    END AS assembly_status,

    CASE 
        WHEN global_ANI >= 99 THEN 'strain'
        WHEN global_ANI >= 95 THEN 'species'
        WHEN global_ANI >= 90 THEN 'genus'
        WHEN global_ANI IS NOT NULL THEN 'UNKNOWN'
    END AS ANI_similarity,

    CASE
        WHEN CHECKM_Completeness  > 90 AND CHECKM_Contamination  <  5 THEN 'High'
        WHEN CHECKM_Completeness >= 50 AND CHECKM_Contamination  < 10 THEN 'Medium'
        WHEN CHECKM_Completeness  < 50 AND CHECKM_Contamination  < 10 THEN 'Low'
        WHEN CHECKM_Completeness  >  0 AND CHECKM_Contamination <= 10 THEN 'Poor'
    END AS assembly_quality
FROM 
    assembly_data
    LEFT JOIN 
    read_parquet('{sequencing_projects}') AS sequencing_projects
    ON  ( sequencing_projects.biosample IN  assembly_data.grouped_SRA_accession) 