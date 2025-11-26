process FETCH_CHECKM_DATABASE {
    label 'small_job'
    errorStrategy { sleep(Math.pow(2, task.attempt) * 200 as long); return 'retry' }
    maxRetries 3
    
    output:
        path "CheckM2_database/*.dmnd"
    
    script:
        """
        wget -O - 'https://zenodo.org/record/5571251/files/checkm2_database.tar.gz?download=1' | tar -xzvf -
        """
    
    stub:
        """
        mkdir CheckM2_database
        touch CheckM2_database/uniref100.KO.1.dmnd
        """
}


process CHECKM2 {
    label 'medium_job'
    conda 'python=3.7 bioconda::checkm2=1.0.2 conda-forge::duckdb-cli=1.1.3'
    publishDir "${output_folder}", mode: 'link', overwrite: true, pattern: "checkm_results", saveAs: { fn -> "${meta_data.assembly_label}" }
    tag "${meta_data.assembly_label}"
    
    input:
        tuple val(meta_data), path(input_file), path(checkm_database)
        val(output_folder)
        
    output:
        path "checkm_results", emit: all_checkm_data
        path "checkm_results/${meta_data.assembly_label}-checkm_report.tsv",  optional: true, emit: report



    script:
        additional_columns = meta_data.subMap(['reference_accession', 'group']).collect { key, value -> "'${value}' AS '${key}'" }.join(', ')
        """
        cat << EOF > query.sql
        COPY
        (
            SELECT
                ${additional_columns},
                *,
            FROM read_csv('checkm_results/quality_report.tsv')
        ) TO 'checkm_results/${meta_data.assembly_label}-checkm_report.tsv' (FORMAT CSV, DELIMITER '\t', HEADER);
        EOF

        checkm2 predict --threads ${task.cpus} --input ${input_file} --database_path ${checkm_database} --force --output-directory ./checkm_results && duckdb < query.sql || echo 'Failed'
        """
        
    stub:
        additional_columns = meta_data.subMap(['reference_accession', 'group']).collect { key, value -> "'${value}' AS '${key}'" }.join(', ')
        """
        cat << EOF > query.sql
        COPY
        (
            SELECT
                ${additional_columns},
                *,
            FROM read_csv('checkm_results/quality_report.tsv')
        ) TO 'checkm_results/${meta_data.assembly_label}-checkm_report.tsv' (FORMAT CSV, DELIMITER '\t', HEADER);
        EOF


        mkdir checkm_results

        echo -e 'Name\tCompleteness\tContamination\tCompleteness_Model_Used\tTranslation_Table_Used\tCoding_Density\tContig_N50\tAverage_Gene_Length\tGenome_Size\tGC_Content\tTotal_Coding_Sequences\tTotal_Contigs\tMax_Contig_Length\tAdditional_Notes' > checkm_results/quality_report.tsv
        echo -e '${meta_data['label']}\t50.45\t0.2\tGradient Boost (General Model)\t11\t0.949\t1107\t173.42372881355934\t129071\t0.33\t236\t151\t12428\tNone' >> checkm_results/quality_report.tsv

        duckdb < query.sql
        """
}
