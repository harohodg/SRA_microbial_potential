process MEGAHIT {
    errorStrategy 'ignore'
    label 'medium_job'
    conda 'bioconda::megahit=1.2.9'
    publishDir "${output_folder}/", mode: 'link', overwrite: true
    tag "${meta_data.assembly_label}"    


    input:
        tuple val(meta_data), val(reads_to_assemble)
        val(output_folder)
        
    output:
        tuple val(meta_data), path("${meta_data.assembly_label}/${meta_data.assembly_label}.contigs.fa"), emit: contigs
        path "${meta_data.assembly_label}/*.log", optional: true, emit: log_file
       
    script:
        assembly_label = meta_data.assembly_label
        output_file    = "${assembly_label}/${assembly_label}.contigs.fa"
        log_file       = "${assembly_label}/${assembly_label}.log"

        def SE_files   = reads_to_assemble.findAll{ it.size() == 1}.collect{ it[0] }
        def PE_file_1  = reads_to_assemble.findAll{ it.size() == 2}.collect{ it[0] }
        def PE_file_2  = reads_to_assemble.findAll{ it.size() == 2}.collect{ it[1] }
        
        parameters = ""
        parameters += SE_files.size()  != 0 ? "-r ${SE_files.join(',')} "  : ""
        parameters += PE_file_1.size() != 0 ? "-1 ${PE_file_1.join(',')} " : ""
        parameters += PE_file_2.size() != 0 ? "-2 ${PE_file_2.join(',')} " : ""
        
        num_files   = SE_files.size() + PE_file_1.size() + PE_file_2.size()
        assembly_command = num_files != 0 ? "megahit -t ${task.cpus} ${parameters} --out-prefix ${assembly_label} -o ${assembly_label} --continue" : "mkdir -p ${assembly_label} && touch ${output_file} && echo 'No input reads' > ${log_file}"
        """
        ${assembly_command} 
        """
        
    stub:
        assembly_label = meta_data.assembly_label
        output_file    = "${assembly_label}/${assembly_label}.contigs.fa"
        log_file       = "${assembly_label}/${assembly_label}.log"
        """
        mkdir ${assembly_label} 

        touch ${log_file}

        echo "@SEQ_ID" > ${output_file}
        echo "GATTTGGGGTTCAAAGCAGTATCGATCAAATAGTAAATCCATTTGTTCAACTCACAGTTT" >> ${output_file}
        echo "+" >> ${output_file}
        echo "!''*((((***+))%%%++)(%%%%).1***-+*''))**55CCF>>>>>>CCCCCCC65" >> ${output_file}
        """
}
