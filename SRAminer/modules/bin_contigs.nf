process SKANI_LABEL_CONTIGS {
    label 'medium_job'
    conda 'bioconda::skani=0.2.2 conda-forge::duckdb-cli=1.1.3'
    publishDir "${output_folder}/${meta_data.assembly_label}", mode: 'link', overwrite: true,  pattern: "*.tsv"
    tag "${meta_data.assembly_label}"    


    input:
        tuple val(meta_data), path(contigs_file), path(reference_genome)
        val output_folder
        
    output:
        tuple val(meta_data), path(contigs_file), path("*-skani_labels.tsv")
       
    script:
        label = meta_data.assembly_label
        """
        touch ${label}-skani_labels.tsv
        skani dist -t ${task.cpus} --qi ${contigs_file} ${reference_genome} > skani_labels.tsv || echo 'skani failed' && duckdb -csv -c "SELECT Query_name AS contig, * EXCLUDE (Query_name)  FROM read_csv('skani_labels.tsv');" | tr ',' '\t' > ${label}-skani_labels.tsv
        """
        
    stub:
        label = meta_data.assembly_label
        """
        echo -e 'contig\tRef_file\tQuery_file\tANI\tAlign_fraction_ref\tAlign_fraction_query\tRef_name' > ${contigs_file.simpleName}-skani_labels.tsv
        echo -e 'contig_label\treference_genome\tcontigs_file\t97.22\t0.18\t93.44\t"sequence_label"' >> ${label}-skani_labels.tsv
        """
}



process FILTER_CONTIG_LABELS {
    label 'medium_job'
    conda 'conda-forge::duckdb-cli=1.1.3'
    tag "${meta_data.assembly_label}"
    
    input:
        tuple val(meta_data), path(contigs_file), path(labels_file)
        val query_filter

    output:
        tuple val(meta_data), path(contigs_file), path("*-filtered_contigs.tsv")
    
    script:
        label = meta_data.assembly_label
        """
        duckdb -csv -noheader -c "SELECT DISTINCT( contig ) FROM read_csv('${labels_file}') WHERE ${query_filter};" > ${label}-filtered_contigs.tsv
        """
        
    stub:
        label = meta_data.assembly_label
        """
        echo -e 'contig_1\ncontig_2' > ${label}-filtered_contigs.tsv
        """
}


process EXTRACT_CONTIGS {
    label 'medium_job'
    conda 'bioconda::seqkit=2.8.2 conda-forge::pigz=2.8'
    publishDir "${output_folder}/${meta_data.assembly_label}", mode: 'link', overwrite: true, pattern: '*.gz'
    tag "${meta_data.assembly_label}"
    
    input:
        tuple val(meta_data), path(contigs_file), path(contigs_list)
        val output_folder
        val output_label
        
    output:
        tuple val(meta_data), path("*.fa*")
        
    script:
        label = meta_data.assembly_label
        """
        seqkit grep --by-name --threads ${task.cpus} -f ${contigs_list} ${contigs_file} \
            | pigz --best > ${label}-${output_label}.fa.gz \
            && rename_if_empty_gzip.sh ${label}-${output_label}.fa.gz
        """
        
    stub:
        label = meta_data.assembly_label
        """
        echo -e 'contig_1\nATCG\ncontig_2\nTAGC' | gzip --best > ${label}-${output_label}.fa.gz
        """
}

process SIZE_FILTER_CONTIGS {
    label 'medium_job'
    conda 'bioconda::seqkit=2.8.2'
    publishDir "${output_folder}/${meta_data.assembly_label}", mode: 'link'
    tag "${meta_data.assembly_label}"
    
    input:
        tuple val(meta_data), path(contigs_file)
        val min_length
        val output_folder
        
    output:
        tuple val(meta_data), path("*.fa")
        
    script:
        label = meta_data.assembly_label
        """
        seqkit seq --threads ${task.cpus} --min-len ${min_length} ${contigs_file} --out-file ${label}-size_filtered.fa
        """
        
    stub:
        label = meta_data.assembly_label
        """
        echo -e 'contig_1\nATCG\ncontig_2\nTAGC' > ${label}-size_filtered.fa
        """

}

