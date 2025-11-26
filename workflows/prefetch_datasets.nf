#!/usr/bin/env nextflow

/*
Work flow which prefetches SRA datasets

Takes SRA accession meta-data objects and prefetches the associated SRA data files.

Meta-data in:
    [
        SRA_accession:str
    ]
    scores_format: 'lite', 'full', or False   
    prefetched_files_folder: string

Meta-data out:
    [
        SRA_accession:str
        quality_scores:'full','lite' or 'streamed', 
        prefetched_data: file or ''
    ] 
*/


nextflow.enable.dsl=2

include { PREFETCH_SRA_DATASET }   from "${projectDir}/modules/download_data"

workflow prefetch_datasets {
    take:
        accessions_to_prefetch  //meta-data objects
        scores_format           //'lite' or'full'
        prefetched_files_folder
        
    emit:
        prefetched_datasets

        
        
    main: 
        if ( scores_format == 'lite' || scores_format == 'full' ) {    
            prefetched_datasets = PREFETCH_SRA_DATASET( accessions_to_prefetch, scores_format, prefetched_files_folder) 
                | map { meta_data, prefetched_file -> meta_data + [prefetched_data: prefetched_file] }
        } else {
            prefetched_datasets = accessions_to_prefetch
                | map { meta_data -> meta_data + [quality_scores:'streamed', prefetched_data: ''] }
        }
}

