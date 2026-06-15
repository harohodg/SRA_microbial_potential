#!/usr/bin/env bash

# Exit the script on any failure
set -e
# Treat failures in a pipeline as an error
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_FOLDER="${SCRIPT_DIR}/../"
SQL_QUERIES="${SCRIPT_DIR}/SQL_queries/ASSEMBLY_RESULTS/"
CACHED_FILES_ROOT="${ROOT_FOLDER}/../SRAminer_DATA_CACHE/"

SINGLETONS_INPUT_ROOT="${ROOT_FOLDER}/SINGLETON_TAXIDS_ANALYSIS/"
TOP_N_INPUT_ROOT="${ROOT_FOLDER}/TOP_N_ANALYSIS"
TARANTELLAE_INPUT_ROOT="${ROOT_FOLDER}/TARANTELLAE_ANALYSIS"

NEXTFLOW_SCRATCH="/scratch/nextflow_scratch"
NEXTFLOW_SETUP="NXF_OPTS='-Xms1g -Xmx4g' NXF_WORK='${NEXTFLOW_SCRATCH}' NFX_TEMP='${NEXTFLOW_SCRATCH}'"

DUCKDB="${ROOT_FOLDER}/bin/duckdb"
source ${SCRIPT_DIR}/data_functions.sh


#Script inputs
DATABASE="$1"
PRIMARY_DATA_TABLES_FOLDER="$2"
OUTPUT_FOLDER="$3"

[[ ! -e "$DATABASE" ]] && { echo "$DATABASE does not appear to be a file" >&2; exit 1; }
MERGED_GENBANK_GTDB_DATA="${PRIMARY_DATA_TABLES_FOLDER}/*-merged_GTDB_Genbank_data.parquet"
SEQUENCING_PROJECTS="${PRIMARY_DATA_TABLES_FOLDER}/sequencing_projects.parquet"

SINGLETONS_OUTPUT_ROOT="${OUTPUT_FOLDER}/RANDOM_SINGLETONS"
TOP_N_OUTPUT_ROOT="${OUTPUT_FOLDER}/TOP_N_SINGLETONS"
TARANTELLAE_OUTPUT_ROOT="${OUTPUT_FOLDER}/TARANTELLAE_ANALYSIS"


##########################################################################################################################################
echo '----------------------------------'
echo '---------Pipeline inputs----------'
echo '----------------------------------'
current_sql_file="${SQL_QUERIES}/copy_pipeline_input.sql" 

# Start by making the necessary output folders and copying over the associated pipeline inputs

## Random Archaea/Bacteria singletons
current_input_root="${SINGLETONS_INPUT_ROOT}"
current_base_output_root="${SINGLETONS_OUTPUT_ROOT}"
columns_to_keep='SRA_accession, reference_accession, \"group\" AS group_label'
data_filter="ends_with(group_label, '_assembly')" #Ignoring co-assemblies
for folder_name in $(find  ${current_input_root} -type d -name 'BATCH*' -printf '%P\n')
do
    current_output_folder="${current_base_output_root}/${folder_name}"
    mkdir -p "${current_output_folder}"

    input_file="${current_input_root}/${folder_name}/../$(basename ${folder_name} | tr '[:upper:]' '[:lower:]' | tr -d '_' )_accessions.csv"
    output_file="${current_output_folder}/random_singletons-$(echo $folder_name |  tr '[:upper:]' '[:lower:]' | tr '/' '-' )-pipeline_input.tsv"
    to_replace="input_file:${input_file};columns_to_keep:${columns_to_keep};data_filter:${data_filter}"
    generate_table "${folder_name} pipeline inputs" "${current_sql_file}" "${output_file}" "${to_replace}"
done


## Bacterial singletons with >= 1000X coverage
current_input_root="${TOP_N_INPUT_ROOT}"
current_output_folder="${TOP_N_OUTPUT_ROOT}/BACTERIA/BATCH_01"
mkdir -p "${current_output_folder}"

input_file="${current_input_root}/top_n-accessions.csv"
output_file="${current_output_folder}/top_n_singletons-bacteria-batch_01-pipeline_input.tsv"
to_replace="input_file:${input_file};columns_to_keep:${columns_to_keep};data_filter:${data_filter}"
generate_table "TOP N pipeline inputs" "${current_sql_file}" "${output_file}" "${to_replace}"


## Tarantellae
current_input_root="${TARANTELLAE_INPUT_ROOT}"
current_output_folder="${TARANTELLAE_OUTPUT_ROOT}/BACTERIA/BATCH_00"
mkdir -p "${current_output_folder}"

input_file="${current_input_root}/C_tarantellae-accessions.csv"
output_file="${current_output_folder}/C_tarantellae-pipeline_input.tsv"
to_replace="input_file:${input_file};columns_to_keep:${columns_to_keep};data_filter:${data_filter}"
generate_table "Tarantellae" "${current_sql_file}" "${output_file}" "${to_replace}"



##########################################################################################################################################
echo '----------------------------------'
echo '---------SRA meta-data------------'
echo '----------------------------------'
current_sql_file="${SQL_QUERIES}/extract_SRA_meta_data.sql" 

for input_file in $(find ${OUTPUT_FOLDER} -type f -name '*-pipeline_input.tsv')
do
    base_input_file=$(basename ${input_file%-pipeline_input.tsv})
    base_input_folder=$(dirname ${input_file} )

    output_file="${base_input_folder}/PARTIAL_DATA_FILES/${base_input_file}-SRA_meta_data.parquet"
    to_replace="input_file:${input_file};SRA_meta_data:${PRIMARY_DATA_TABLES_FOLDER}/SRA_meta_data.parquet"
    generate_table "${base_input_file} SRA meta-data" "${current_sql_file}" "${output_file}" "${to_replace}"
done


##########################################################################################################################################
echo '----------------------------------------------------'
echo '------------Reference genomes meta-data-------------'
echo '----------------------------------------------------'
current_sql_file="${SQL_QUERIES}/extract_reference_genomes_meta_data.sql" 

for input_file in $(find ${OUTPUT_FOLDER} -type f -name '*-pipeline_input.tsv')
do
    base_input_file=$(basename ${input_file%-pipeline_input.tsv})
    base_input_folder=$(dirname ${input_file} )

    output_file="${base_input_folder}/PARTIAL_DATA_FILES/${base_input_file}-reference_genomes_meta_data.parquet"
    to_replace="input_file:${input_file};gtdb_data:${MERGED_GENBANK_GTDB_DATA}"
    generate_table "${base_input_file} Reference Genome meta-data" "${current_sql_file}" "${output_file}" "${to_replace}"
done


##########################################################################################################################################
echo '----------------------------------'
echo '------------STAT data-------------'
echo '----------------------------------'
current_sql_file="${SQL_QUERIES}/extract_STAT_data.sql" 

for input_file in $(find ${OUTPUT_FOLDER} -type f -name '*-pipeline_input.tsv')
do
    base_input_file=$(basename ${input_file%-pipeline_input.tsv})
    base_input_folder=$(dirname ${input_file} )


    pipeline_input_file="${input_file}"
    reference_genomes_meta_data="${base_input_folder}/PARTIAL_DATA_FILES/${base_input_file}-reference_genomes_meta_data.parquet"
    STAT_data="${PRIMARY_DATA_TABLES_FOLDER}/*-summarized_STAT_data.parquet"

    output_file="${base_input_folder}/PARTIAL_DATA_FILES/${base_input_file}-STAT_data.parquet"
    to_replace="pipeline_input_file:${pipeline_input_file};reference_genomes_meta_data:${reference_genomes_meta_data};STAT_data:${STAT_data}"
    generate_table "${base_input_file} STAT data" "${current_sql_file}" "${output_file}" "${to_replace}"
done


##########################################################################################################################################
echo '----------------------------------'
echo '---------Checkm Results-----------'
echo '----------------------------------'
current_sql_file="${SQL_QUERIES}/extract_checkm_results.sql" 

## Random Archaea/Bacteria singletons
intermediate_columns_to_keep='reference_accession, \"group\" AS group_label'
columns_to_keep="reference_accession, group_label"

current_input_root="${SINGLETONS_INPUT_ROOT}"
current_base_output_root="${SINGLETONS_OUTPUT_ROOT}"
for folder_name in $(find  ${current_input_root} -type d -name 'BATCH*' -printf '%P\n')
do
    current_output_folder="${current_base_output_root}/${folder_name}"
    input_file="$(ls ${current_output_folder}/*-pipeline_input.tsv)"
    base_input_file=$(basename ${input_file%-pipeline_input.tsv})


    data_files="${current_input_root}/${folder_name}/CHECKM_RESULTS/*/*-checkm_report.tsv"
    output_file="${current_output_folder}/PARTIAL_DATA_FILES/${base_input_file}-checkm_results.tsv"
    to_replace="data_files:${data_files};intermediate_columns_to_keep:${intermediate_columns_to_keep};columns_to_keep:${columns_to_keep}"
    generate_table "${folder_name} checkm results" "${current_sql_file}" "${output_file}" "${to_replace}"
done


## Bacterial singletons with >= 1000X coverage
current_input_root="${TOP_N_INPUT_ROOT}"
current_output_folder="${TOP_N_OUTPUT_ROOT}/BACTERIA/BATCH_01"
input_file="$(ls ${current_output_folder}/*-pipeline_input.tsv)"
base_input_file=$(basename ${input_file%-pipeline_input.tsv})

data_files="${current_input_root}/CHECKM_RESULTS/*/*-checkm_report.tsv"
output_file="${current_output_folder}/PARTIAL_DATA_FILES/${base_input_file}-checkm_results.tsv"
to_replace="data_files:${data_files};intermediate_columns_to_keep:${intermediate_columns_to_keep};columns_to_keep:${columns_to_keep}"
generate_table "TOP N checkm results" "${current_sql_file}" "${output_file}" "${to_replace}"


## Tarantellae
current_input_root="${TARANTELLAE_INPUT_ROOT}"
current_output_folder="${TARANTELLAE_OUTPUT_ROOT}/BACTERIA/BATCH_00"
input_file="$(ls ${current_output_folder}/*-pipeline_input.tsv)"
base_input_file=$(basename ${input_file%-pipeline_input.tsv})

data_files="${current_input_root}/CHECKM_RESULTS/*/*-checkm_report.tsv"
output_file="${current_output_folder}/PARTIAL_DATA_FILES/${base_input_file}-checkm_results.tsv"
to_replace="data_files:${data_files};intermediate_columns_to_keep:${intermediate_columns_to_keep};columns_to_keep:${columns_to_keep}"
generate_table "Tarantellae checkm results" "${current_sql_file}" "${output_file}" "${to_replace}"




##########################################################################################################################################
echo '--------------------------------------'
echo '---------Global ANI Results-----------'
echo '--------------------------------------'
current_sql_file="${SQL_QUERIES}/extract_global_ANI_results.sql"
columns_to_keep='reference_accession, \"group\" AS group_label'

# Start by making the necessary output folders and copying over the associated pipeline inputs
## Random Archaea/Bacteria singletons
current_input_root="${SINGLETONS_INPUT_ROOT}"
current_base_output_root="${SINGLETONS_OUTPUT_ROOT}"
for folder_name in $(find  ${current_input_root} -type d -name 'BATCH*' -printf '%P\n')
do
    current_output_folder="${current_base_output_root}/${folder_name}"
    input_file="$(ls ${current_output_folder}/*-pipeline_input.tsv)"
    base_input_file=$(basename ${input_file%-pipeline_input.tsv})

    data_files="${current_input_root}/${folder_name}/GLOBAL_ANI_RESULTS/*/*-global_ANI.tsv"
    output_file="${current_output_folder}/PARTIAL_DATA_FILES/${base_input_file}-global_ANI_results.tsv"
    to_replace="data_files:${data_files};columns_to_keep:${columns_to_keep}"
    generate_table "${folder_name} global ANI results" "${current_sql_file}" "${output_file}" "${to_replace}"
done


## Bacterial singletons with >= 1000X coverage
current_input_root="${TOP_N_INPUT_ROOT}"
current_base_output_root="${TOP_N_OUTPUT_ROOT}"

current_output_folder="${current_base_output_root}/BACTERIA/BATCH_01"
input_file="$(ls ${current_output_folder}/*-pipeline_input.tsv)"
base_input_file=$(basename ${input_file%-pipeline_input.tsv})

data_files="${current_input_root}/GLOBAL_ANI_RESULTS/*/*-global_ANI.tsv"
output_file="${current_output_folder}/PARTIAL_DATA_FILES/${base_input_file}-global_ANI_results.tsv"
to_replace="data_files:${data_files};columns_to_keep:${columns_to_keep}"
generate_table "TOP N global ANI results" "${current_sql_file}" "${output_file}" "${to_replace}"


## Tarantellae
current_input_root="${TARANTELLAE_INPUT_ROOT}"
current_base_output_root="${TARANTELLAE_OUTPUT_ROOT}"

current_output_folder="${current_base_output_root}/BACTERIA/BATCH_00"
input_file="$(ls ${current_output_folder}/*-pipeline_input.tsv)"
base_input_file=$(basename ${input_file%-pipeline_input.tsv})

data_files="${current_input_root}/GLOBAL_ANI_RESULTS/*/*-global_ANI.tsv"
output_file="${current_output_folder}/PARTIAL_DATA_FILES/${base_input_file}-global_ANI_results.tsv"
to_replace="data_files:${data_files};columns_to_keep:${columns_to_keep}"
generate_table "Tarantellae global ANI results" "${current_sql_file}" "${output_file}" "${to_replace}"



#################################################
echo '-------------------------------------------'
echo '---------Reference Genomes Cache-----------'
echo '-------------------------------------------'
summarize_intermediate_files ${CACHED_FILES_ROOT}/GENOMES_CACHE ${OUTPUT_FOLDER}/CACHED_FILES/reference_genomes.tsv

echo '---------------------------------------------------------'
echo '---------Summarize pipeline intermediate files-----------'
echo '---------------------------------------------------------'
for intermediate_folder in "MAPPED_READS" "MEGAHIT_CONTIGS" "SIZE_FILTERED_CONTIGS" "BINNED_CONTIGS"
do
    #For each singleton folder
    for folder_name in $(find  ${SINGLETONS_INPUT_ROOT} -type d -name 'BATCH*' -printf '%P\n')
    do
        current_output_folder="${SINGLETONS_OUTPUT_ROOT}/${folder_name}"
        mkdir -p "${current_output_folder}"

        input_folder="${SINGLETONS_INPUT_ROOT}/${folder_name}/${intermediate_folder}"
        output_file="${current_output_folder}/INTERMEDIATE_FILES/${intermediate_folder}.tsv"
        summarize_intermediate_files "${input_folder}" "${output_file}"
    done

    #For the top N data
    current_output_folder="${TOP_N_OUTPUT_ROOT}/BACTERIA/BATCH_01"
    mkdir -p "${current_output_folder}"

    input_folder="${TOP_N_INPUT_ROOT}/${intermediate_folder}"
    output_file="${current_output_folder}/INTERMEDIATE_FILES/${intermediate_folder}.tsv"
   summarize_intermediate_files "${input_folder}" "${output_file}"


    #Tarantellae
    current_output_folder="${TARANTELLAE_OUTPUT_ROOT}/BACTERIA/BATCH_00"
    mkdir -p "${current_output_folder}"

    input_folder="${TARANTELLAE_INPUT_ROOT}/${intermediate_folder}"
    output_file="${current_output_folder}/INTERMEDIATE_FILES/${intermediate_folder}.tsv"
    summarize_intermediate_files "${input_folder}" "${output_file}"
done


echo '-----------------------------------------------------'
echo '---------Merge pipeline intermediate files-----------'
echo '-----------------------------------------------------'
for input_file in $(find ${OUTPUT_FOLDER} -type f -name '*-pipeline_input.tsv')
do
    base_input_file=$(basename ${input_file%-pipeline_input.tsv})
    base_input_folder=$(dirname ${input_file} )
    to_replace="pipeline_input_file:${input_file};"


        current_sql_file="${SQL_QUERIES}/merge_pipeline_data.sql"
        output_file="${base_input_folder}/merge_assembly_data"

        to_replace+="SRA_meta_data_file:${base_input_folder}/PARTIAL_DATA_FILES/*-SRA_meta_data.parquet;"
        to_replace+="STAT_data_file:${base_input_folder}/PARTIAL_DATA_FILES/*-STAT_data.parquet;"
        to_replace+="genomes_meta_data_file:${base_input_folder}/PARTIAL_DATA_FILES/*-reference_genomes_meta_data.parquet;"
        to_replace+="mapped_reads_file:${base_input_folder}/INTERMEDIATE_FILES/MAPPED_READS.tsv;"
        to_replace+="megahit_assemblies_file:${base_input_folder}/INTERMEDIATE_FILES/MEGAHIT_CONTIGS.tsv;"
        to_replace+="binned_assemblies_file:${base_input_folder}/INTERMEDIATE_FILES/BINNED_CONTIGS.tsv;"
        to_replace+="size_filtered_file:${base_input_folder}/INTERMEDIATE_FILES/SIZE_FILTERED_CONTIGS.tsv;"
        to_replace+="genomes_data_file:${OUTPUT_FOLDER}/CACHED_FILES/reference_genomes.tsv;"
        to_replace+="checkm_results_file:${base_input_folder}/PARTIAL_DATA_FILES/*-checkm_results.tsv;"
        to_replace+="global_ANI_results_file:${base_input_folder}/PARTIAL_DATA_FILES/*-global_ANI_results.tsv;"

        to_replace+="intermediate_data_output_file:${base_input_folder}/PARTIAL_MERGED_DATA_FILES/${base_input_file}-intermediate_data.parquet;"
        to_replace+="reference_genomes_data_output_file:${base_input_folder}/PARTIAL_MERGED_DATA_FILES/${base_input_file}-reference_genomes_data.parquet;"
        to_replace+="input_meta_data_output_file:${base_input_folder}/PARTIAL_MERGED_DATA_FILES/${base_input_file}-input_meta_data.parquet;"
        to_replace+="pipeline_output_data_output_file:${base_input_folder}/PARTIAL_MERGED_DATA_FILES/${base_input_file}-pipeline_output_data.parquet;"
        to_replace+="fully_merged_data_output_file:${base_input_folder}/${base_input_file}-pipeline_results.parquet;"


    mkdir -p ${base_input_folder}/PARTIAL_MERGED_DATA_FILES/
    generate_table "Merge ${base_input_folder} data" "${current_sql_file}" "${output_file}" "${to_replace}"
done



echo '-------------------------------------------'
echo '---------Merge all pipeline results--------'
echo '-------------------------------------------'

#Individual assemblies
current_sql_file="${SQL_QUERIES}/merge_all_pipeline_individual_assembly_results.sql"
output_prefix="individual_assemblies"
for base_folder in "RANDOM_SINGLETONS" "TOP_N_SINGLETONS" "TARANTELLAE_ANALYSIS"
do
    output_file="${OUTPUT_FOLDER}/${base_folder}/pipeline-${base_folder,,}-${output_prefix}.parquet"
    # echo $output_file
    to_replace="results_files:${OUTPUT_FOLDER}/${base_folder}/*/*/*-pipeline_results.parquet;sequencing_projects:${SEQUENCING_PROJECTS}"
    generate_table "Merge assembly pipeline results" "${current_sql_file}" "${output_file}" "${to_replace}"  
done

output_file="${OUTPUT_FOLDER}/pipeline-individual_assemblies.parquet"
to_replace="tarantellae_data_file:${OUTPUT_FOLDER}/TARANTELLAE_ANALYSIS/pipeline-tarantellae_analysis-individual_assemblies.parquet;"
to_replace+="random_data_file:${OUTPUT_FOLDER}/RANDOM_SINGLETONS/pipeline-random_singletons-individual_assemblies.parquet;"
to_replace+="top_n_data_file:${OUTPUT_FOLDER}/TOP_N_SINGLETONS/pipeline-top_n_singletons-individual_assemblies.parquet"
generate_table "Merge individual pipeline results" "${SQL_QUERIES}/combine_pipeline_individual_results.sql" "${output_file}" "${to_replace}"  
