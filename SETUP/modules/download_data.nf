/*
List SRA AWS files
*/
process LIST_SRA_FILES {
    conda 'conda-forge::awscli=2.17.63'
    input:
        val url
    
    output:
        path "results.txt"
    
    shell:
        '''
        aws s3 ls --no-sign-request s3://sra-pub-metadata-us-east-1/!{url}/ | awk -F ' ' '{print "!{url}/"$4}' > results.txt
        '''
}

/*
Download SRA data
*/
process DOWNLOAD_SRA_DATA {
    conda 'conda-forge::awscli=2.17.63'
    maxForks 4
    
    publishDir "${output_folder}", mode: 'link', overwrite: true
    
    input:
        val(url)
        val(output_folder)
        val(output_label)
    
    output:
        path "${output_label}-${task.index}.parquet"
        
    script:
        """
        aws s3 cp --no-sign-request s3://sra-pub-metadata-us-east-1/${url} ${output_label}-${task.index}.parquet
        """    
}

/*
Download NCBI genomic/viral dataset summaries
*/
process DOWNLOAD_NCBI_DATA {
    cpus 4
    conda 'conda-forge::ncbi-datasets-cli=16.30.1 conda-forge::pigz=2.3.4'
    publishDir "${output_folder}", mode: 'link', overwrite: true
    
    input:
        val command
        val output_folder
        val output_file
    
    output:
        path "${output_file}"
    
    script:
        """
        datasets summary ${command} | pigz --processes ${task.cpus}  --best > ${output_file} 
        """
}