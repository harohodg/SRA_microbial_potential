#!/usr/bin/env nextflow

/*
Work flow which calculates the global ANI for a set of contigs
and a given references

Takes meta-data objects and returns the global ANI as meta-data objects 

Input:
    For assembly pipeline
    [
     reference_accession : str,
     reference_genome : file,
     group : str,
     assembly_label: str,
     binned_assembly : file
    ]

    For logan screen
    [
     SRA_accession : str, 
     data_type : string,
     assembly_label: str,
     reference_accession : str,
     reference_genome : file,
     binned_assembly : file
    ] 


Output :
    input + [global_ANI:str]
*/

nextflow.enable.dsl=2

include { GLOBAL_ANI } from "${projectDir}/modules/calculate_global_ANI"

workflow calculate_global_ANI {
    take:
        binned_assemblies  //assemblies
        results_folder //Where to put the bins
        
    emit:
        global_ANI_results

        
    main:
        global_ANI_input = binned_assemblies
            | filter { meta_data -> meta_data.binned_assembly.size() != 0 }
            | map { meta_data -> tuple(meta_data, meta_data.binned_assembly, meta_data.reference_genome) }

        global_ANI_results = GLOBAL_ANI( global_ANI_input, results_folder )
            | filter { meta_data, global_ANI, output_file -> global_ANI.length() != 0 && output_file.size() != 0 }
            | map { meta_data, global_ANI, output_file -> meta_data + [global_ANI: global_ANI] } 
}

