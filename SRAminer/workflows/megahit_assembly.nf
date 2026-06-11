#!/usr/bin/env nextflow

/*
Work flow which combines mapped reads by group label and coassembles them.


Input:
    [
         SRA_accession : str, 
         reference_accession : str,
         reference_genome : file, 
         reads_to_assemble : [[file1]] or [[file1,file2]] or [[file1],[file1,file2]], 
    ]
    [
        group_label: string,
        group: string,
        reference_accession: string,
        SRA_accessions: [string, string, ...]
    ]
    megahit_output_folder: string

Output :
    [
     reference_accession : str,
     reference_genome : file, 
     group : str,
     group_label : str, 
     assembled_data : file
    ]
*/


nextflow.enable.dsl=2

include { MEGAHIT } from "${projectDir}/modules/megahit_assembly"


workflow megahit_assembly {
    take:
        to_assemble
        assembly_groups                 
        megahit_output_folder
        
    emit:
        megahit_contigs
        
    main:
        //megahit_contigs = channel.empty()


        //Add group size and group label to each accession
        accession_group_labels  = assembly_groups 
            | flatMap { grouping -> grouping.SRA_accessions.collect{ accession -> tuple( tuple(accession, grouping.reference_accession), grouping.subMap(['group_label', 'group', 'reference_accession']) + [group_size: grouping.SRA_accessions.size()] )}}
 
        assembly_inputs = to_assemble
            | map { meta_data -> tuple( tuple(meta_data.SRA_accession, meta_data.reference_accession), meta_data) }
            | combine(accession_group_labels, by: 0 )
            | map { grouping, data_to_assemble, group_info -> tuple( groupKey(group_info.group_label, group_info.group_size), data_to_assemble + group_info) }
            | groupTuple()
            | map { grouping, grouped_meta_data -> grouped_meta_data.sum() + [assembly_label: "${grouping}", reads_to_assemble: grouped_meta_data.collect{meta_data -> meta_data.reads_to_assemble}.sum() ]}
            | map { meta_data -> tuple( meta_data.subMap(['group_label', 'group', 'reference_accession', 'reference_genome', 'assembly_label']), meta_data.reads_to_assemble.sort() ) }
            | filter {meta_data, reads_to_assemble -> reads_to_assemble.size() != 0 }

        megahit_contigs  = MEGAHIT( assembly_inputs, megahit_output_folder ).contigs
            | map { meta_data, assembled_contigs -> meta_data.subMap(['group_label', 'group', 'reference_accession', 'reference_genome', 'assembly_label']) + [assembled_data: assembled_contigs, data_type: 'contigs'] } 

}
