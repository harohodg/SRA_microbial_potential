#!/usr/bin/env nextflow

/* 
Author : Harold Hodgins <hhodgins@uwaterloo.ca>

History :
    Version 0.0.0 : January 22, 2025
        - sufficently stable


Nextflow script which downloads and assembles a set of SRA datasets
using the following steps. Based on previous benchmarking no quality control
steps are included (eg. fastp). Steps in [] are optional

0: The Phred encoding of each accesions is estimated. This information isn't used 
in the analysis and is stored in ${output_folder}/Phred_encodings.tsv

[1:] Accessions are prefetched with full or lite quality scores

[2:] Prefetched data is extracted in SE or PE format. Most SRA datasets
are PE these days but a few olders ones are SE and a few (eg SRR000001) 
are "both". Reads can be extracted in chunks or as a single unit.

3: Reads are mapped to a target reference (currently genbank or refseq) using 
magic blast with splicing turned off and a percent identity threshold. 

4: Mapped reads are grouped by group label and reference genome before being co-assembled 
using Megahit. This can be used to group accession by biosample or any other label. 

5: Megahit contigs are filtered by size removing any sequences under 500bp and labeled using
SKANI to estimate their ANI vs the reference. Contigs which are estimated to have an ANI
of 95% or greater are binned together and passed to Checkm2 to estimate their completeness
and contamination. Binned contigs have their global ANI vs their associated reference calculated.

6: An overall summary of each step and the checkm results is calculated at the end. 
This can be used to determine when/why an accession failed to produced checkm results.



TO DO:
- add option to pass in additional or alternative magic blast parameters
- add option to pass in non RefSeq or Genbank reference, eg a toxin gene 
- support multiple binning thresholds?
- add support for alternative extracted reads compression level?
- add stats for all intermediate files?
*/
include { calculate_num_spots }               from "${projectDir}/workflows/calculate_num_spots"
include { prefetch_datasets }                 from "${projectDir}/workflows/prefetch_datasets"
include { extract_reads }                     from "${projectDir}/workflows/extract_reads"

include { fetch_and_index_reference_genomes } from "${projectDir}/workflows/map_to_reference" 
include { map_to_reference }                  from "${projectDir}/workflows/map_to_reference"   
include { megahit_assembly }                  from "${projectDir}/workflows/megahit_assembly"
include { size_filter_contigs }               from "${projectDir}/workflows/size_filter_contigs"
include { bin_contigs as bin_assembly_data }  from "${projectDir}/workflows/bin_contigs"
include { checkm2_analysis }                  from "${projectDir}/workflows/checkm2_analysis"
include { calculate_global_ANI }              from "${projectDir}/workflows/calculate_global_ANI"

nextflow.enable.dsl=2

params.downloads_file          = 'test_downloads.csv'
params.output_folder           = "SRA_ANALYSIS"
params.reference_genomes_cache = ''
params.prefetch_datasets       = false //or lite or full
params.extract_reads           = false //or SE or PE
params.mapped_reads            = 'SE' //or PE (PE only applies to PE extracted reads)
params.percent_identity_threshold = 95
params.ANI_threshold              = 95
params.max_num_data_slices        = 1
params.min_data_slice_size        = 1000000


assert params.prefetch_datasets in [false, 'lite', 'full'] : "${params.prefetch_data} not one of [false, 'lite', 'full']"
assert params.extract_reads in [false, 'SE', 'PE']         : "${params.extract_reads} not one of 'SE' or 'PE'"
assert params.mapped_reads  in ['SE', 'PE']                : "${params.mapped_reads} not one of 'SE' or 'PE'"

assert "${params.percent_identity_threshold}".isInteger() : "${params.percent_identity_threshold} is not a number"
assert "${params.ANI_threshold}".isInteger()              : "${params.ANI_threshold} is not a number"

assert 0  <= params.percent_identity_threshold && params.percent_identity_threshold <= 100 : "${params.percent_identity_threshold} is not between 0 and 100"
assert 80 <= params.ANI_threshold              && params.ANI_threshold <= 100              : "${params.ANI_threshold} is not between 80 and 100"
assert "${params.max_num_data_slices}".toInteger() >= 1
assert "${params.min_data_slice_size}".toInteger() >= 1


ANI_filter                 = "ANI >= ${params.ANI_threshold}"
percent_identity_threshold = params.percent_identity_threshold
scores_format              = params.prefetch_datasets
max_num_slices             = "${params.max_num_data_slices}".toInteger()
min_slice_size             = "${params.min_data_slice_size}".toInteger()
reads_format               = params.extract_reads 
mapped_reads_format        = params.mapped_reads


MIN_CONTIG_LENGTH = 500
PREFETECHED_FILES_OUTPUT_FOLDER     = "${params.output_folder}/PREFETCHED_FILES"
EXTRACTED_FILES_OUTPUT_FOLDER       = "${params.output_folder}/EXTRACTED_FILES"
REFERENCE_GENOMES_OUTPUT_FOLDER     = "${params.output_folder}/REFERENCE_GENOMES"
MAPPED_READS_OUTPUT_FOLDER          = "${params.output_folder}/MAPPED_READS"
MEGAHIT_CONTIGS_OUTPUT_FOLDER       = "${params.output_folder}/MEGAHIT_CONTIGS"
SIZE_FILTERED_CONTIGS_OUTPUT_FOLDER = "${params.output_folder}/SIZE_FILTERED_CONTIGS"
BINNED_CONTIGS_OUTPUT_FOLDER        = "${params.output_folder}/BINNED_CONTIGS"
CHECKM_OUTPUT_FOLDER                = "${params.output_folder}/CHECKM_RESULTS"
GLOBAL_ANI_OUTPUT_FOLDER            = "${params.output_folder}/GLOBAL_ANI_RESULTS"
SUMMARIZED_RESULTS_FOLDER           = "${params.output_folder}/RESULTS"

workflow {
    println "Input parameters\n${params}"

    //-----------------------------------------Setup-------------------------------------
    //Use the downloads file to setup the initial data structures
    input_meta_data = channel.fromPath("${params.downloads_file}").splitCsv(header: true)
        | map { row -> row.subMap(['SRA_accession', 'reference_accession', 'group']) }
        | unique
    
    

    //Calculate mapping groups
    mapping_groups = input_meta_data
        | map { meta_data -> tuple( meta_data.reference_accession, meta_data.SRA_accession) }
        | unique
        | groupTuple()
        | map {reference_accession, accessions -> [reference_accession: reference_accession, SRA_accessions: accessions] }



    //Calculate assembly groups for the co-assembly step
    assembly_groups = input_meta_data
        | map { meta_data -> tuple(tuple(meta_data.group, meta_data.reference_accession), meta_data.SRA_accession) }
        | unique
        | groupTuple()
        | map { grouping, accessions -> [group_label: "${grouping.join('-')}", group: grouping[0], reference_accession: grouping[1], SRA_accessions: accessions ] }


    //Setup the initial data download/extraction
    all_accessions = input_meta_data
        | map{ meta_data -> meta_data.subMap(['SRA_accession'])}

    unique_accessions = all_accessions
        | unique
    

    //--------------------------------Actual calculations-------------------------------------
    num_spots           = calculate_num_spots(unique_accessions, max_num_slices, min_slice_size)
    prefetched_datasets = prefetch_datasets(num_spots, scores_format, PREFETECHED_FILES_OUTPUT_FOLDER )
    extracted_reads     = extract_reads( prefetched_datasets, reads_format, EXTRACTED_FILES_OUTPUT_FOLDER )
    

    //Fetch and index all reference genomes
    fetched_genomes           = fetch_and_index_reference_genomes( input_meta_data, REFERENCE_GENOMES_OUTPUT_FOLDER, params.reference_genomes_cache )
    reference_genomes         = fetched_genomes.reference_genomes
    indexed_reference_genomes = fetched_genomes.indexed_genomes


    //Map reads to references
    mapped_reads      = map_to_reference(extracted_reads, indexed_reference_genomes, mapping_groups, MAPPED_READS_OUTPUT_FOLDER, mapped_reads_format, percent_identity_threshold)
        | map { meta_data -> meta_data + [reads_to_assemble: meta_data.mapped_reads ]}
    

    //Co-assembly mapped reads using Megahit
    assembled_contigs = megahit_assembly( mapped_reads, assembly_groups, MEGAHIT_CONTIGS_OUTPUT_FOLDER)


    //Size filter the assembled contigs
    size_filtering_input = assembled_contigs 
        | filter { meta_data -> meta_data.assembled_data.size() != 0 }
    size_filtered_assembly_data = size_filter_contigs( size_filtering_input, MIN_CONTIG_LENGTH, SIZE_FILTERED_CONTIGS_OUTPUT_FOLDER )


    //Bin contigs using Skani
    contig_binning_inputs = size_filtered_assembly_data 
        | filter { meta_data -> meta_data.size_filtered_assembly.size() != 0 }
    skani_binned_data     = bin_assembly_data(contig_binning_inputs, ANI_filter, BINNED_CONTIGS_OUTPUT_FOLDER)
    

    //Finally run the binned contigs through CheckM and calculate their global ANI
    checkm_inputs  = skani_binned_data
        | filter {meta_data -> meta_data.binned_assembly.size() != 0}
    checkm_results     = checkm2_analysis( checkm_inputs, CHECKM_OUTPUT_FOLDER )
    global_ANI_results = calculate_global_ANI( checkm_inputs, GLOBAL_ANI_OUTPUT_FOLDER )

}
