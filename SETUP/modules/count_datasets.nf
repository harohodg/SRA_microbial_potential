/*
Count SRA datasets
*/
process COUNT_SRA_DATASETS {
    cpus 8
    conda 'conda-forge::duckdb-cli=1.1.3'
    tag "${size_threshold}:${coverage_threshold}"
    
    input:
        tuple path(extracted_database), val(size_threshold), val(coverage_threshold)
        val output_folder
        
    output:
        path("*.parquet")
        
    script:
        output_file="SRA_counts-${size_threshold}bases_${coverage_threshold}Xcoverage.parquet"
        """
        cat << EOF > query.sql

        SET threads=${task.cpus};
        SET temp_directory=".";

        SET autoinstall_known_extensions=1;
        SET autoload_known_extensions=1;

        COPY 
        (
            SELECT * FROM SRA_COUNTS(${size_threshold},${coverage_threshold})
        ) TO '${output_file}';
        EOF

        duckdb --readonly ${extracted_database} < query.sql
        """    
}


/*
Count NCBI datasets and add taxonomy labels
*/
process COUNT_NCBI_DATASETS {
    cpus 2
    conda 'conda-forge::duckdb-cli=1.1.3'
    publishDir "${output_folder}", mode: 'link', overwrite: true
    
    input:
        path extracted_database
        val output_folder
    
    output:
       path "NCBI_counts.parquet"
        
    script:
        """
        cat << EOF > query.sql

        SET threads=${task.cpus};
        SET temp_directory=".";

        SET autoinstall_known_extensions=1;
        SET autoload_known_extensions=1;

        COPY ( SELECT * FROM LABELED_REFSEQ_GENBANK_VIRAL_COUNTS )
        TO 'NCBI_counts.parquet';
        EOF

        duckdb --readonly ${extracted_database} < query.sql
        """               
}


/*
Merge NCBI/SRA counts
*/
process MERGE_NCBI_SRA_COUNTS {
    cpus 4
    conda 'conda-forge::duckdb-cli=1.1.3'
    publishDir "${output_folder}", mode: 'link', overwrite: true
    
    input:
        tuple path(NCBI_counts, stageAs: 'NCBI_counts.parquet' ), path(SRA_counts)
        val output_folder
        
    output:
        path "${SRA_counts.simpleName}-merged.parquet"
        
    script:
        """
        cat << EOF > query.sql

        SET threads=${task.cpus};
        SET temp_directory=".";

        SET autoinstall_known_extensions=1;
        SET autoload_known_extensions=1;

        COPY 
        (
            SELECT 
                *
            FROM 
                read_parquet('NCBI_counts.parquet')  AS NCBI_COUNTS 
                JOIN 
                read_parquet('SRA_counts-*.parquet') AS SRA_COUNTS USING (tax_id)
        ) TO '${SRA_counts.simpleName}-merged.parquet';
        EOF

        duckdb < query.sql
        """      
}

/*
Merge NCBI/SRA counts
*/
process MERGE_ALL_COUNTS {
    cpus 8
    conda 'conda-forge::duckdb-cli=1.1.3'
    publishDir "${output_folder}", mode: 'link', overwrite: true
    
    input:
        path(input_files)
        val output_folder
        
    output:
        path "all_dataset_counts.parquet"
        
    script:
        """
        cat << EOF > query.sql

        SET threads=${task.cpus};
        SET temp_directory=".";

        SET autoinstall_known_extensions=1;
        SET autoload_known_extensions=1;

        COPY
        (
            WITH NCBI_COUNTS AS 
            (
                SELECT
                    tax_id,
                    num_refseq_genomes,
                    num_genbank_genomes,
                    num_viral_datasets,
                    sci_name,
                    root_taxonomy_label,
                FROM read_parquet('NCBI_counts.parquet')
            ), SRA_COUNTS AS
            (
                SELECT 
                    tax_id,
                    num_SRA_datasets,
                    min_bases,
                    min_coverage
                FROM read_parquet('SRA_counts-*.parquet') 
            ), PIVOTED_SRA_COUNTS AS
            (
                PIVOT SRA_COUNTS ON min_bases,min_coverage USING SUM(num_SRA_datasets) 
                GROUP BY tax_id
            ), LABELED_PIVOTED_SRA_COUNTS AS
            (
                SELECT 
                    IFNULL( columns('.*'), 0 )
                FROM PIVOTED_SRA_COUNTS
            )
            SELECT 
                * 
            FROM 
                NCBI_COUNTS JOIN LABELED_PIVOTED_SRA_COUNTS USING (tax_id)
        ) TO 'all_dataset_counts.parquet';
        EOF

        duckdb < query.sql
        """      
}
