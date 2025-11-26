#!/usr/bin/env nextflow

/*
Work flow which bins assembled data using SKANI

Takes meta-data objects and returns the size filtered and fully filtered results as meta-data objects 

Input:
    For assembly pipeline
    [
        reference_accession : str,
        reference_genome : file, 
        group : str,
        assembly_label : str, 
        data_type : 'contigs',
        assembled_data : file
    ]

    For logan screen
    [
        SRA_accession : str, 
        data_type : string,
        assembly_label : str, 
        assembled_data : file
    ]
Output :
    For assembly pipeline
    [
        reference_accession : str,
        reference_genome : file,
        group : str,
        data_type : str,
        size_filtered_assembly : file
    ]

    For logan screen
    [
        SRA_accession : str, 
        data_type : string,
        size_filtered_assembly : file
    ]   
*/

nextflow.enable.dsl=2

include { SIZE_FILTER_CONTIGS } from "${projectDir}/modules/bin_contigs" 

workflow size_filter_contigs {
    take:
        contigs     //assemblies
        min_contig_length //assembly length threshold
        size_filtered_folder //Where to put the bins
        
    emit:
        size_filtered_contigs

        
    main:
        size_filtered_input   = contigs
            | map { meta_data-> tuple(meta_data, meta_data.assembled_data) }
        
        size_filtered_contigs = SIZE_FILTER_CONTIGS(size_filtered_input, min_contig_length, "${size_filtered_folder}")
            | map {meta_data, filtered_contigs -> meta_data + [size_filtered_assembly: filtered_contigs]}
            | map {meta_data -> meta_data - [assembled_data: meta_data.assembled_data]}
            | map {meta_data -> meta_data - [label: meta_data.label]}
        
}