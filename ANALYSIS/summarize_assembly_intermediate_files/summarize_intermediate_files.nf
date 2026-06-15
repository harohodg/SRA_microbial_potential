#!/usr/bin/env nextflow

/* 
Author : Harold Hodgins <hhodgins@uwaterloo.ca>

History :
    Version 0.0.0 : August 16, 2025
        - sufficently stable


Nextflow script which summarizes a set of intermediate files.
*/

include { calculate_file_stats }  from "${projectDir}/workflows"


nextflow.enable.dsl=2

params.input_folder   = ''
params.output_file    = ''


SEARCH_PATTERNS = [
    LOGAN_CACHE           : '**.fa.gz',
    BINNED_ASSEMBLIES     : '**-skani_contigs.fa.gz',
    GENOMES_CACHE         : '**.fna.gz',
    MAPPED_READS          : '**.fasta.gz',
    MEGAHIT_CONTIGS       : '**.contigs.fa',
    SIZE_FILTERED_CONTIGS : '**-size_filtered.fa',
    BINNED_CONTIGS        : '**-skani_contigs.fa'
    ]


META_DATA_MAPS  = [
    LOGAN_CACHE           : { it -> tuple( [SRA_accession : it.name.split('_')[0], data_type : it.name.split('-')[0].split('_')[1] ], it ) },
    BINNED_ASSEMBLIES     : { it -> tuple( [SRA_accession : it.parent.name.split('-')[0], reference_accession: it.parent.name.split('-')[1], data_type: it.parent.name.split('-')[2]], it ) },
    GENOMES_CACHE         : { it -> tuple( [reference_accession : it.name.replace('.fna.gz', '')], it) },
    MAPPED_READS          : { it -> tuple( [SRA_accession : it.parent.name.split('-')[0], reference_accession : it.parent.name.split('-')[1] ], it ) },
    MEGAHIT_CONTIGS       : { it -> tuple( [group_label: it.parent.name.split('-')[0..-2].join('-'), reference_accession: it.parent.name.split('-')[-1] ], it )},
    SIZE_FILTERED_CONTIGS : { it -> tuple( [group_label: it.parent.name.split('-')[0..-2].join('-'), reference_accession: it.parent.name.split('-')[-1] ], it )},
    BINNED_CONTIGS        : { it -> tuple( [group_label: it.parent.name.split('-')[0..-2].join('-'), reference_accession: it.parent.name.split('-')[-1] ], it )}
    ]

DATA_LABELS = [
    LOGAN_CACHE           : 'size_filtered_logan',
    BINNED_ASSEMBLIES     : 'binned_assemblies_logan',
    GENOMES_CACHE         : 'reference',
    MAPPED_READS          : 'mapped_reads',
    MEGAHIT_CONTIGS       : 'megahit_contigs',
    SIZE_FILTERED_CONTIGS : 'size_filtered_pipeline',
    BINNED_CONTIGS        : 'binned_contigs_pipeline'
    ]

assert params.input_folder  != '' 
assert params.output_file   != ''

input_folder = new File(params.input_folder)
data_key     = input_folder.name

search_pattern     = "${params.input_folder}/${SEARCH_PATTERNS[data_key]}"
data_label         = DATA_LABELS[data_key]
output_file        = new File(params.output_file)
output_file_fname  = output_file.name
output_file_folder = output_file.parent == null ? '.' : output_file.parent


workflow {
    println "Input parameters\n${params}"

    calculate_file_stats( search_pattern, META_DATA_MAPS[data_key], data_label)
        | collectFile(name: output_file_fname, newLine: false, keepHeader: true, storeDir: output_file_folder)
}