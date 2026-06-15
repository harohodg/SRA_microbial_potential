process FILE_STATS {
    cpus 2
    conda 'bioconda::seqkit=2.8.2 conda-forge::duckdb-cli=1.4.1'
    tag "${input_file.baseName}" 
    
    
    input:
        tuple val(meta_data), path(input_file) 
        
    output:
        tuple val(meta_data), path('file_stats.tsv')
    
    script:
        """
        seqkit stats --tabular --threads ${task.cpus} ${input_file} > temp_stats.tsv

        cat << EOF > query.sql
        COPY 
        (
        SELECT
            num_seqs,
            sum_len,
            min_len,
            max_len
        FROM read_csv('temp_stats.tsv')
        ) TO file_stats.tsv (DELIMITER '\t', HEADER true);
        EOF
        
        duckdb < query.sql 
        """
        
    stub:

        """
        echo -e "num_seqs\tsum_len\tmin_len\tmax_len" > file_stats.tsv
        echo -e "1\t423\t3\t56" >> file_stats.tsv
        """
}


process SUMMARIZE_FILE_STATS {
    cpus 2
    conda 'conda-forge::duckdb-cli=1.4.1'
    
    input:
        tuple val(meta_data), path(input_files, name: 'input_files') 
        
    output:
        tuple val(meta_data), path('merged_stats.tsv')
    
    script:
        """
        cat << EOF > query.sql
        COPY 
        (
        SELECT
            SUM( COLUMNS('.*num_seqs|.*sum_len') )::UBIGINT, 
            MIN( COLUMNS('.*min_len') )::UBIGINT, 
            MAX( COLUMNS('.*max_len') )::UBIGINT 
        FROM read_csv('input_files*')
        ) TO merged_stats.tsv (DELIMITER '\t', HEADER true);
        EOF
        
        duckdb < query.sql
        """
}

process RELABEL_STATS_COLUMNS {
    cpus 2
    conda 'conda-forge::duckdb-cli=1.4.1'
    
    input:
        tuple val(meta_data), val(stats_label), path(input_file) 
        
    output:
        path('updated_stats.tsv')
    
    script:
        meta_data_to_export = meta_data.collect { k, v -> "'${v}' AS ${k}" }.join(',')
        """
        cat << EOF > query.sql
        COPY 
        (
        SELECT
            ${meta_data_to_export},
            COLUMNS(*) AS "${stats_label}_\\0"
        FROM read_csv(${input_file})
        ) TO updated_stats.tsv (DELIMITER '\t', HEADER true);
        EOF
        
        duckdb < query.sql
        """
}


process COMBINE_FILE_STATS {
    cpus 2
    conda 'conda-forge::duckdb-cli=1.4.1'
    
    input:
        path(input_files, name: 'input_file') 
        
    output:
        path('combined_stats.tsv')
    
    script:
        """
        cat << EOF > query.sql
        COPY 
        (
        SELECT
            *
        FROM read_csv('input_file*')
        ) TO combined_stats.tsv (DELIMITER '\t', HEADER true);
        EOF
        
        duckdb < query.sql
        """
}


process FILTER_DATA_COLUMNS {
    cpus 2
    conda 'conda-forge::duckdb-cli=1.4.1'
    
    input:
        tuple val(meta_data), val(to_keep), path(input_file) 
        
    output:
        path('filtered_data.tsv')
    
    script:
        meta_data_to_export = meta_data.collect { k, v -> "'${v}' AS ${k}" }.join(',')
        columns_to_keep     = to_keep.join(',')
        """
        cat << EOF > query.sql
        COPY 
        (
        SELECT
            ${meta_data_to_export},
            ${columns_to_keep}
        FROM read_csv('${input_file}')
        ) TO filtered_data.tsv (DELIMITER '\t', HEADER true);
        EOF
        
        duckdb < query.sql
        """
}

process MERGE_STATS_AND_RESULTS {
    cpus 4
    conda 'conda-forge::duckdb-cli=1.4.1'
    
    input:
        path(input_files) 
        
    output:
        path('summarized_results.tsv')
    
    script:
        """
        echo "SET threads=${task.cpus};" >> query.sql
        echo ".mode tab"                 >> query.sql
        cat ${projectDir}/sql_queries/merge_stats_and_results.sql >> query.sql
        duckdb < query.sql > summarized_results.tsv
        """
}