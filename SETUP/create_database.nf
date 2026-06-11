#!/usr/bin/env nextflow

/* 
Nextflow script which extracts NCBI genbank/refseq/viral/SRA database data.
*/


nextflow.enable.dsl=2

params.input_folder  = ""
params.output_folder = ""
params.database_name = ""
params.num_files     = -1

include { EXTRACT_data as EXTRACT_genomic_data }   from "${projectDir}/modules/create_database"

include { EXTRACT_data as EXTRACT_taxonomy_data }  from "${projectDir}/modules/create_database"
include { EXTRACT_data as EXTRACT_SRA_meta_data }  from "${projectDir}/modules/create_database" 
include { EXTRACT_data as EXTRACT_STAT_meta_data } from "${projectDir}/modules/create_database" 
include { EXTRACT_data as EXTRACT_STAT_data }      from "${projectDir}/modules/create_database"

include { CREATE_DATABASE }                        from "${projectDir}/modules/create_database" 




workflow {
    genomic_data = Channel.fromPath( "${params.input_folder}/NCBI_DATA-*/genomic_data-*.jsonl.gz" )
    
    taxonomy_data_files  = Channel.fromPath("${params.input_folder}/TAXONOMY_DATA-*/*",type: 'file').take(params.num_files)
    SRA_meta_data_files  = Channel.fromPath("${params.input_folder}/SRA_META_DATA-*/*",type: 'file').take(params.num_files)
    STAT_meta_data_files = Channel.fromPath("${params.input_folder}/STAT_META_DATA-*/*",type: 'file').take(params.num_files)
    STAT_data_files      = Channel.fromPath("${params.input_folder}/STAT_DATA-*/*",  type: 'file').take(params.num_files)
   
    extracted_genomic_files = EXTRACT_genomic_data( genomic_data, 'genomic_data', 'NCBI_DATA.jsonl.gz' )
    NCBI_extracted_files    = extracted_genomic_files
    
    
    extracted_taxonomy_files       = EXTRACT_taxonomy_data( taxonomy_data_files,   'taxonomy_data',  'PARQUET_FILE')
    extracted_SRA_meta_data_files  = EXTRACT_SRA_meta_data( SRA_meta_data_files,   'SRA_meta_data',  'PARQUET_FILE')
    extracted_STAT_meta_data_files = EXTRACT_STAT_meta_data( STAT_meta_data_files, 'STAT_meta_data', 'PARQUET_FILE')
    extracted_STAT_data_files      = EXTRACT_STAT_data( STAT_data_files,            'STAT_data',     'PARQUET_FILE')
    SRA_extracted_files            = extracted_taxonomy_files.mix( extracted_SRA_meta_data_files ).mix( extracted_STAT_meta_data_files ).mix( extracted_STAT_data_files )
    
    extracted_files = NCBI_extracted_files.mix( SRA_extracted_files ).collect()
    CREATE_DATABASE( extracted_files, params.database_name, params.output_folder )
}

