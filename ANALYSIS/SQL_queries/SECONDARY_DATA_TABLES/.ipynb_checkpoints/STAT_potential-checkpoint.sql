WITH data AS 
( 
    SELECT
        {genome_coverage_threshold} AS genome_coverage_threshold,
        query_root_taxonomy_label AS query_root_taxonomy, 
--        list_distinct( meta_data_what_was_sequenced_root_taxonomy_labels) AS sequenced_root_taxonomy, 
        CASE
            WHEN meta_data_what_was_sequenced_root_taxonomy_labels = [] THEN NULL
            ELSE  NOT query_root_taxonomy_label IN meta_data_what_was_sequenced_root_taxonomy_labels 
        END AS is_novel_assembly,
        meta_data_assay_type AS assay_type, 
        meta_data_platform   AS sequencing_platform, 
        estimated_genome_coverage,
        STAT_SRA_accession,
        STAT_species_tax_id,
    FROM read_parquet('{search_data_table}') 
    WHERE 
        estimated_genome_coverage >= {genome_coverage_threshold}
        AND
        meta_data_dataset_size >= {min_dataset_size}
        AND
        {num_genomes_filter}
)
SELECT 
    {columns_to_group},
    
    COUNT( DISTINCT STAT_SRA_accession ) AS num_datasets,
    COUNT( DISTINCT STAT_species_tax_id ) AS num_species,
    COUNT(*) AS num_assemblies,
    
    MIN( estimated_genome_coverage ) AS estimated_genome_coverage_min,
    MAX( estimated_genome_coverage ) AS estimated_genome_coverage_max,
    STDDEV( estimated_genome_coverage ) AS estimated_genome_coverage_std
FROM data
GROUP BY ALL;