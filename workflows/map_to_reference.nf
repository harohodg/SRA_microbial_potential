#!/usr/bin/env nextflow

nextflow.enable.dsl=2

include { DOWNLOAD_REFERENCE_GENOME }          from "${projectDir}/modules/download_data"
include { INDEX_REFERENCE }                    from "${projectDir}/modules/map_to_reference"
include { MAP_TO_REFERENCE_AND_EXTRACT_READS } from "${projectDir}/modules/map_to_reference"


/*
Workflow which tries to fetch RefSeq or GenBank reference genomes

Input:
    [reference_accession:str, ...]
Output:
    [reference_accession:str, reference_genome:file]
*/
workflow fetch_reference_genomes {
    take:
        input_meta_data
        output_folder
        caching_folder
        
    emit:
        reference_genomes

    main:
        reference_accessions = input_meta_data
            | unique { meta_data -> meta_data.reference_accession }
            | map { meta_data -> meta_data.reference_accession }

        reference_genomes    = DOWNLOAD_REFERENCE_GENOME( reference_accessions, output_folder, caching_folder )
            | map{ reference_accession, reference_genome -> [reference_accession: reference_accession, reference_genome: reference_genome] }                   
}


/*
Workflow which Blast indexes downloaded RefSeq/GenBank genomes

Input:
    [reference_accession:str, reference_genome:file]
Output:
    [reference_accession:str, reference_genome:file, indexed_genome:[files]]
*/
workflow index_reference_genomes {
    take:
        reference_genomes
        
    emit:
        indexed_genomes

    main:
        to_index = reference_genomes
            | unique { meta_data -> tuple(meta_data.reference_accession, meta_data.reference_genome)  }
            | map { meta_data -> tuple(meta_data.reference_accession, meta_data.reference_genome) }

        indexed_genomes = INDEX_REFERENCE( reference_genomes )
            | map{ reference_accession, reference_genome, indexed_genome_files -> [reference_accession: reference_accession, reference_genome: reference_genome, indexed_genome: indexed_genome_files] }                   
}


/*
Workflow which which tries to fetch RefSeq or GenBank reference genomes 
and then create Blast indexes

Input:
    [reference_accession:str, ...]
Output:
    [reference_accession:str, reference_genome:file, indexed_genome:[files]]
*/
workflow fetch_and_index_reference_genomes {
    take:
        input_meta_data
        output_folder
        caching_folder
        
    emit:
        reference_genomes
        indexed_genomes

    main:    
        reference_genomes = fetch_reference_genomes( input_meta_data, output_folder, caching_folder )
        indexed_genomes   = index_reference_genomes( reference_genomes )      
}



/*
Workflow which maps SRA accessions to indexed reference genomes

Input:
    [
        SRA_accession: str, 
        quality_scores:'full','lite' or 'streamed', 
        prefetched_data: file or '',
        prefetched_data: file or '',
        num_chunks: int >= 1,
        chunk_size: int >= 1
        extracted_reads: [ [SE_file] or [PE_file1, PE_file2] ... ] or []
    ]
    [
        reference_accession: string,
        reference_genome: file,
        indexed_genome: [file1, file2, file3 ...]
    ]
    [
        reference_accession: string, 
        SRA_accessions:[string,string, ...]
    ]
    output_folder: string
    mapped_reads_format : 1 or 2
    percent_identity_threshold : 0 - 100

Output:
    [
     SRA_accession : str, 
     reference_accession : str, 
     reference_genome : file, 
     mapped_reads : [] or [ [file(s)] ... ]
     mapping_input_stats: string
    ]
*/
workflow map_to_reference {
    take:
        to_map            //meta data for each accession to map to a reference
        reference_genomes //the reference genomes
        mapping_groups    //which accessions are mapped to which reference
        output_folder       //where to save a copy of the mapped reads
        mapped_reads_format //SE or PE       //1 for SE, 2 for PE if PE input otherwise SE output
        percent_identity_threshold //what threshold should we apply to the read maps
    emit:
        mapped_reads

    main:
        num_mapped_reads_out = mapped_reads_format == 'SE' ? 1 : 2

        //Merge the reference_genomes and accessions to map based
        //on the mapping groups    
        reference_genomes_with_groups = mapping_groups
            | cross( reference_genomes ) { meta_data -> meta_data.reference_accession }
            | flatMap { mapping, reference_genome -> mapping.SRA_accessions.collect{ accession -> tuple(accession, reference_genome) } }


        //reorder accessions to be mapped so they can be merged with reference genomes
        accessions_to_map = to_map
            | map { meta_data -> tuple( meta_data.SRA_accession, meta_data) }

        merged_data = accessions_to_map 
            | combine(reference_genomes_with_groups, by: 0 )
            | map { accession, meta_data, reference_genome -> tuple(meta_data, reference_genome) }
            | branch { meta_data, reference_genome -> 
                extracted_reads: meta_data.extracted_reads.size() != 0
                streamed_reads: true
             }       


             
        accessions_to_stream_reads = merged_data.streamed_reads
                | flatMap {meta_data, reference_genome -> (0..meta_data.num_slices-1).collect{ tuple(meta_data + [data_slice: it, mapping_group_size: meta_data.num_slices], reference_genome) } }
                | map {meta_data, reference_genome -> tuple(meta_data + [reference_accession: reference_genome.reference_accession, reference_genome: reference_genome.reference_genome], reference_genome)}
                | map {meta_data, reference_genome -> tuple(meta_data, reference_genome.indexed_genome) }
        
        
        accessions_to_map_reads    = merged_data.extracted_reads
            | map { meta_data, reference_genome -> tuple(meta_data + [ mapping_group_size: meta_data.extracted_reads.size() ], reference_genome) }
            | flatMap { meta_data, reference_genome -> meta_data.extracted_reads.collect{ reads -> tuple(meta_data + [extracted_reads: reads], reference_genome) } }
            | map {meta_data, reference_genome -> tuple(meta_data + [reference_accession: reference_genome.reference_accession, reference_genome: reference_genome.reference_genome], reference_genome)}
            | map {meta_data, reference_genome -> tuple(meta_data, reference_genome.indexed_genome) }   

        mapping_input = accessions_to_stream_reads.mix( accessions_to_map_reads )
        
        mapped_reads = MAP_TO_REFERENCE_AND_EXTRACT_READS(mapping_input, num_mapped_reads_out, output_folder, percent_identity_threshold)
            | map { meta_data, mapped_to_reference -> tuple( groupKey( "${meta_data.SRA_accession}-${meta_data.reference_accession}", meta_data.mapping_group_size), meta_data + [mapped_reads: mapped_to_reference]) } 
            | groupTuple() 
            | map { grouping, grouped_meta_data ->  grouped_meta_data.sum() + [mapped_reads: grouped_meta_data.collect{meta_data -> meta_data.mapped_reads}] }
            | map { meta_data -> meta_data + [mapped_reads: meta_data.mapped_reads.findAll{ it[0].size() != 0 }]}
            | map { meta_data -> meta_data.subMap(['SRA_accession', 'reference_accession', 'reference_genome', 'mapped_reads']) }
        }