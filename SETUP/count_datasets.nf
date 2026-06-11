#!/usr/bin/env nextflow

/* 
Nextflow script which filters NCBI genbank/refseq/viral database taxonomic coverage data
based on SRA dataset size, predicted number of reads, and taxonomic rank.
*/


nextflow.enable.dsl=2

params.extracted_database        = ""
params.SRA_size_threshold        = '1000'
params.genome_coverage_threshold = '1 10 100 1000'
params.output_folder             = ""

include { COUNT_SRA_DATASETS; COUNT_NCBI_DATASETS } from "${projectDir}/modules/count_datasets"
include { MERGE_ALL_COUNTS; MERGE_NCBI_SRA_COUNTS } from "${projectDir}/modules/count_datasets"

workflow {
    SRA_size_thresholds        = Channel.fromList( "${params.SRA_size_threshold}".tokenize(' ') )
    genome_coverage_thresholds = Channel.fromList( "${params.genome_coverage_threshold}".tokenize(' ') )
    extracted_database         = Channel.fromPath("${params.extracted_database}",type: 'file')

    filtering_parameters = extracted_database.combine( SRA_size_thresholds ).combine( genome_coverage_thresholds )

    NCBI_COUNTS = COUNT_NCBI_DATASETS( extracted_database, "${params.output_folder}" )
    SRA_counts  = COUNT_SRA_DATASETS( filtering_parameters, "${params.output_folder}" )
    
    to_merge = NCBI_COUNTS.mix( SRA_counts ).collect()
    MERGE_ALL_COUNTS( to_merge, "${params.output_folder}" )
    
    to_combine = NCBI_COUNTS.combine( SRA_counts )
    MERGE_NCBI_SRA_COUNTS( to_combine, "${params.output_folder}" ) 
}

