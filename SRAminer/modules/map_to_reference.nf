process INDEX_REFERENCE {
    label 'small_job'
    conda 'bioconda::blast=2.16.0'
    tag "${accession}"
    
    input:
        tuple val(accession), path(reference_genome)
        
    output:
        tuple val(accession), path(reference_genome), path("${accession}*", arity: "1..*")
       
    script:
        """
        zstdcat ${reference_genome} | makeblastdb -dbtype nucl -parse_seqids -out ${accession} -title "${reference_genome.simpleName} blast database"
        """
        
    stub:
        """
        touch ${accession}.{nsq,not,nin,nhr,ndb,nto,nog,ntf,nos,njs}
        """
}


process MAP_TO_REFERENCE_AND_EXTRACT_READS {
    label 'medium_job'
    conda 'bioconda::magicblast=1.7.0 bioconda::samtools=1.20 bioconda::sra-tools=3.1.0 conda-forge::pigz=2.8'
    maxRetries 5
    errorStrategy { sleep(Math.pow(2, task.attempt) * 200 as long); return (task.attempt <= maxRetries) ? 'retry' : 'ignore' }
    publishDir "${output_folder}/${meta_data.SRA_accession}-${meta_data.reference_accession}", mode: 'link', overwrite: true, pattern: '*.gz'
    tag "${meta_data.SRA_accession}-${meta_data.reference_accession}"

    input:
        tuple val(meta_data), path(genome_index)
        val num_output_files
        val output_folder
        val percent_identity

    output:
        tuple val(meta_data), path("*.fasta*", arity: "1..2")

    script:
        label = "${meta_data.SRA_accession}_${meta_data.reference_accession}" 
        SRA_accession = meta_data.SRA_accession
        prefetched_data = meta_data.prefetched_data
        reads = meta_data.extracted_reads
        if ( reads.size() == 0){
            streaming_source      = prefetched_data != "" ? prefetched_data : SRA_accession
            extraction_parameters = "--stdout "
            
            if (meta_data.num_slices == 1 ) {
                extraction_tool = "fasterq-dump" 
            } else {
                extraction_tool = "fastq-dump"
                first_spot = (meta_data.data_slice*meta_data.spots_per_slice)+1
                last_spot  = (meta_data.data_slice+1)*meta_data.spots_per_slice
                extraction_parameters  += " --minSpotId ${first_spot} --maxSpotId ${last_spot}"
            }
            extraction_parameters += " --split-spot --skip-technical "
            extraction_parameters += meta_data.num_slices == 1 ? "--fasta-unsorted" : "--fasta" 

            read_streaming_command =  "${extraction_tool} ${extraction_parameters} ${streaming_source} |"

        } else { 
            read_streaming_command = ""
        }
        output_file_prefix = "${label}"
        output_file_prefix += meta_data.num_slices == 1 ? "" : "-${meta_data.data_slice}"

        mapping_command  = "magicblast -num_threads ${task.cpus} -no_unaligned -perc_identity ${percent_identity} -splice F -db ${genome_index[0].baseName} "
        mapping_command += reads.size() == 0 ? "" : "-query ${reads[0]}"
        mapping_command += reads.size() == 2 ? " -query_mate ${reads[1]} " : ""

        read_extraction_command  = "samtools fasta -n "
        read_extraction_command += reads.size() == 2 && num_output_files == 2 ? " -1 ${output_file_prefix}_1-mapped.fasta -2 ${output_file_prefix}_2-mapped.fasta -0 /dev/null -s /dev/null" : " > ${output_file_prefix}_mapped.fasta"
        compression_command = "pigz --force --processes ${task.cpus} --best *.fasta"

        size_check = reads.size() == 1 ? "rename_if_empty_gzip.sh ${output_file_prefix}_mapped.fasta.gz" : " rename_if_empty_gzip.sh ${output_file_prefix}_1-mapped.fasta.gz && rename_if_empty_gzip.sh ${output_file_prefix}_2-mapped.fasta.gz"
        """
        TMPDIR="." ${read_streaming_command} ${mapping_command} | ${read_extraction_command} && ${compression_command} && ${size_check}
        """

    stub:
        label       = "${meta_data.SRA_accession}_${meta_data.reference_accession}"
        output_file_prefix = "${label}"
        output_file_prefix += meta_data.num_slices == 1 ? "" : "-${meta_data.data_slice}"

        output_file = num_output_files == 1 ? "${output_file_prefix}_mapped.fasta" : "${output_file_prefix}_1-mapped.fasta ${output_file_prefix}_2-mapped.fasta"
        compression_command = "pigz --force --processes ${task.cpus} --fast *.fasta"
        """
        echo "^SEQ_ID" > ${output_file}
        echo "GATTTGGGGTTCAAAGCAGTATCGATCAAATAGTAAATCCATTTGTTCAACTCACAGTTT" >> ${output_file}

        ${compression_command}
        """
}

