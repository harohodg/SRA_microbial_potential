process PREFETCH_SRA_DATASET {
    label 'small_job'
    conda 'bioconda::sra-tools=3.1.0'
    maxRetries 3
    errorStrategy { sleep(Math.pow(2, task.attempt) * 200 as long); return (task.attempt <= maxRetries) ? 'retry' : 'ignore' }
    publishDir "${output_folder}/", mode: 'link', overwrite: true

    tag "${meta_data.SRA_accession}" 
    
    input:
        val meta_data
        val scores_format
        val output_folder
    
    output:
        tuple val(meta_data), path("${meta_data.SRA_accession}/**.sra*")
    
    script:
        accession = meta_data.SRA_accession
        download_parameters = scores_format == 'lite' ? '--eliminate-quals' : ''
        meta_data += [quality_scores : scores_format]
        """        
        prefetch ${accession} ${download_parameters} --force all --max-size 100g -O .
        """
        
    stub:
        accession = meta_data.SRA_accession
        download_parameters = scores_format == 'lite' ? '--eliminate-quals' : ''
        meta_data += [quality_scores : scores_format]
        """
        mkdir ${accession}
        touch ${accession}/${accession}.sra${ scores_format == 'lite' ? 'lite' : ''}
        """
}

process EXTRACT_SRA_DATASET {
    label 'small_job'
    maxRetries 5
    errorStrategy { sleep(Math.pow(2, task.attempt) * 200 as long); return (task.attempt <= maxRetries) ? 'retry' : 'ignore' }
    conda 'bioconda::sra-tools=3.1.1 conda-forge::pigz=2.8'
    publishDir "${output_folder}/${meta_data.SRA_accession}-${meta_data.quality_scores}", mode: 'link', overwrite: true
    tag "${meta_data.SRA_accession}-${meta_data.quality_scores}:slice ${meta_data.data_slice+1} of ${meta_data.num_slices}" 
    
    input:
        val meta_data
        val extraction_format
        val output_folder
        
    output:
        tuple val(meta_data), path("${meta_data.SRA_accession}.fasta.gz", arity: '0..*'), path("${meta_data.SRA_accession}_{1,2}.fasta.gz", arity: '0..*')

    script:
        accession             = meta_data.SRA_accession
        to_extract = meta_data.prefetched_data.size() != 0 ? meta_data.prefetched_data : meta_data.SRA_accession
        extraction_parameters = extraction_format == 'SE' ? '--split-spot --skip-technical ' : '--split-3 --skip-technical '
        
        if (meta_data.num_slices == 1 ) {
            extraction_tool = "fasterq-dump --threads ${task.cpus}" 
        } else {
            extraction_tool = "fastq-dump"
            extraction_parameters = extraction_format == 'SE' ? '--split-spot --skip-technical ' : '--split-3 --skip-technical' 
            first_spot = (meta_data.data_slice*meta_data.spots_per_slice)+1
            last_spot  = (meta_data.data_slice+1)*meta_data.spots_per_slice
            extraction_parameters += " --minSpotId ${first_spot} --maxSpotId ${last_spot} "
        }
        extraction_parameters += meta_data.num_slices == 1 && extraction_format == 'SE' ? "--fasta-unsorted" : "--fasta" 

        """
        ${extraction_tool} ${to_extract} ${extraction_parameters} -O . && pigz --force --processes ${task.cpus} --fast *.fasta 
        """
        
    stub:
        accession = meta_data.SRA_accession
        """
        ${ extraction_format == 'SE' ? "touch ${accession}.fastq.gz" : "touch ${accession}_1.fastq.gz ${accession}_2.fastq.gz" } 
        """
}

process DOWNLOAD_REFERENCE_GENOME {
    label 'serial_job'
    submitRateLimit = '1/2sec'
    maxForks 25
    conda 'conda-forge::ncbi-datasets-cli=16.30.1 conda-forge::unzip=6.0 conda-forge::pigz=2.8'
    maxRetries 5
    errorStrategy { sleep(Math.pow(2, task.attempt) * 1000 as long); return (task.attempt <= maxRetries) ? 'retry' : 'ignore' }
    publishDir "${output_folder}", mode: 'link', overwrite: true, pattern: '*.gz'
    tag "${accession}"
    
    input:
        val accession
        val output_folder
        val caching_folder
        
    output:
        tuple val(accession), path("${accession}.fna*")
       
    script:
        local_file="${accession}.fna.gz"
        temp_local_file="${local_file}.partial"
        cached_file = caching_folder != ''   ? "${caching_folder}/${local_file}" : ""
        temp_cached_file = cached_file != '' ? "${cached_file}.partial" : ""
        
        if ( cached_file != "" && file(cached_file).exists() )
            """
            cp ${cached_file} ${temp_local_file} && mv ${temp_local_file} ${local_file}
            """
        else if (caching_folder != '')
            """
            download_genome.sh ${accession} \
                | pigz --best > ${local_file} \
                && mkdir -p ${caching_folder} \
                && cp ${local_file} ${temp_cached_file} \
                && mv ${temp_cached_file} ${cached_file} \
                && rm ${accession}.zip
            """
        else
            """
            download_genome.sh ${accession} \
                | pigz --best > ${local_file} \
                && rm ${accession}.zip
            """

    
    stub:
        """
        touch ${accession}.fna
        """
}



process CALCULATE_NUM_SPOTS {
    maxForks 4
    label 'serial_job'
    maxRetries 5
    errorStrategy { sleep(Math.pow(2, task.attempt) * 1000 as long); return (task.attempt <= maxRetries) ? 'retry' : 'ignore' }
    conda 'bioconda::sra-tools=3.1.1'
    tag "${accession}"
    
    input:
        val meta_data
        
    output:
        tuple val(meta_data), stdout
        
    shell:
        accession = meta_data.SRA_accession
        '''
        sleep $((RANDOM % 20 + 1))
        vdb-dump --info !{accession} | grep '^SEQ' | tr -d 'SEQ: ,\n' > results.txt
        if [ -s "results.txt" ]; then
            cat results.txt 
        else
            echo "!{accession} returned an empty string"
            exit 1
        fi
        '''
        
    stub:
        accession = meta_data.SRA_accession
        """
        echo "16600251"
        """
}



process CHECK_LOGAN_ACCESSIONS {
    label 'medium_job'
    publishDir "${output_folder}", pattern: 'no_logan_data.csv', mode: 'link', overwrite: true
    conda 'conda-forge::duckdb-cli=1.1.3'

    input:
        val(data_type)
        val(SRA_accessions)
        val(output_folder)
        
    
    output:
        path 'have_logan_data.csv', emit: have_logan_data
        path 'no_logan_data.csv',   emit: no_logan_data

    script:
        def values = SRA_accessions.collect { "('${it}')" }.join(", ")
        def insertStatement = "INSERT INTO SRA_accessions (${data_type}_accessions ) VALUES ${values};"

        """
        cat << EOF > query.sql

        SET threads=${task.cpus};
        SET autoinstall_known_extensions=1;
        SET autoload_known_extensions=1;

        CREATE OR REPLACE TEMP TABLE SRA_accessions (  ${data_type}_accessions VARCHAR );
        ${insertStatement}

        COPY
        (
            SELECT ${data_type}_accessions AS SRA_accession
            FROM read_parquet('${projectDir}/logan_accessions.parquet') AS logan_accessions
            JOIN SRA_accessions USING( ${data_type}_accessions )
        ) TO 'have_logan_data.csv' (FORMAT csv, HEADER true); 

        COPY
        (
            SELECT SRA_accessions.${data_type}_accessions AS SRA_accession
            FROM read_parquet('${projectDir}/logan_accessions.parquet') AS logan_accessions
            RIGHT JOIN SRA_accessions USING( ${data_type}_accessions )
            WHERE logan_accessions.${data_type}_accessions IS NULL
        ) TO 'no_logan_data.csv' (FORMAT csv, HEADER true); 
        EOF

        duckdb < query.sql    
        """
}


process DOWNLOAD_LOGAN_DATA {
    submitRateLimit = '1/2sec'
    maxForks 50
    label 'small_job'
    maxRetries 3
    conda 'conda-forge::awscli=2.17.63' 
    errorStrategy { sleep(Math.pow(2, task.attempt) * 1000 as long); return (task.attempt <= maxRetries) ? 'retry' : 'ignore' }
    publishDir "${output_folder}/${meta_data['SRA_accession']}", mode: 'link', overwrite: true
    tag "${meta_data['SRA_accession']}:${data_type}"
    
    input:
        val(meta_data) 
        val output_folder
        val caching_folder
        
    output:
        tuple val(meta_data), path("*.fa.zst")
        
    script:
        accession = meta_data.SRA_accession
        data_type = meta_data['data_type']

        remote_file = "s3://logan-pub/${data_type[0]}/${accession}/${accession}.${data_type}.fa.zst "
        local_file  = "${accession}_${data_type}.fa.zst"
        temp_local_file = "${local_file}.partial"
        cached_file = caching_folder != '' ? "${caching_folder}/${local_file}" : ""
        temp_cached_file = cached_file != '' ? "${cached_file}.partial" : ""

        if ( cached_file != "" && file(cached_file).exists() )
            """
            cp ${cached_file} ${temp_local_file} && mv ${temp_local_file} ${local_file}
            """
        else if (caching_folder != '')
            """
            download_logan_data.sh ${remote_file} > ${local_file} \
                && mkdir -p ${caching_folder} \
                && cp ${local_file} ${temp_cached_file} \
                && mv ${temp_cached_file} ${cached_file}
            """
        else
            """
            download_logan_data.sh ${remote_file} > ${local_file}
            """
     
        
    stub:
        accession  = meta_data.SRA_accession
        data_type  = meta_data['data_type']
        local_file = "${accession}_${data_type}.fa.zst"

        """
        echo -e ">${accession}.${data_type}\nATCG" | zstd - --stdout > ${local_file}
        """
}

process DOWNLOAD_AND_SIZE_FILTER_LOGAN_DATA {
    submitRateLimit = '1/2sec'
    maxForks 50
    label 'small_job'
    maxRetries 3
    conda 'conda-forge::awscli=2.17.63 bioconda::seqkit=2.8.2 conda-forge::pigz=2.8' 
    errorStrategy { sleep(Math.pow(2, task.attempt) * 1000 as long); return (task.attempt <= maxRetries) ? 'retry' : 'ignore' }
    publishDir "${output_folder}/${meta_data['SRA_accession']}", mode: 'link', overwrite: true, pattern: '*.gz'
    tag "${meta_data['SRA_accession']}:${data_type}"
    
    input:
        val(meta_data)
        val size_threshold 
        val output_folder
        val caching_folder
        
    output:
        tuple val(meta_data), path("*.fa*")
        
    script:
        accession = meta_data.SRA_accession
        data_type = meta_data['data_type']

        remote_file = "s3://logan-pub/${data_type[0]}/${accession}/${accession}.${data_type}.fa.zst "
        local_file = "${accession}_${data_type}-size_filtered_${size_threshold}.fa.gz"
        temp_local_file = "${local_file}.partial"
        cached_file      = caching_folder != '' ? "${caching_folder}/${local_file}" : ""
        temp_cached_file = cached_file != '' ? "${cached_file}.partial" : ""

        if ( cached_file != "" && file(cached_file).exists() )
            """
            cp ${cached_file} ${temp_local_file} \
                && mv ${temp_local_file} ${local_file} \
                && rename_if_empty_gzip.sh ${local_file}
            """
        else if (caching_folder != '')
            """
            download_logan_data.sh ${remote_file} \
                | seqkit seq --threads ${task.cpus} --min-len ${size_threshold} \
                | pigz --best --stdout  > ${local_file} \
                && mkdir -p ${caching_folder} \
                && cp ${local_file} ${temp_cached_file} \
                && mv ${temp_cached_file} ${cached_file} \
                && rename_if_empty_gzip.sh ${local_file}
            """
        else
            """
            download_logan_data.sh ${remote_file} \
                | seqkit seq --threads ${task.cpus} --min-len ${size_threshold} \
                | pigz --best --stdout  > ${local_file} \
                && rename_if_empty_gzip.sh ${local_file}
            """   
        
    stub:
        accession  = meta_data.SRA_accession
        data_type  = meta_data['data_type']
        size_filtered_file = "${accession}_${data_type}-size_filtered_${size_threshold}.fa.gz"

        """
        echo -e ">${accession}.${data_type}\nATCG" | gzip --best > ${size_filtered_file}
        """
}
