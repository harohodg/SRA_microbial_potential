#!/usr/bin/env nextflow

/* 
Nextflow script which runs a set of logan contigs or unitigs through binning, checkm analysis and calculates a global ANI. 
*/


nextflow.enable.dsl=2

params.downloads_file          = 'test_downloads.csv'
params.output_folder           = "LOGAN_SCREEN"
params.data_type               = 'contigs'
params.reference_genomes_cache = ''
params.logan_data_cache        = ''


include { download_logan_data }     from "${projectDir}/workflows/download_logan_data"
include { fetch_reference_genomes } from "${projectDir}/workflows/map_to_reference" 

include { size_filter_contigs }     from "${projectDir}/workflows/size_filter_contigs"
include { bin_contigs as bin_assembly_data } from "${projectDir}/workflows/bin_contigs"

include { checkm2_analysis }                 from "${projectDir}/workflows/checkm2_analysis"
include { calculate_global_ANI }             from "${projectDir}/workflows/calculate_global_ANI"


MIN_CONTIG_LENGTH = 500
ANI_FILTER        = "ANI >= 95"


workflow {
    println "Input parameters : $params"
    assert params.data_type == 'contigs' || params.data_type == 'unitigs' : "${params.data_type} not 'contigs' or 'unitigs'"
    
    input_meta_data = channel.fromPath("${params.downloads_file}").splitCsv(header: true)
        | map { [SRA_accession: it.SRA_accession, reference_accession: it.reference_accession] }
        | unique



    accession_reference_map = input_meta_data
        | unique { meta_data -> tuple(meta_data.SRA_accession, meta_data.reference_accession)}
        | map { meta_data -> tuple(meta_data.SRA_accession, meta_data.reference_accession)}



    accessions_to_download = input_meta_data
        | unique { meta_data -> meta_data.SRA_accession }
        | map { meta_data -> [SRA_accession: meta_data.SRA_accession] }
    
    references_to_download = input_meta_data
        | unique { meta_data -> meta_data.reference_accession }
        | map { meta_data -> [reference_accession: meta_data.reference_accession] }       


    logan_data              = download_logan_data( params.data_type, MIN_CONTIG_LENGTH, accessions_to_download, "${params.output_folder}/LOGAN_DATA-SIZE_FILTERED", params.logan_data_cache )    
    reference_genomes       = fetch_reference_genomes( references_to_download, "${params.output_folder}/REFERENCE_GENOMES", params.reference_genomes_cache )
    
    
    //Add reference genome to each logan dataset
    reference_genomes_map = reference_genomes
        | map{meta_data -> tuple(meta_data.reference_accession, meta_data)}

    
      /*Skani bin the size filtered assembly data
    Starting with SRA_accession, size_filtered_data, data_type
        convert to SRA_accession, reference_accession, reference_genome, size_filtered_data, data_type
    */
    binning_inputs = logan_data 
        | filter { meta_data -> meta_data.size_filtered_assembly.size() != 0 }
        | map {meta_data -> tuple(meta_data.SRA_accession, meta_data)}
        | combine(accession_reference_map, by:0) 
        | map { accession, logan_results, reference_accession -> logan_results +[reference_accession: reference_accession]}
        | map{meta_data -> tuple(meta_data.reference_accession, meta_data)}
        | combine(reference_genomes_map, by:0)
        | map{reference_accession, logan_results, reference_genome -> logan_results + reference_genome} 
        | map { meta_data -> meta_data + ['assembly_label' : "${meta_data.SRA_accession}-${meta_data.reference_accession}-${meta_data.data_type}"] }   


    skani_binned_data = bin_assembly_data(binning_inputs, ANI_FILTER, "${params.output_folder}/BINNED_ASSEMBLIES")
    

    //Finally run the binned assembly data through CheckM
    checkm_inputs  = skani_binned_data
        | filter {meta_data -> meta_data.binned_assembly.size() != 0} 
    checkm_results     = checkm2_analysis( checkm_inputs, "${params.output_folder}/CHECKM_RESULTS" )
    global_ANI_results = calculate_global_ANI( checkm_inputs, "${params.output_folder}/GLOBAL_ANI_RESULTS"  )


}
