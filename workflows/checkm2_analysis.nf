#!/usr/bin/env nextflow

/*
Work flow which estimates assembly completeness and contamination
using Checkm2.


Input:
    [
     reference_accession : str,
     binned_assembly : file, 
     group : str, 
     group_label : str 
    ]

Output :
    [
     reference_accession : str,
     binned_assembly : file, 
     group : str, 
     group_label : str 
    ]
*/

nextflow.enable.dsl=2

include { CHECKM2; FETCH_CHECKM_DATABASE } from "${projectDir}/modules/checkm2_analysis"

workflow checkm2_analysis {
    take:
        assembly_data
        checkm_output_folder
        
    emit:
        checkm_reports

        
    main:
        checkm_database = System.getenv('CHECKM2DB')  ? channel.fromPath( System.getenv('CHECKM2DB') ) : FETCH_CHECKM_DATABASE()

        checkm_input    = assembly_data
            | map {meta_data -> tuple(meta_data, meta_data.binned_assembly)}
            | combine( checkm_database )


        checkm_data     = CHECKM2( checkm_input, checkm_output_folder)
        checkm_reports  = checkm_data.report

}

