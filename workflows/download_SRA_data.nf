#!/usr/bin/env nextflow

/*
Work flow which downloads and extracts a set of SRA accessions

Takes meta-data objects and returns SE and/or PE reads 

Input:
    [
     SRA_accession : str
    ]



Output :
    [
     SRA_accession : str
     SE_reads      : [] or [file1]
     PE_reads      : [] or [file1,file2]
    ]
*/

nextflow.enable.dsl=2

include { PREFETCH_SRA_DATASETS; EXTRACT_SRA_DATASETS;  } from "${projectDir}/modules/download_data"

workflow download_SRA_data {
    take:
        accessions_to_download //meta data of accessions to download
        extracted_files_folder //Folder to put the extracted files in
        download_parameters    //parameters to use with prefetch
        extraction_parameters  //parameters to use with fasterq-dump
        
    emit:
        extracted_files
        
        
    main:
        unique_accessions = accessions_to_download 
            | unique { meta_data -> meta_data.SRA_accession } 
            | map { meta_data -> [SRA_accession: meta_data.SRA_accession] }   
        
        prefetched_files    = PREFETCH_SRA_DATASETS( unique_accessions, download_parameters ) 
            | map {meta_data, prefetched_file -> tuple( meta_data + [prefetched_file : prefetched_file], prefetched_file) }
  
        extracted_files    = EXTRACT_SRA_DATASETS( prefetched_files, extracted_files_folder, extraction_parameters )
            | map { meta_data, SE_file, PE_files -> meta_data + [extracted_reads: [SE_file, PE_files].findAll{ it.size() != 0 } ]}   
}

