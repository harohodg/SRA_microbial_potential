#!/usr/bin/env nextflow

/* 
Nextflow script which downloads the latest SRA and NCBI datasets summaries.
*/


nextflow.enable.dsl=2

def today = new Date().format( 'yyyy_MM_dd' )

params.output_folder = "RAW_DATA/${today}"


include { LIST_SRA_FILES as LIST_USER_META_DATA_FILES }      from "${projectDir}/modules/download_data" 
include { LIST_SRA_FILES as LIST_STAT_RESULTS_FILES }        from "${projectDir}/modules/download_data"
include { LIST_SRA_FILES as LIST_STAT_META_DATA_FILES }      from "${projectDir}/modules/download_data"
include { LIST_SRA_FILES as LIST_TAXONOMY_DATA_FILES }       from "${projectDir}/modules/download_data"

include { DOWNLOAD_SRA_DATA as DOWNLOAD_USER_META_DATA }     from "${projectDir}/modules/download_data"  
include { DOWNLOAD_SRA_DATA as DOWNLOAD_STAT_RESULTS }       from "${projectDir}/modules/download_data" 
include { DOWNLOAD_SRA_DATA as DOWNLOAD_STAT_META_DATA }     from "${projectDir}/modules/download_data" 
include { DOWNLOAD_SRA_DATA as DOWNLOAD_TAXONOMY_DATA }      from "${projectDir}/modules/download_data"

include { DOWNLOAD_NCBI_DATA as DOWNLOAD_NCBI_GENOMIC_DATA } from "${projectDir}/modules/download_data" 
//include { DOWNLOAD_NCBI_DATA as DOWNLOAD_NCBI_VIRAL_DATA }   from "${projectDir}/modules/download_data"   


META_DATA_AWS_FOLDER = 'sra/metadata'
STAT_DATA_AWS_FOLDER = 'sra_tax_analysis_tool/tax_analysis'
STAT_META_DATA_AWS_FOLDER = 'sra_tax_analysis_tool/tax_analysis_info'
TAXONOMY_DATA_AWS_FOLDER  = 'sra_tax_analysis_tool/taxonomy'

GENOMIC_DOWNLOAD_FLAGS = 'genome taxon "1" --as-json-lines --assembly-source all --exclude-atypical --limit all --mag all --report genome'
VIRAL_DOWNLOAD_FLAGS   = 'virus genome taxon "viruses" --as-json-lines --limit all --report virus'

meta_data_folder = "${params.output_folder}/SRA_META_DATA-${today}"
stat_data_folder = "${params.output_folder}/STAT_DATA-${today}" 
stat_meta_data_folder = "${params.output_folder}/STAT_META_DATA-${today}"
taxonomy_data_folder  = "${params.output_folder}/TAXONOMY_DATA-${today}"
ncbi_data_folder      =  "${params.output_folder}/NCBI_DATA-${today}"
genomic_data_file     = "genomic_data-${today}.jsonl.gz"
viral_data_file       = "viral_data-${today}.jsonl.gz"

meta_data_label       = 'SRA_META_DATA'
stat_data_label       = 'STAT_DATA'
stat_meta_data_label  = 'STAT_META_DATA'
taxonomy_data_label   = 'TAXONOMY_DATA'


workflow {
    meta_data_files      = LIST_USER_META_DATA_FILES( META_DATA_AWS_FOLDER ).splitCsv() | map { it[0] }
    stat_results_files   = LIST_STAT_RESULTS_FILES( STAT_DATA_AWS_FOLDER ).splitCsv()   | map { it[0] }
    stat_meta_data_files = LIST_STAT_META_DATA_FILES( STAT_META_DATA_AWS_FOLDER ).splitCsv() | map { it[0] }
    taxonomy_data_files  = LIST_TAXONOMY_DATA_FILES( TAXONOMY_DATA_AWS_FOLDER ).splitCsv()   | map { it[0] }

    DOWNLOAD_USER_META_DATA( meta_data_files, meta_data_folder, meta_data_label )
    DOWNLOAD_STAT_RESULTS( stat_results_files, stat_data_folder, stat_data_label)
    DOWNLOAD_STAT_META_DATA( stat_meta_data_files, stat_meta_data_folder, stat_meta_data_label )
    DOWNLOAD_TAXONOMY_DATA( taxonomy_data_files, taxonomy_data_folder, taxonomy_data_label )
    
    DOWNLOAD_NCBI_GENOMIC_DATA( GENOMIC_DOWNLOAD_FLAGS, ncbi_data_folder, genomic_data_file)
   //DOWNLOAD_NCBI_VIRAL_DATA( VIRAL_DOWNLOAD_FLAGS,     ncbi_data_folder, viral_data_file)
}

