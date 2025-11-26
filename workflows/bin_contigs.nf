#!/usr/bin/env nextflow

/*
Work flow which bins assembled data using SKANI
Assumes assembled data has already been size filtered

Takes meta-data objects and returns skani filtered results as meta-data objects 

Input:
    For assembly pipeline
    [
        reference_accession : str,
        reference_genome : file,
        group : str,
        assembly_label: str,
        size_filtered_assembly : file
    ]

    For logan screen
    [
        SRA_accession : str, 
        data_type : string,
        reference_accession : str,
        reference_genome : file,
        assembly_label: str,
        size_filtered_assembly : file
    ] 


Output :
    input + [binned_assembly: file]
*/

nextflow.enable.dsl=2

include { SKANI_LABEL_CONTIGS } from "${projectDir}/modules/bin_contigs"
include { FILTER_CONTIG_LABELS as FILTER_SKANI_CONTIG_LABELS } from "${projectDir}/modules/bin_contigs"
include { EXTRACT_CONTIGS as EXTRACT_SKANI_CONTIGS }           from "${projectDir}/modules/bin_contigs"


workflow bin_contigs {
    take:
        size_filtered_data  //assemblies
        ani_filter  //ANI filter for binning, eg "ANI > 95 AND ANI <= 100"
        bins_folder //Where to put the bins
        
    emit:
        skani_binned_data

        
    main:
        skani_labelling_input = size_filtered_data
            | filter { meta_data -> meta_data.size_filtered_assembly.size() != 0 }
            | map { meta_data -> tuple(meta_data, meta_data.size_filtered_assembly, meta_data.reference_genome) }

        skani_labels          = SKANI_LABEL_CONTIGS( skani_labelling_input, bins_folder )
            | branch { failed : it[-1].size() == 0; success : true }

        filtered_skani_labels = FILTER_SKANI_CONTIG_LABELS( skani_labels.success, ani_filter)        
            | branch { failed : it[-1].size() == 0; success : true }
        

        skani_binned_data     = EXTRACT_SKANI_CONTIGS( filtered_skani_labels.success, bins_folder, 'skani_contigs' )
            | map {meta_data, binned_contigs -> meta_data + [binned_assembly: binned_contigs]  }
            | map {meta_data -> meta_data }  
}

