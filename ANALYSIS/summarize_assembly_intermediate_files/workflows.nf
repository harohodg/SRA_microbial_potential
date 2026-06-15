#!/usr/bin/env nextflow

/*
Work flow which calculates the intermediate file stats
and merges stats from files with the same grouping.

Takes 
    a path regex
    a file to meta-data mapping
    a label to add to each of the stats
Returns 
    a file with all the stats for each file with files with the same meta-data merged
*/

nextflow.enable.dsl=2

include { FILE_STATS }            from "${projectDir}/modules"
include { SUMMARIZE_FILE_STATS }  from "${projectDir}/modules"
include { RELABEL_STATS_COLUMNS } from "${projectDir}/modules"
include { COMBINE_FILE_STATS }    from "${projectDir}/modules"

LABEL_SEPARATOR = '_'

workflow calculate_file_stats {
    take:
        path_regex
        meta_data_map
        stats_label
        
    emit:
        all_file_stats


    main:
        files_to_stat = channel.fromPath( path_regex )
            |  map ( meta_data_map ) //extract meta-data from filename
            | groupTuple() 
            | flatMap { meta_data, files -> files.collect{ f -> tuple( meta_data + [num_files : files.size() ], f) } } //Add num files

        file_stats            = FILE_STATS( files_to_stat ) 
        individual_file_stats = file_stats.filter{ meta_data, stats -> meta_data.num_files == 1 }
        file_stats_to_merge   = file_stats.filter{ meta_data, stats -> meta_data.num_files != 1 }
            | map { meta_data, stats -> tuple(groupKey(meta_data, meta_data.num_files), stats) }
            | groupTuple()

        merged_stats = SUMMARIZE_FILE_STATS( file_stats_to_merge )  

        stats_to_relabel = individual_file_stats.mix( merged_stats )
            | map { meta_data, stats -> tuple( meta_data - [num_files: meta_data.num_files] + [ "${stats_label}_num_files" : meta_data.num_files], stats_label, stats) }

        relabeled_stats = RELABEL_STATS_COLUMNS(stats_to_relabel).collect() 


        all_file_stats = COMBINE_FILE_STATS( relabeled_stats ) 
}

