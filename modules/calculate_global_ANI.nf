process GLOBAL_ANI {
    label 'medium_job'
    conda 'bioconda::skani=0.2.2 conda-forge::duckdb-cli=1.1.3' 
    publishDir "${output_folder}/${meta_data.assembly_label}", mode: 'link', overwrite: true,  pattern: "*.tsv"
    tag "${meta_data.assembly_label}"    


    input:
        tuple val(meta_data), path(contigs_file), path(reference_genome)
        val output_folder
        
    output:
        tuple val(meta_data), stdout, path("*-global_ANI.tsv")
       
    script:
        label       = meta_data.assembly_label
        output_file = "${contigs_file.simpleName}-global_ANI.tsv"
        additional_columns = meta_data.subMap(['reference_accession', 'group']).collect { key, value -> "'${value}' AS '${key}'" }.join(', ')
        """
        cat << EOF > query.sql
        COPY
        (
            SELECT
                ${additional_columns},
                *,
            FROM read_csv('global_ani.tsv')
        ) TO '${output_file}' (FORMAT CSV, DELIMITER '\t', HEADER);
        EOF

        touch ${output_file}
        skani dist -t ${task.cpus} ${contigs_file} ${reference_genome} > global_ani.tsv || echo 'skani failed' && duckdb < query.sql
        """
        
    stub:
        label = meta_data.assembly_label
        output_file = "${contigs_file.simpleName}-global_ANI.tsv"
        additional_columns = meta_data.subMap(['reference_accession', 'group']).collect { key, value -> "'${value}' AS '${key}'" }.join(', ')
        """
        cat << EOF > query.sql
        COPY
        (
            SELECT
                ${additional_columns},
                *,
            FROM read_csv('global_ani.tsv')
        ) TO '${output_file}' (FORMAT CSV, DELIMITER '\t', HEADER);
        EOF

        echo -e 'ANI\tAlign_fraction_ref\tAlign_fraction_query' > global_ani.tsv
        echo -e '97.22\t0.18\t93.44' >> global_ani.tsv

        duckdb < query.sql
        """
}