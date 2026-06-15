#!/usr/bin/env bash

# Exit the script on any failure
set -e
# Treat failures in a pipeline as an error
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_FOLDER="${SCRIPT_DIR}/../"
GTDB_DATA="${ROOT_FOLDER}/RAW_DATA/GTDB_DATA"
SQL_QUERIES="${SCRIPT_DIR}/SQL_queries/PRIMARY_DATA_TABLES/"

DUCKDB="${ROOT_FOLDER}/bin/duckdb"
source ${SCRIPT_DIR}/data_functions.sh


DATABASE="$1"
OUTPUT_FOLDER="$2"

[[ ! -e "$DATABASE" ]] && { echo "$DATABASE does not appear to be a file" >&2; exit 1; }



#========================== GDTB raw genome counts ================================
output_file="${OUTPUT_FOLDER}/GTDB_raw_genome_counts.parquet"
to_replace="data_table:${GTDB_DATA}/*.gz"
generate_table "RAW GTDB data" "${SQL_QUERIES}/GTDB_raw_genome_counts.sql" "${output_file}" "${to_replace}"


#========================== GenBank raw genome counts ================================
output_file="${OUTPUT_FOLDER}/GenbBank_raw_counts.parquet"
generate_table "RAW GenBank genome data" "${SQL_QUERIES}/GenbBank_raw_counts.sql" "${output_file}"


#========================== merged gtdb/genbank genome data ================================
for target_taxonomy in "Archaea" "Bacteria" "Viruses" "Eukaryota" "UNKNOWN"
do 
    output_file="${OUTPUT_FOLDER}/${target_taxonomy}-merged_GTDB_Genbank_data.parquet"
    to_replace="raw_genbank_data:${OUTPUT_FOLDER}/GenbBank_raw_counts.parquet;raw_gtdb_data:${OUTPUT_FOLDER}/GTDB_raw_genome_counts.parquet;genbank_root_taxonomy:${target_taxonomy}"
    generate_table "Merged GTDB/GenBank ${target_taxonomy} data" "${SQL_QUERIES}/combined_genbank_gtdb_data.sql" "${output_file}" "${to_replace}"
done

#========================== Genome Counts ================================
#Per "species" tax_id how many GenBank/RefSeq genomes are there
#What is the "best" available genome
output_file="${OUTPUT_FOLDER}/genome_counts.parquet"
generate_table 'Genome Counts' " SELECT * FROM LABELED_REFSEQ_GENBANK_COUNTS('species') " "${output_file}"


#========================== Sequencing projects ================================
#For each GenBank/RefSeq accession with a biosample what are the associated "species" tax ids
output_file="${OUTPUT_FOLDER}/sequencing_projects.parquet"
generate_table 'Sequencing projects' " SELECT * FROM SEQUENCING_PROJECTS('species')" "${output_file}"


#========================== SRA meta data ================================
#SRA meta-data with "what was sequenced" root taxonomy labels added
output_file="${OUTPUT_FOLDER}/SRA_meta_data.parquet"
sql_query=$(cat << EOF
WITH meta_data AS
(
    SELECT 
        acc AS SRA_accession,
        experiment,
        bioproject,
        biosample,
        organism AS what_was_sequenced,
        instrument,
        assay_type,
        platform,
        avgspotlen AS average_read_length, 
        CAST( list_filter(attributes, d -> d.k = 'bases')[1].v AS UBIGINT)  AS dataset_size,
        librarysource AS library_source,
        librarylayout AS library_layout
    FROM read_parquet('../RAW_DATA/2025_01_15/SRA_META_DATA-2025_01_15/*')
), labeled_meta_data AS
(
    SELECT
        meta_data.*,

        analyzed_spot_count,
        total_spot_count,

        IFNULL(TAXONOMY_LABELS.ranks, [])                    AS what_was_sequenced_ranks,
        IFNULL(TAXONOMY_LABELS.tax_ids, [])                  AS what_was_sequenced_tax_ids,
        IFNULL(TAXONOMY_LABELS.root_taxonomy_labels, [])     AS what_was_sequenced_root_taxonomy_labels,
    FROM 
        meta_data 
        LEFT JOIN
        TAXONOMY_LABELS
        ON (meta_data.what_was_sequenced = TAXONOMY_LABELS.sci_name)
        LEFT JOIN 
        STAT_meta_data
        ON (meta_data.SRA_accession = STAT_meta_data.accession)
)
SELECT
    SRA_accession,
    COLUMNS(* EXCLUDE (SRA_accession) ) AS 'SRA_\0'
FROM 
    labeled_meta_data
EOF
)
generate_table 'SRA meta-data' "${sql_query}" "${output_file}"


#========================== Root taxonomies and Parent species ================================
#The root taxonomy and parent species of all taxids 
output_file="${OUTPUT_FOLDER}/species_root_taxonomies.parquet"
generate_table 'Species root taxonomies' "${SQL_QUERIES}/parent_species.sql" "${output_file}"


#========================== Summarized STAT data ===============================
#per root taxonomy
for target_taxonomy in "Archaea" "Bacteria" "Viruses" "Eukaryota"
do 
    output_file="${OUTPUT_FOLDER}/${target_taxonomy}-summarized_STAT_data.parquet"
    to_replace="data_folder:${OUTPUT_FOLDER};target_taxonomy:${target_taxonomy}"
    generate_table "Summarized ${target_taxonomy} STAT data" "${SQL_QUERIES}/known_summarized_STAT_data.sql" "${output_file}" "${to_replace}"
done 


#UNKNOWN root taxonomies 
output_file="${OUTPUT_FOLDER}/UNKNOWN-summarized_STAT_data.parquet"
generate_table "Summarized UNKNOWN STAT data" "${SQL_QUERIES}/unknown_summarized_STAT_data.sql" "${output_file}"


#========================== Finally the actual search tables ================================
for target_taxonomy in "Archaea" "Bacteria" "Viruses" "Eukaryota" "UNKNOWN"
do 
    output_file="${OUTPUT_FOLDER}/${target_taxonomy}-search_table.parquet"
    to_replace="data_folder:${OUTPUT_FOLDER};target_taxonomy:${target_taxonomy};genbank_gtdb_data_table:${OUTPUT_FOLDER}/${target_taxonomy}-merged_GTDB_Genbank_data.parquet"
    generate_table "${target_taxonomy} Search table" "${SQL_QUERIES}/search_table.sql" "${output_file}" "${to_replace}"
done 

