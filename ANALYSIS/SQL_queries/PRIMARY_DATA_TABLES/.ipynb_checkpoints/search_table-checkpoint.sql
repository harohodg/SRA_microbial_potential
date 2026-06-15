SELECT 
    COLUMNS( queries.* ) AS 'query_\0',
    COLUMNS( summarized_stat_data.* ) AS 'STAT_\0',
    COLUMNS( updated_meta_data.* ) AS 'meta_data_\0',


    CASE
        WHEN queries.tax_id IS NOT NULL AND queries.tax_id IN genome_projects.tax_ids     THEN 'an associated sequencing project'
        WHEN queries.tax_id IS NOT NULL AND queries.tax_id NOT IN genome_projects.tax_ids THEN concat_ws(' ', 'a', array_to_string(updated_meta_data.what_was_sequenced_root_taxonomy_labels,'|'), 'sequencing project')
        ELSE NULL    
    END AS sequencing_project_type,

    queries.root_taxonomy IN  updated_meta_data.what_was_sequenced_root_taxonomy_labels AS root_taxonomy_overlap,
    updated_meta_data.what_was_sequenced LIKE '%metagenome%' AS metagenomic_data_source

FROM 
    read_parquet('{data_folder}/{target_taxonomy}-summarized_STAT_data.parquet') AS summarized_stat_data
    LEFT JOIN  
    read_parquet('{data_folder}/SRA_meta_data.parquet') AS updated_meta_data
    ON (summarized_stat_data.SRA_accession = updated_meta_data.SRA_accession) 
    LEFT JOIN 
    read_parquet('{data_folder}/genome_counts.parquet') AS queries
    ON (summarized_stat_data.tax_id = queries.tax_id)
    LEFT JOIN 
    read_parquet('{data_folder}/sequencing_projects.parquet') AS genome_projects
    ON  ( updated_meta_data.biosample = genome_projects.biosample )