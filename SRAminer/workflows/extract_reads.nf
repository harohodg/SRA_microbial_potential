#!/usr/bin/env nextflow

/*
Work flow which extracts a set of SRA accessions

Takes meta-data objects and returns SE and/or PE reads 

Input:
    [
        SRA_accession: str, 
        quality_scores:'full','lite' or 'streamed', 
        prefetched_data: file or '',
        num_chunks: int >= 1,
        chunk_size: int >= 1
    ]
    extraction_format: 'SE', 'PE' or False
    extracted_files_folder: string 


Output :
    [
        SRA_accession: str, 
        quality_scores:'full','lite' or 'streamed', 
        prefetched_data: file or '',
        prefetched_data: file or '',
        num_chunks: int >= 1,
        chunk_size: int >= 1
        extracted_reads: [ [SE_file] or [PE_file1, PE_file2] ... ] or []
    ]
*/

nextflow.enable.dsl=2

include { EXTRACT_SRA_DATASET;  } from "${projectDir}/modules/download_data"

workflow extract_reads {
    take:
        accessions_to_extract //meta data of accessions to extract
        extraction_format     //SE or PE or FALSE, if false returns empty results
        extracted_files_folder //Folder to put the extracted files in
        
    emit:
        extracted_files
        
        
    main:
        if ( extraction_format != false ) {
            slices_to_extract = accessions_to_extract
                | flatMap {meta_data -> (0..meta_data.num_slices-1).collect{ meta_data + [data_slice:it]} }

            extracted_files = EXTRACT_SRA_DATASET( slices_to_extract, extraction_format, extracted_files_folder )
                | map { meta_data, SE_file, PE_files -> meta_data + [extracted_reads: [SE_file, PE_files].findAll{ it.size() != 0 } ]}   
                | map { meta_data -> tuple( groupKey(meta_data.SRA_accession, meta_data.num_slices), meta_data) } 
                | groupTuple()  
                | map { SRA_accession, extracted_reads -> tuple( extracted_reads.sum(), extracted_reads.sum{meta_data -> meta_data.extracted_reads}) }
                | map { meta_data, extracted_reads -> meta_data - [data_slice: meta_data.data_slice] + [extracted_reads: extracted_reads] }
        } else {
            extracted_files = accessions_to_extract
                | map { meta_data -> meta_data + [extracted_reads: [] ]}
        }
}

