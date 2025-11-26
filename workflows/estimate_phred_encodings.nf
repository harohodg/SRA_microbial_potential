#!/usr/bin/env nextflow

/*
Work flow which tries to estimate the Phred encoding of each SRA dataset.

Takes meta-data objects and returns the phred encoding per accession as meta-data objects 

Input:
    [SRA_accession:str]
Output :
    [SRA_accession: str, phred_encoding:str, min_phred_score: #, max_phred_score: #] 
*/


nextflow.enable.dsl=2

include { ESTIMATE_PHRED_ENCODING }   from "${projectDir}/modules/download_data"

workflow estimate_phred_encodings {
    take:
        input_meta_data 
        
    emit:
        phred_encodings

        
        
    main:
        accessions_to_check = input_meta_data 
            | unique { meta_data -> meta_data.SRA_accession } //filter out any duplicates (these may have multiple mappings)
            | map { meta_data -> meta_data.SRA_accession }
 

        //Try and estimate the Phred encoding of each data set    
        phred_encodings = ESTIMATE_PHRED_ENCODING( accessions_to_check ) 
            | splitCsv(sep: "\t")
            | map { accession, encoding, min_score, max_score -> [SRA_accession:accession, phred_encoding:encoding, min_phred_score: min_score, max_phred_score: max_score] }
}

