WITH intermediate_data AS
(
    SELECT 
        *,
        SRA_average_read_length*STAT_num_reads/reference_genome_genome_size AS genome_coverage,
        CASE 
            WHEN data_source != 'is the sequencing project' AND STAT_root_taxonomy NOT IN SRA_what_was_sequenced_root_taxonomy_labels THEN 'is novel' 
            WHEN data_source = 'is the sequencing project'  THEN 'is the sequencing project'
            WHEN STAT_root_taxonomy IN SRA_what_was_sequenced_root_taxonomy_labels THEN 'overlapping root taxonomy' 
        END AS assembly_type
    FROM read_parquet('{data_table}')
    WHERE {primary_data_filter}
), summarized_data AS
(
    SELECT
        {columns_to_group_by},

        COUNT( DISTINCT CASE WHEN {secondary_data_filter} THEN reference_accession END )   AS num_species,
        COUNT( DISTINCT CASE WHEN {secondary_data_filter} THEN SRA_accession END )         AS num_datasets,
        COUNT( CASE WHEN {secondary_data_filter} THEN 1 END )                              AS num_assemblies,

        COUNT( DISTINCT reference_accession )   AS total_num_species,
        COUNT( DISTINCT SRA_accession )         AS total_num_datasets,
        COUNT( * )                              AS total_num_assemblies,

        num_species    / total_num_species      AS fraction_of_species,
        num_datasets   / total_num_datasets     AS fraction_of_datasets,
        num_assemblies / total_num_assemblies   AS fraction_of_assemblies,

        MAX( CASE WHEN {secondary_data_filter} THEN genome_coverage END ) AS max_genome_coverage,
        MAX( CASE WHEN {secondary_data_filter} THEN CHECKM_Completeness END ) AS max_CHECKM_Completeness,
        MAX( CASE WHEN {secondary_data_filter} THEN CHECKM_Contamination END ) AS max_CHECKM_Contamination,
        MAX( CASE WHEN {secondary_data_filter} THEN global_ANI END ) AS max_global_ANI,

        MIN( CASE WHEN {secondary_data_filter} THEN genome_coverage END ) AS min_genome_coverage,
        MIN( CASE WHEN {secondary_data_filter} THEN CHECKM_Completeness END ) AS min_CHECKM_Completeness,
        MIN( CASE WHEN {secondary_data_filter} THEN CHECKM_Contamination END ) AS min_CHECKM_Contamination,
        MIN( CASE WHEN {secondary_data_filter} THEN global_ANI END ) AS min_global_ANI,

        MEAN( CASE WHEN {secondary_data_filter} THEN genome_coverage END ) AS average_genome_coverage,
        MEAN( CASE WHEN {secondary_data_filter} THEN CHECKM_Completeness END ) AS average_CHECKM_Completeness,
        MEAN( CASE WHEN {secondary_data_filter} THEN CHECKM_Contamination END ) AS average_CHECKM_Contamination,
        MEAN( CASE WHEN {secondary_data_filter} THEN global_ANI END ) AS average_global_ANI,

    FROM intermediate_data
    GROUP BY ALL
)

SELECT
    {columns_to_keep}
FROM summarized_data