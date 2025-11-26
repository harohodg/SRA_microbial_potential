#!/usr/bin/env nextflow

/*
Work flow which attempts to download the logan unitigs or contigs for a set of SRA accessions.

Takes meta-data objects and returns a

Input:
    data_type: str ('unitigs' or 'contigs')
    [SRA_accession:str]
    downloads_folder: str
Output :
    [SRA_accession: str, data_type: str, assembled_data: file] 
*/

nextflow.enable.dsl=2

include { CHECK_LOGAN_ACCESSIONS } from "${projectDir}/modules/download_data"
include { DOWNLOAD_AND_SIZE_FILTER_LOGAN_DATA }    from "${projectDir}/modules/download_data"

workflow download_logan_data {
    take:
        data_type
        size_threshold
        accessions_to_download
        downloads_folder
        caching_folder
        
    emit:
        logan_files
        
        
    main:
        data_types = channel.of( data_type )
        accessions_to_check = accessions_to_download
            | map { it.SRA_accession } | collect

        //Use ${projectDir}/logan_accessions.parquet to check which of these accessions
        //has logan data before we attempt to download them
        checked_accessions = CHECK_LOGAN_ACCESSIONS(data_type, accessions_to_check, downloads_folder)
        
        //Split out the list of accessions to download
        to_download = checked_accessions.have_logan_data
            | splitCsv(header: true) 

        //Setup the actual download
        download_parameters = to_download.combine(data_types)
            | map { meta_data, data_type -> meta_data + [data_type: data_type] }
    
        //And do the actual download
        logan_files = DOWNLOAD_AND_SIZE_FILTER_LOGAN_DATA( download_parameters, size_threshold, downloads_folder, caching_folder )
            | map {meta_data, logan_file -> meta_data + [size_filtered_assembly: logan_file]}
}