#!/usr/bin/env nextflow

/*
Work flow which fetches the number of spots per accession
and calculates the corresponding number of chunks and chunk sizes

Takes meta-data obbjecthe and returns the number of spots 

Input:
    [SRA_accession:str, refererence_accession:str, group: str]
Output :
    [SRA_accession: str, num_spots: #, num_slices: #, spots_per_slice: #]  
*/

def calculate_chunks(num_spots, max_num_chunks, min_chunk_size) {
    proposed_chunk_size = Math.ceil(num_spots / max_num_chunks)
    chunk_size          = proposed_chunk_size >= min_chunk_size ? proposed_chunk_size : min_chunk_size
    num_chunks          = Math.ceil(num_spots / chunk_size)
    return [num_slices: num_chunks.toInteger(), spots_per_slice: chunk_size.toInteger()]
}



nextflow.enable.dsl=2

include { CALCULATE_NUM_SPOTS } from "${projectDir}/modules/download_data"

workflow calculate_num_spots {
    take:
        accessions_to_check
        max_num_chunks
        min_chunk_size 
        
    emit:
        num_spots


    main:

    if ( max_num_chunks == 1 ) {
        num_spots = accessions_to_check
            | map { meta_data -> meta_data + [num_spots: 'unknown', num_slices: 1, spots_per_slice: 0] }
    } else { 
        num_spots = CALCULATE_NUM_SPOTS( accessions_to_check )
            | filter { meta_data, num_spots -> num_spots.size() != 0 }
            | map { meta_data, num_spots -> meta_data + [num_spots: num_spots] + calculate_chunks(num_spots.toInteger(), max_num_chunks, min_chunk_size) }
    }
 
}

