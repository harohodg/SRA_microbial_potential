#!/usr/bin/env bash

# Exit the script on any failure
set -e
# Treat failures in a pipeline as an error
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_FOLDER="${SCRIPT_DIR}/../"
SANDPIPER_DATA="${ROOT_FOLDER}/RAW_DATA/SANDPIPER_DATA/sandpiper1.1.0.gtdb.csv.gz"
RAW_STAT_DATA="${ROOT_FOLDER}/RAW_DATA/2025_01_15/STAT_DATA-2025_01_15/*"
RAW_SRA_META_DATA="${ROOT_FOLDER}/RAW_DATA/2025_01_15/SRA_META_DATA-2025_01_15/*"
RAW_GTDB_DATA="${ROOT_FOLDER}/RAW_DATA/GTDB_DATA/*.gz"
SQL_QUERIES="${SCRIPT_DIR}/SQL_queries/SECONDARY_DATA_TABLES/"
PPANGGOLIN_ANALYSES="${SCRIPT_DIR}/PPANGGOLIN_ANALYSES"

DUCKDB="${ROOT_FOLDER}/bin/duckdb"
source ${SCRIPT_DIR}/data_functions.sh


DATABASE="$1"
PRIMARY_DATA_TABLES_FOLDER="$2"
ASSEMBLY_DATA_TABLES_FOLDER="$3"
OUTPUT_FOLDER="$4"

[[ ! -e "$DATABASE" ]] && { echo "$DATABASE does not appear to be a file" >&2; exit 1; }
GTDB_DATA="${PRIMARY_DATA_TABLES_FOLDER}/GTDB_raw_genome_counts.parquet"
MERGED_GENBANK_GTDB_DATA="${PRIMARY_DATA_TABLES_FOLDER}/*-merged_GTDB_Genbank_data.parquet"
INDIVIDUAL_ASSEMBLY_DATA="${ASSEMBLY_DATA_TABLES_FOLDER}/pipeline-individual_assemblies.parquet"

#========================================== taxonomy overview ================================
#How many tax ids are there per root taxonomy with rank above species, species, below species
#Sorted by total # of tax ids ASC
output_file="${OUTPUT_FOLDER}/taxonomy_overview.tsv"
generate_table 'Taxonomy overview' "${SQL_QUERIES}/taxonomy_overview.sql" "${output_file}"
#display_table "${output_file}"


#========================================= genomes overview =======================================
#How many GenBank/RefSeq genomes are there 
#per root taxonomy, per tax id rank (above, below, species, species or lower rolled up to species)
#How many are singletons
output_file="${OUTPUT_FOLDER}/genomes_overview.tsv" 
generate_table 'Genomes overview' "${SQL_QUERIES}/GenBank_RefSeq_overview.sql" "${output_file}"
#display_table "${output_file}"


#===================================== SRA overview ======================================
#How many datasets are in the SRA, how many are meta-genomes, how many have missing data fields?
output_file="${OUTPUT_FOLDER}/SRA_overview.tsv"
generate_table 'SRA overview' "${SQL_QUERIES}/SRA_overview.sql" "${output_file}"
#display_table "${output_file}"


#=================================== SRA+STAT overview : Everything / Metagenomes ==============================================
#How many datasets in the SRA have STAT predictions, how many species have STAT predictions. How many are metagenomic
#No filtering based on num_bases, num_genomes etc.
unset primary_data_filters;declare -A primary_data_filters
primary_data_filters["everything"]="true"
primary_data_filters["metagenomes"]="IFNULL(SRA_what_was_sequenced, '') LIKE '%metagenome%'"


unset data_tables;declare -A data_tables
unset secondary_data_filters;declare -A secondary_data_filters
for target_taxonomy in "Archaea" "Bacteria" "Viruses" "Eukaryota" "UNKNOWN"
do
    data_tables["${target_taxonomy}"]="${PRIMARY_DATA_TABLES_FOLDER}/${target_taxonomy}-search_table.parquet"
    secondary_data_filters["${target_taxonomy}"]="true"
done
data_tables["ALL"]="${PRIMARY_DATA_TABLES_FOLDER}/*-search_table.parquet"
data_tables["microbes"]="${PRIMARY_DATA_TABLES_FOLDER}/*-search_table.parquet"

secondary_data_filters["ALL"]="true"
secondary_data_filters["microbes"]="STAT_root_taxonomy IN ('Archaea', 'Bacteria')"

for data_label in "everything" "metagenomes"
do
    output_root="${OUTPUT_FOLDER}/SRA_STAT_overview/${data_label^}"
    for target_taxonomy in "Archaea" "Bacteria" "Viruses" "Eukaryota" "UNKNOWN" "ALL" "microbes"
    do
        data_filter="${primary_data_filters[${data_label}]} AND ${secondary_data_filters[${target_taxonomy}]}"
        output_file="${output_root}/${target_taxonomy}-SRA_STAT_overview.tsv" 

        to_replace="root_taxonomy:${target_taxonomy};search_table:${data_tables[${target_taxonomy}]};data_filter:${data_filter};data_label:${data_label}"
        generate_table "${data_label} : ${target_taxonomy} SRA STAT overview" "${SQL_QUERIES}/SRA_STAT_overview.sql" "${output_file}"  "$to_replace"
        #display_table "${output_file}" 
    done
done



# #==================== SRA potential : Everything / metagenomes / GenBank Singletons / GTDB Singetons / Both Singletons =======================================
# #As a function of genome coverage threshold, how many potential assemblies are there
# #For all predicted assemblies where the species has at least one genbank genome, and the associated
# #SRA dataset has an average read_length
novel_assembly_equation="${NOVEL_PROPOSED_ASSEMBLY}"
coverage_equation="${PROPOSED_ASSEMBLY_COVERAGE}"

unset data_filters;declare -A data_filters
base_filter="SRA_dataset_size >= 1000"
data_filters["everything"]="${base_filter} AND query_num_genbank_genomes >= 1"
data_filters["metagenomes"]="${base_filter} AND query_num_genbank_genomes >= 1 AND IFNULL(SRA_what_was_sequenced, '') LIKE '%metagenome%'"
data_filters["genbank_singletons"]="${base_filter} AND query_num_genbank_genomes = 1"
data_filters["GTDB_singletons"]="${base_filter} AND GTDB_num_genomes = 1"
data_filters["double_singletons"]="${base_filter} AND query_num_genbank_genomes = 1 AND GTDB_num_genomes = 1"

coverage_thesholds=$(echo 0; seq 0 0 | awk '{print 10^$1}')
for data_label in "everything" "metagenomes" "genbank_singletons" "GTDB_singletons" "double_singletons"
do
    base_data_filter="${data_filters[$data_label]}"
    output_root="${OUTPUT_FOLDER}/STAT_potential/${data_label^}"
    for target_taxonomy in "Archaea" "Bacteria" "Viruses" "Eukaryota" "UNKNOWN" "ALL" "microbes"
    do
        for genome_coverage_threshold in $coverage_thesholds;
        do
            data_filter="${coverage_equation} >= ${genome_coverage_threshold} AND ${base_data_filter} AND ${secondary_data_filters[${target_taxonomy}]}"
            data_table="${data_tables[$target_taxonomy]}"
            
            columns_to_group="'${data_label^}' AS data_label,\n"
            columns_to_group+="${genome_coverage_threshold} AS genome_coverage_threshold,\n"
            columns_to_group+="'${target_taxonomy}' AS root_taxonomy,\n"
            columns_to_group+="${novel_assembly_equation} AS is_novel_assembly,\n"
            columns_to_group+="'ANY' AS assay_type,\n 'ANY' AS sequencing_platform\n"

            to_replace="data_filter:${data_filter};data_table:${data_table};columns_to_group:${columns_to_group};coverage_equation:${coverage_equation}"
            
            output_file="${output_root}/${target_taxonomy}/${target_taxonomy}-SRA_potential-ge_${genome_coverage_threshold}X_coverage.tsv" 
            generate_table "${data_label} : ${target_taxonomy} SRA potential >= ${genome_coverage_threshold}X genome coverage" "${SQL_QUERIES}/SRA_potential.sql" "$output_file" "$to_replace"
        done
    done
done
#=================================== top N species per taxonomy root ==============================================================

output_file="${OUTPUT_FOLDER}/top_N_species.tsv" 
generate_table "Top N species per root taxonomy" "${SQL_QUERIES}/top_N_species.sql" "$output_file" "target_db:genbank;top_N:10"
#display_table "$output_file"

#=================================== GTDB overview ==============================================================
output_file="${OUTPUT_FOLDER}/gtdb_overview.tsv" 
to_replace="data_table:${GTDB_DATA}"
generate_table "GTDB overview" "${SQL_QUERIES}/GTDB_overview.sql" "$output_file" "${to_replace}"
#display_table "$output_file"


#=================================== GTDB kindgom jumpers ==============================================================
output_file="${OUTPUT_FOLDER}/gtdb_kindgom_jumpers.tsv" 
to_replace="data_table:${RAW_GTDB_DATA}"
generate_table "GTDB kingdom jumpers" "${SQL_QUERIES}/GTDB_kingdom_jumpers.sql" "$output_file" "${to_replace}"


#=================================== Genbank / GTDB overlap ==============================================================
unset data_filters;declare -A data_filters
for target_taxonomy in "Archaea" "Bacteria" "Viruses" "Eukaryota" "UNKNOWN"
do
    data_filters["${target_taxonomy}"]="data_table.root_taxonomy ='${target_taxonomy}'"
done
data_filters["ALL"]="true"
data_filters["microbes"]="data_table.root_taxonomy IN ('Archaea', 'Bacteria')"

output_root="${OUTPUT_FOLDER}/GenBank_GTDB_overlap"
for target_taxonomy in "Archaea" "Bacteria" "Viruses" "Eukaryota" "UNKNOWN" "ALL" "microbes"
do
    output_file="${output_root}/${target_taxonomy}-GenBank_GTDB_overlap.tsv" 
    to_replace="data_table:${MERGED_GENBANK_GTDB_DATA};genbank_bounds:(1,1);gtdb_bounds:(1,1),(1,5);target_taxonomy:${target_taxonomy};data_filter:${data_filters[$target_taxonomy]}"
    generate_table "${target_taxonomy} : GenBank Singletons GTDB overlap" "${SQL_QUERIES}/GenBank_GTDB_overlap.sql" "$output_file" "${to_replace}"
    #display_table "${output_file}" 
done


# ============================================================== Individual Assemblies Summaries ==============================================================
## Assembly "success" rate for novel attempted assemblies (excluding Tarantellae)
### Intermediate data - labeled based on threshold of 1% of all categories
base_output_root="${OUTPUT_FOLDER}/ASSEMBLIES/INDIVIDUAL_ASSEMBLIES_OVERVIEW/ASSEMBLY_OUTPUTS/is_novel/fraction_successful"
reference_plot_file="PLOTS/attempted_assemblies/novel_assemblies/successful/RANDOM-1000X/SANDPIPER_INCLUDED/sequencing_types/sequencing_types.tsv"
sql_query=$(cat << EOF
SELECT
    root_taxonomy,
    assembly_data_label,
    concat_ws('|', SRA_library_source, SRA_assay_type) AS library_assay,
    CASE WHEN library_assay IN ( SELECT library_assay FROM read_csv('${reference_plot_file}') ) THEN library_assay ELSE 'OTHER' END AS label,
    ( ${SUCCESSFUL_ATTEMPTED_ASSEMBLY} ) AS successful
FROM read_parquet('${INDIVIDUAL_ASSEMBLY_DATA}')
WHERE (${NOVEL_ATTEMPTED_ASSEMBLY}) AND  assembly_data_label != 'TARANTELLAE_ANALYSIS' 
EOF
)

output_file="${base_output_root}/novel-fraction_successful-intermediate_data.parquet"
generate_table "Novel - successful fraction - intermediate data" "${sql_query}" "$output_file" ""

## Primary data table
intermediate_file="${output_file}"
sql_query=$(cat << EOF
WITH raw_data AS
(
    SELECT
        UNNEST( [{'root_taxonomy':root_taxonomy, 'assembly_data_label':assembly_data_label},
                {'root_taxonomy':'ANY', 'assembly_data_label':assembly_data_label},
                {'root_taxonomy':root_taxonomy, 'assembly_data_label':'ANY'},
                {'root_taxonomy':'ANY', 'assembly_data_label':'ANY'} ], recursive:=true ),
        * EXCLUDE( root_taxonomy, assembly_data_label )
    FROM read_parquet('${intermediate_file}')
), middling_data AS
(
    SELECT 
        root_taxonomy, 
        assembly_data_label,
        label,
        SUM( CASE WHEN successful THEN 1 ELSE 0 END ) AS num_succcessful_assemblies,
        COUNT(*) AS num_assemblies,
    FROM raw_data
    GROUP BY ALL
) 
SELECT
    root_taxonomy, assembly_data_label, label,
    array_to_string( [ ((num_succcessful_assemblies/num_assemblies)::INT)::VARCHAR, '% (', num_succcessful_assemblies::VARCHAR, ' / ',  num_assemblies::VARCHAR, ')'], '' ) AS stats
FROM middling_data

EOF
)

output_file="${base_output_root}/novel-fraction_successful-main.tsv"
generate_table "Novel - successful fraction - main data table" "${sql_query}" "$output_file" ""


## supplimentary data table
sql_query=$(cat << EOF
WITH raw_data AS
(
    SELECT
        UNNEST( [{'root_taxonomy':root_taxonomy, 'assembly_data_label':assembly_data_label},
                {'root_taxonomy':'ANY', 'assembly_data_label':assembly_data_label},
                {'root_taxonomy':root_taxonomy, 'assembly_data_label':'ANY'},
                {'root_taxonomy':'ANY', 'assembly_data_label':'ANY'} ], recursive:=true ),
        * EXCLUDE( root_taxonomy, assembly_data_label )
    FROM read_parquet('${intermediate_file}') WHERE label = 'OTHER'
), middling_data AS
(
    SELECT 
        root_taxonomy, 
        assembly_data_label,
        library_assay AS label,
        SUM( CASE WHEN successful THEN 1 ELSE 0 END ) AS num_succcessful_assemblies,
        COUNT(*) AS num_assemblies,
    FROM raw_data
    GROUP BY ALL
) 
SELECT
    root_taxonomy, assembly_data_label, label,
    array_to_string( [ ((num_succcessful_assemblies/num_assemblies)::INT)::VARCHAR, '% (', num_succcessful_assemblies::VARCHAR, ' / ',  num_assemblies::VARCHAR, ')'], '' ) AS stats
FROM middling_data
EOF
)

output_file="${base_output_root}/novel-fraction_successful-supp.tsv"
generate_table "Novel - successful fraction - supp data table" "${sql_query}" "$output_file" ""



## For novel attempted assemblies, how successul where they
base_output_root="${OUTPUT_FOLDER}/ASSEMBLIES/INDIVIDUAL_ASSEMBLIES_OVERVIEW/ASSEMBLY_OUTPUTS/is_novel/assemblies_per_category"
sql_query=$(cat << EOF
WITH raw_data AS
(
    SELECT
        SRA_accession,
        reference_accession,
        root_taxonomy,
        assembly_data_label,
        assembly_status = 'assembled' AS assembled,
        assembly_quality,
        ${LOW_CONFIDENCE_ASSEMBLY} AS low_confidence_assembly,
        ${GOOD_ANI_ALIGNMENT} AS good_alignment,
    FROM read_parquet('${INDIVIDUAL_ASSEMBLY_DATA}')
    WHERE
        (${NOVEL_ATTEMPTED_ASSEMBLY})  
        AND 
        (assembly_data_label != 'TARANTELLAE_ANALYSIS')
), relabeled_data AS
(
    SELECT
        SRA_accession,
        reference_accession,
        root_taxonomy,
        assembly_data_label,
        CASE
            WHEN assembled = false THEN 'failed assembly'
            WHEN assembled AND assembly_quality = 'Medium' AND NOT low_confidence_assembly AND good_alignment THEN 'Medium quality'
            WHEN assembled AND assembly_quality = 'High' AND NOT low_confidence_assembly AND good_alignment THEN 'High quality'
            WHEN assembled AND (assembly_quality IN ('Poor', 'Low') OR low_confidence_assembly OR NOT good_alignment) THEN 'Poor/Low quality'
            ELSE 'UNKNOWN'
        END AS category,
    FROM raw_data
) SELECT * FROM relabeled_data
EOF
)
output_file="${base_output_root}/novel-assemblies_per_category-intermediate_data.parquet"
generate_table "Novel - assemblies per category - intermediate data" "${sql_query}" "$output_file" ""


## And what to the results look like
sql_query=$(cat << EOF
WITH raw_data AS
(
    SELECT
        UNNEST( [{'root_taxonomy':root_taxonomy, 'assembly_data_label':assembly_data_label},
                {'root_taxonomy':'ANY', 'assembly_data_label':assembly_data_label},
                {'root_taxonomy':root_taxonomy, 'assembly_data_label':'ANY'},
                {'root_taxonomy':'ANY', 'assembly_data_label':'ANY'} ], recursive:=true ),
        * EXCLUDE( root_taxonomy, assembly_data_label )
    FROM read_parquet('${output_file}')
), middling_data AS 
(
    SELECT 
        root_taxonomy, 
        assembly_data_label,
        category,
        COUNT(*) AS num_assemblies
    FROM raw_data
    GROUP BY ALL
) 
SELECT
    root_taxonomy, assembly_data_label, category,
    (num_assemblies, num_novel_assemblies, (100*(num_assemblies/num_novel_assemblies))::INT) AS stats
FROM
(
    SELECT 
        root_taxonomy, assembly_data_label, category,
        num_assemblies,
        SUM(num_assemblies) OVER (PARTITION BY root_taxonomy, assembly_data_label) AS num_novel_assemblies,
    FROM middling_data
)
EOF
)
output_file="${base_output_root}/novel-assemblies_per_category.tsv"
generate_table "Novel - assemblies per category - final stats" "${sql_query}" "$output_file" ""




#TO DO : Clean up the following (everything really), update to latest filtering definitions
unset data_filters;declare -A data_filters
unset data_labels;declare -A data_labels
key='everything';data_filters[${key}]="true";data_labels[${key}]="everything"
key='metagenomic';data_filters[${key}]="SRA_what_was_sequenced LIKE '%metagenome%'";data_labels[${key}]="metagenomic data input"
key='is_novel';data_filters[${key}]="${NOVEL_ATTEMPTED_ASSEMBLY}";data_labels[${key}]="is a novel assembly"
key='is_the_sequencing_project';data_filters[${key}]="data_source = 'is the sequencing project'";data_labels[${key}]="is the seqeuncing project"
key='GTDB_singleton';data_filters[${key}]="reference_genome_num_gtdb_genomes = 1";data_labels[${key}]="is a GTDB singleton"
key='underrepesented_GTDB';data_filters[${key}]="reference_genome_num_gtdb_genomes IN (1,2,3,4)";data_labels[${key}]="is an under represented GTDB species"
key='successfull_assembly';data_filters[${key}]="assembly_status = 'assembled'";data_labels[${key}]="all successfull assemblies"
key='failed_assemblies';data_filters[${key}]="assembly_status != 'assembled'";data_labels[${key}]="all failed assemblies"
key='moderately_successful_assembly';data_filters[${key}]="assembly_quality IN ('Medium', 'High')";data_labels[${key}]="moderately successfull asesmblies"
key='moderately_poor_assembly';data_filters[${key}]="assembly_quality IN ('Low', 'Poor')";data_labels[${key}]="moderately poor asesmblies"
key='successfull_low_contamination';data_filters[${key}]="assembly_status = 'assembled' AND CHECKM_Contamination < 10";data_labels[${key}]="successful assemblies with low contamination"
key='novel_or_other';data_filters[${key}]="assembly_type IN ('is novel', 'overlapping root taxonomy')";data_labels[${key}]="novel or other assembly"

for novel_and_key in "metagenomic" "GTDB_singleton" "underrepesented_GTDB"
do
    key="is_novel_AND_${novel_and_key}";data_filters[${key}]="${data_filters['is_novel']} AND ${data_filters[${novel_and_key}]}";data_labels[${key}]="${data_labels['is_novel']} AND ${data_labels[${novel_and_key}]}"
done



data_table="${INDIVIDUAL_ASSEMBLY_DATA}"
base_output_root="${OUTPUT_FOLDER}/ASSEMBLIES/INDIVIDUAL_ASSEMBLIES_OVERVIEW/"


#-------------------------------------- Assembly inputs --------------------------------------
output_root="${base_output_root}/ASSEMBLY_INPUTS"
grouping_columns=('root_taxonomy' 'assembly_data_label' 'assembly_type')
keeping_columns=('primary_data_label' 'secondary_data_label' 'root_taxonomy' 'assembly_data_label' 'assembly_type' "COLUMNS('^num.*')")
IFS=',';columns_to_keep="${keeping_columns[*]}"


unset filter_pairs;filter_pairs=("everything:everything" "is_novel:GTDB_singleton" "is_novel:underrepesented_GTDB")
for pair in "${filter_pairs[@]}"; do
    # Split the string into individual elements using IFS
    IFS=':' read -r primary_key secondary_key <<< "$pair"

    primary_data_filter="${data_filters[$primary_key]}"
    secondary_data_filter="${data_filters[$secondary_key]}"

    primary_data_label="${data_labels[$primary_key]}"
    secondary_data_label="${data_labels[$secondary_key]}"

    summarize_assemblies \
    "${primary_data_label}" \
    "${primary_data_filter}" \
    "${secondary_data_label}" \
    "${secondary_data_filter}" \
    $(IFS='|';echo "${grouping_columns[*]}")  \
    "${SQL_QUERIES}/assemblies_overview.sql" \
    "${output_root}/${primary_key}/${secondary_key}/individual_assemblies-${primary_key}-${secondary_key}" \
    "data_table:${data_table};primary_data_filter:${primary_data_filter};secondary_data_filter:${secondary_data_filter};columns_to_keep:${columns_to_keep};"
done

#-------------------------------------- Assembly outputs --------------------------------------
output_root="${base_output_root}/ASSEMBLY_OUTPUTS"
grouping_columns=('root_taxonomy' 'assembly_data_label' 'assembly_type' 'ANI_similarity')
keeping_columns=('primary_data_label' 'secondary_data_label' 'root_taxonomy' 'assembly_data_label' 'assembly_type' 'ANI_similarity' "COLUMNS('^num.*')" "COLUMNS('^total.*')" "COLUMNS('^fraction.*')")
IFS=',';columns_to_keep="${keeping_columns[*]}"


unset filter_pairs;filter_pairs=("is_novel:moderately_successful_assembly" "is_novel:moderately_poor_assembly" "is_novel:successfull_low_contamination")
for pair in "${filter_pairs[@]}"; do
    # Split the string into individual elements using IFS
    IFS=':' read -r primary_key secondary_key <<< "$pair"

    primary_data_filter="${data_filters[$primary_key]}"
    secondary_data_filter="${data_filters[$secondary_key]}"

    primary_data_label="${data_labels[$primary_key]}"
    secondary_data_label="${data_labels[$secondary_key]}"

    summarize_assemblies \
    "${primary_data_label}" \
    "${primary_data_filter}" \
    "${secondary_data_label}" \
    "${secondary_data_filter}" \
    $(IFS='|';echo "${grouping_columns[*]}")  \
    "${SQL_QUERIES}/assemblies_overview.sql" \
    "${output_root}/${primary_key}/${secondary_key}/individual_assemblies-${primary_key}-${secondary_key}" \
    "data_table:${data_table};primary_data_filter:${primary_data_filter};secondary_data_filter:${secondary_data_filter};columns_to_keep:${columns_to_keep};"
done



# More more
output_root="${base_output_root}/ASSEMBLY_OUTPUTS"
grouping_columns=('root_taxonomy' 'assembly_data_label' 'assembly_type' 'SRA_assay_type')
keeping_columns=('primary_data_label' 'secondary_data_label' 'root_taxonomy' 'assembly_data_label' 'assembly_type' 'SRA_assay_type' "COLUMNS('^num.*')" "COLUMNS('^total.*')" "COLUMNS('^fraction.*')")
IFS=',';columns_to_keep="${keeping_columns[*]}"


unset filter_pairs;filter_pairs=("is_novel:failed_assemblies" "is_novel_AND_metagenomic:failed_assemblies")
for pair in "${filter_pairs[@]}"; do
    # Split the string into individual elements using IFS
    IFS=':' read -r primary_key secondary_key <<< "$pair"

    primary_data_filter="${data_filters[$primary_key]}"
    secondary_data_filter="${data_filters[$secondary_key]}"

    primary_data_label="${data_labels[$primary_key]}"
    secondary_data_label="${data_labels[$secondary_key]}"

    summarize_assemblies \
    "${primary_data_label}" \
    "${primary_data_filter}" \
    "${secondary_data_label}" \
    "${secondary_data_filter}" \
    $(IFS='|';echo "${grouping_columns[*]}")  \
    "${SQL_QUERIES}/assemblies_overview.sql" \
    "${output_root}/${primary_key}/${secondary_key}/individual_assemblies-${primary_key}-${secondary_key}" \
    "data_table:${data_table};primary_data_filter:${primary_data_filter};secondary_data_filter:${secondary_data_filter};columns_to_keep:${columns_to_keep};"
done


# More more more
output_root="${base_output_root}/ASSEMBLY_OUTPUTS"
grouping_columns=('root_taxonomy' 'assembly_data_label' 'assembly_type')
keeping_columns=('primary_data_label' 'secondary_data_label' 'root_taxonomy' 'assembly_data_label' 'assembly_type' "COLUMNS('^num.*')" "COLUMNS('^total.*')" "COLUMNS('^fraction.*')" "COLUMNS('^average.*')") 
IFS=',';columns_to_keep="${keeping_columns[*]}"


unset filter_pairs;filter_pairs=("everything:successfull_assembly" "novel_or_other:successfull_assembly")
for pair in "${filter_pairs[@]}"; do
    # Split the string into individual elements using IFS
    IFS=':' read -r primary_key secondary_key <<< "$pair"

    primary_data_filter="${data_filters[$primary_key]}"
    secondary_data_filter="${data_filters[$secondary_key]}"

    primary_data_label="${data_labels[$primary_key]}"
    secondary_data_label="${data_labels[$secondary_key]}"

    summarize_assemblies \
    "${primary_data_label}" \
    "${primary_data_filter}" \
    "${secondary_data_label}" \
    "${secondary_data_filter}" \
    $(IFS='|';echo "${grouping_columns[*]}")  \
    "${SQL_QUERIES}/assemblies_overview.sql" \
    "${output_root}/${primary_key}/${secondary_key}/individual_assemblies-${primary_key}-${secondary_key}" \
    "data_table:${data_table};primary_data_filter:${primary_data_filter};secondary_data_filter:${secondary_data_filter};columns_to_keep:${columns_to_keep};"
done

# One more for a ? : Proportion of eukaryotic assemblies 
output_root="${base_output_root}/ASSEMBLY_OUTPUTS"
grouping_columns=('root_taxonomy')
keeping_columns=('primary_data_label' 'secondary_data_label' 'root_taxonomy' "COLUMNS('^num.*')" "COLUMNS('^total.*')" "COLUMNS('^fraction.*')" "COLUMNS('^average.*')") 
IFS=',';columns_to_keep="${keeping_columns[*]}"


primary_data_label='>=1000X novel assembled Medium or High'
primary_data_filter="${NOVEL_ATTEMPTED_ASSEMBLY} = true AND assembly_status = 'assembled' AND assembly_quality IN ('Medium', 'High') AND ${ATTEMPTED_ASSEMBLY_COVERAGE} >= 1000"
secondary_data_label="eukaryotic wgs assemblies"
secondary_data_filter="data_source = 'is a Eukaryota sequencing project' AND SRA_assay_type = 'WGS'"

data_table="${INDIVIDUAL_ASSEMBLY_DATA}"


summarize_assemblies \
"${primary_data_label}" \
"${primary_data_filter}" \
"${secondary_data_label}" \
"${secondary_data_filter}" \
$(IFS='|';echo "${grouping_columns[*]}")  \
"${SQL_QUERIES}/assemblies_overview.sql" \
"${output_root}/individual_assemblies-proportion_of_Eukaryota" \
"data_table:${data_table};primary_data_filter:${primary_data_filter};secondary_data_filter:${secondary_data_filter};columns_to_keep:${columns_to_keep};"

#============================================================== Checkm Overview ==============================================================
output_file="${OUTPUT_FOLDER}/checkm_overview.tsv" 

thresholds='[1, 1000]'
data_table="${INDIVIDUAL_ASSEMBLY_DATA}"
coverage_equation="${ATTEMPTED_ASSEMBLY_COVERAGE}"
data_filter="${NOVEL_ATTEMPTED_ASSEMBLY} = true AND assembly_status = 'assembled' AND assembly_quality IN ('Medium', 'High')"
to_replace="data_table:${data_table};thresholds:${thresholds};coverage_equation:${coverage_equation};data_filter:${data_filter}"
generate_table "Checkm overview" "${SQL_QUERIES}/checkm_overview.sql" "$output_file" "${to_replace}"


#============================================================== General assembly success ==============================================================
current_sql_file="${SQL_QUERIES}/assembly_success.sql"
output_file="${OUTPUT_FOLDER}/pipeline_assembly_success.tsv"

to_replace="data_file:${INDIVIDUAL_ASSEMBLY_DATA};"
to_replace+="data_filter:(${NOVEL_ATTEMPTED_ASSEMBLY})"
generate_table "Checkm overview" "${current_sql_file}" "$output_file" "${to_replace}"


#============================================================== Assembled,Novel Contamination distribution ==============================================================
base_output_root="${OUTPUT_FOLDER}/ASSEMBLIES/INDIVIDUAL_ASSEMBLIES_OVERVIEW/ASSEMBLY_OUTPUTS/STATS/"
current_sql_file="${SQL_QUERIES}/assemblies_stats.sql"
output_file="${base_output_root}/novel-assembled-contaminations_stats.tsv"

to_replace="data_file:${INDIVIDUAL_ASSEMBLY_DATA};"
to_replace+="target_column:CHECKM_Contamination;"
to_replace+="data_filter:(${NOVEL_ATTEMPTED_ASSEMBLY}) AND assembly_status = 'assembled'"
generate_table "Checkm overview" "${current_sql_file}" "$output_file" "${to_replace}"



# #========== Sandpiper comparison ==========
## Extract Sandpiper/STAT microbial data for further crunching
### "Everything" - STAT
base_output_root="${OUTPUT_FOLDER}/SANDPIPER_COMPARISON/"
sql_query="SELECT acc AS SRA_accession, tax_id AS taxonomy FROM read_parquet('${RAW_STAT_DATA}') WHERE tax_id IN ( SELECT tax_id FROM  ROOT_TAXONOMY_LABELS WHERE root_taxonomy_label = 'Archaea' OR root_taxonomy_label = 'Bacteria' )"
output_file="${base_output_root}/microbial_STAT_data.parquet"

to_replace="raw_STAT_data:${RAW_STAT_DATA};"
generate_table "Microbial STAT data" "${sql_query}" "$output_file" ""

### "Everything" - Sandpiper
base_output_root="${OUTPUT_FOLDER}/SANDPIPER_COMPARISON/"
sql_query="SELECT sample AS SRA_accession, taxonomy FROM read_csv('${SANDPIPER_DATA}')"
output_file="${base_output_root}/raw_sandpiper_data.parquet"

generate_table "Raw sandpiper data" "${sql_query}" "$output_file" ""


### "Double singetons data"
base_output_root="${OUTPUT_FOLDER}/SANDPIPER_COMPARISON/"
sql_query="SELECT tax_id, gtdb_species[1] AS gtdb_species FROM read_parquet('${PRIMARY_DATA_TABLES_FOLDER}/*-merged_GTDB_Genbank_data.parquet') WHERE num_genbank_genomes = 1 AND LENGTH(genbank_base_accessions) = 1"
output_file="${base_output_root}/double_singletons.parquet"

generate_table "Double singletons" "${sql_query}" "$output_file" ""

### "Double singletons" - STAT
base_output_root="${OUTPUT_FOLDER}/SANDPIPER_COMPARISON/"
sql_query="SELECT query_tax_id AS taxonomy, STAT_SRA_accession AS SRA_accession, SRA_average_read_length*STAT_num_reads/query_mean_genome_length AS coverage FROM read_parquet('${PRIMARY_DATA_TABLES_FOLDER}/*-search_table.parquet') WHERE query_tax_id IN ( SELECT tax_id FROM read_parquet('${base_output_root}/double_singletons.parquet') )"
output_file="${base_output_root}/STAT-double_singletons-data.parquet"

generate_table "Double singletons : STAT" "${sql_query}" "$output_file" ""

### "Double singletons" - Sandpiper
base_output_root="${OUTPUT_FOLDER}/SANDPIPER_COMPARISON/"
sql_query="SELECT taxonomy, sample AS SRA_accession, coverage FROM read_csv('${SANDPIPER_DATA}') WHERE string_split(taxonomy, ';')[-1][5:] IN ( SELECT gtdb_species FROM read_parquet('${base_output_root}/double_singletons.parquet') )"
output_file="${base_output_root}/sandpiper-double_singletons-data.parquet"

generate_table "Double singletons : Sandpiper" "${sql_query}" "$output_file" ""


## Calculation overlaping SRA accessions
### Everything
base_output_root="${OUTPUT_FOLDER}/SANDPIPER_COMPARISON/"
sql_query="SELECT DISTINCT SRA_accession FROM read_parquet('${base_output_root}/raw_sandpiper_data.parquet') WHERE SRA_accession IN (SELECT SRA_accession FROM read_parquet('${base_output_root}/microbial_STAT_data.parquet') ) "
output_file="${base_output_root}/sandpiper-microbial_stat-overlap.parquet"

generate_table "Sandpiper/Microbial STAT overlap : all ranks" "${sql_query}" "$output_file" ""


### "Double singletons" - 0X coverage
base_output_root="${OUTPUT_FOLDER}/SANDPIPER_COMPARISON/"
sql_query="SELECT DISTINCT SRA_accession FROM read_parquet('${base_output_root}/sandpiper-double_singletons-data.parquet') WHERE SRA_accession IN (SELECT SRA_accession FROM read_parquet('${base_output_root}/STAT-double_singletons-data.parquet') ) "
output_file="${base_output_root}/double_singlteons-0x-overlap.parquet"

generate_table "Double singletons 0X coverage overlap" "${sql_query}" "$output_file" ""

### "Double singletons" - 1X coverage
base_output_root="${OUTPUT_FOLDER}/SANDPIPER_COMPARISON/"
sql_query="SELECT DISTINCT SRA_accession FROM ( SELECT SRA_accession FROM read_parquet('${base_output_root}/sandpiper-double_singletons-data.parquet') WHERE coverage >= 1) WHERE SRA_accession IN ( SELECT SRA_accession FROM read_parquet('${base_output_root}/STAT-double_singletons-data.parquet') WHERE coverage >= 1) "
output_file="${base_output_root}/double_singlteons-1x-overlap.parquet"

generate_table "Double singletons 1X coverage overlap" "${sql_query}" "$output_file" ""


## Now all of the stats - so many stats
### Everything - separate
base_output_root="${OUTPUT_FOLDER}/SANDPIPER_COMPARISON/"
sql_query="SELECT 'all ranks|raw_data' AS data_label, 'Sandpiper' AS data_source, COUNT( DISTINCT SRA_accession ) AS num_SRA_accessions, COUNT( * ) AS num_predictions, COUNT( DISTINCT taxonomy ) AS num_taxonomy FROM read_parquet('${base_output_root}/raw_sandpiper_data.parquet') "
output_file="${base_output_root}/sandpiper-all_ranks-raw_data.tsv"
generate_table "Sandpiper : all ranks : stats" "${sql_query}" "$output_file" ""

base_output_root="${OUTPUT_FOLDER}/SANDPIPER_COMPARISON/"
sql_query="SELECT 'all ranks|raw_data' AS data_label, 'STAT' AS data_source, COUNT( DISTINCT SRA_accession ) AS num_SRA_accessions, COUNT( * ) AS num_predictions, COUNT( DISTINCT taxonomy ) AS num_taxonomy FROM read_parquet('${base_output_root}/microbial_STAT_data.parquet') "
output_file="${base_output_root}/STAT-all_ranks-raw_data.tsv"
generate_table "STAT : all ranks : stats" "${sql_query}" "$output_file" ""


### Everything - overlap
base_output_root="${OUTPUT_FOLDER}/SANDPIPER_COMPARISON/"
sql_query="SELECT 'all ranks|overlap' AS data_label, 'Sandpiper' AS data_source, COUNT( DISTINCT SRA_accession ) AS num_SRA_accessions, COUNT( * ) AS num_predictions, COUNT( DISTINCT taxonomy ) AS num_taxonomy FROM read_parquet('${base_output_root}/sandpiper-double_singletons-data.parquet') WHERE SRA_accession IN ( SELECT SRA_accession FROM read_parquet('${base_output_root}/sandpiper-microbial_stat-overlap.parquet') )"
output_file="${base_output_root}/sandpiper-all_ranks-overlap.tsv"
generate_table "Sandpiper : all ranks : overlap stats" "${sql_query}" "$output_file" ""

base_output_root="${OUTPUT_FOLDER}/SANDPIPER_COMPARISON/"
sql_query="SELECT 'all ranks|overlap' AS data_label, 'STAT' AS data_source, COUNT( DISTINCT SRA_accession ) AS num_SRA_accessions, COUNT( * ) AS num_predictions, COUNT( DISTINCT taxonomy ) AS num_taxonomy FROM read_parquet('${base_output_root}/STAT-double_singletons-data.parquet') WHERE SRA_accession IN ( SELECT SRA_accession FROM read_parquet('${base_output_root}/sandpiper-microbial_stat-overlap.parquet') ) "
output_file="${base_output_root}/STAT-all_ranks-overlap.tsv"
generate_table "STAT : all ranks : overlap stats" "${sql_query}" "$output_file" ""



### Double singletons - 0x coverage - separate
base_output_root="${OUTPUT_FOLDER}/SANDPIPER_COMPARISON/"
sql_query="SELECT 'double singletons|0x coverage|raw_data' AS data_label, 'Sandpiper' AS data_source, COUNT( DISTINCT SRA_accession ) AS num_SRA_accessions, COUNT( * ) AS num_predictions, COUNT( DISTINCT taxonomy ) AS num_taxonomy FROM read_parquet('${base_output_root}/sandpiper-double_singletons-data.parquet') "
output_file="${base_output_root}/sandpiper-double_singletons-0X-raw_data.tsv"
generate_table "Sandpiper : double singltetons : 0X : stats" "${sql_query}" "$output_file" ""

base_output_root="${OUTPUT_FOLDER}/SANDPIPER_COMPARISON/"
sql_query="SELECT 'double singletons|0x coverage|raw_data' AS data_label, 'STAT' AS data_source, COUNT( DISTINCT SRA_accession ) AS num_SRA_accessions, COUNT( * ) AS num_predictions, COUNT( DISTINCT taxonomy ) AS num_taxonomy FROM read_parquet('${base_output_root}/STAT-double_singletons-data.parquet') "
output_file="${base_output_root}/STAT-double_singletons-0X-raw_data.tsv"
generate_table "STAT : double singletons : 0X : stats" "${sql_query}" "$output_file" ""


### Double singletons - 0x coverage -  overlap
base_output_root="${OUTPUT_FOLDER}/SANDPIPER_COMPARISON/"
sql_query="SELECT 'double singletons|0x coverage|overlap' AS data_label, 'Sandpiper' AS data_source, COUNT( DISTINCT SRA_accession ) AS num_SRA_accessions, COUNT( * ) AS num_predictions, COUNT( DISTINCT taxonomy ) AS num_taxonomy FROM read_parquet('${base_output_root}/sandpiper-double_singletons-data.parquet') WHERE SRA_accession IN ( SELECT SRA_accession FROM read_parquet('${base_output_root}/double_singlteons-0x-overlap.parquet') )"
output_file="${base_output_root}/sandpiper-double_singletons-0X-overlap.tsv"
generate_table "Sandpiper : double singletons 0X : overlap stats" "${sql_query}" "$output_file" ""

base_output_root="${OUTPUT_FOLDER}/SANDPIPER_COMPARISON/"
sql_query="SELECT 'double singletons|0x coverage|overlap' AS data_label, 'STAT' AS data_source, COUNT( DISTINCT SRA_accession ) AS num_SRA_accessions, COUNT( * ) AS num_predictions, COUNT( DISTINCT taxonomy ) AS num_taxonomy FROM read_parquet('${base_output_root}/STAT-double_singletons-data.parquet') WHERE SRA_accession IN ( SELECT SRA_accession FROM read_parquet('${base_output_root}/double_singlteons-0x-overlap.parquet') ) "
output_file="${base_output_root}/STAT-double_singletons-0X-overlap.tsv"
generate_table "STAT : double singletons 0X : overlap stats" "${sql_query}" "$output_file" ""



### Double singletons - 1x coverage - separate
base_output_root="${OUTPUT_FOLDER}/SANDPIPER_COMPARISON/"
sql_query="SELECT 'double singletons|1x coverage|raw_data' AS data_label, 'Sandpiper' AS data_source, COUNT( DISTINCT SRA_accession ) AS num_SRA_accessions, COUNT( * ) AS num_predictions, COUNT( DISTINCT taxonomy ) AS num_taxonomy FROM read_parquet('${base_output_root}/sandpiper-double_singletons-data.parquet') WHERE coverage >= 1"
output_file="${base_output_root}/sandpiper-double_singletons-1X-raw_data.tsv"
generate_table "Sandpiper : double singltetons : 1X : stats" "${sql_query}" "$output_file" ""

base_output_root="${OUTPUT_FOLDER}/SANDPIPER_COMPARISON/"
sql_query="SELECT 'double singletons|1x coverage|raw_data' AS data_label, 'STAT' AS data_source, COUNT( DISTINCT SRA_accession ) AS num_SRA_accessions, COUNT( * ) AS num_predictions, COUNT( DISTINCT taxonomy ) AS num_taxonomy FROM read_parquet('${base_output_root}/STAT-double_singletons-data.parquet') WHERE coverage >= 1"
output_file="${base_output_root}/STAT-double_singletons-1X-raw_data.tsv"
generate_table "STAT : double singletons : 1X : stats" "${sql_query}" "$output_file" ""


### Double singletons - 1x coverage -  overlap
base_output_root="${OUTPUT_FOLDER}/SANDPIPER_COMPARISON/"
sql_query="SELECT 'double singletons|1x coverage|overlap' AS data_label, 'Sandpiper' AS data_source, COUNT( DISTINCT SRA_accession ) AS num_SRA_accessions, COUNT( * ) AS num_predictions, COUNT( DISTINCT taxonomy ) AS num_taxonomy FROM read_parquet('${base_output_root}/sandpiper-double_singletons-data.parquet') WHERE coverage >=1 AND SRA_accession IN ( SELECT SRA_accession FROM read_parquet('${base_output_root}/double_singlteons-1x-overlap.parquet') )"
output_file="${base_output_root}/sandpiper-double_singletons-1X-overlap.tsv"
generate_table "Sandpiper : double singletons 01X : overlap stats" "${sql_query}" "$output_file" ""

base_output_root="${OUTPUT_FOLDER}/SANDPIPER_COMPARISON/"
sql_query="SELECT 'double singletons|1x coverage|overlap' AS data_label, 'STAT' AS data_source, COUNT( DISTINCT SRA_accession ) AS num_SRA_accessions, COUNT( * ) AS num_predictions, COUNT( DISTINCT taxonomy ) AS num_taxonomy FROM read_parquet('${base_output_root}/STAT-double_singletons-data.parquet') WHERE coverage >= 1 ANd SRA_accession IN ( SELECT SRA_accession FROM read_parquet('${base_output_root}/double_singlteons-1x-overlap.parquet') ) "
output_file="${base_output_root}/STAT-double_singletons-1X-overlap.tsv"
generate_table "STAT : double singletons 1X : overlap stats" "${sql_query}" "$output_file" ""


## microbial STAT meta-data
base_output_root="${OUTPUT_FOLDER}/SANDPIPER_COMPARISON/"
sql_query="SELECT 'microbial STAT sandpiper overlap' AS data_label, 'metagenome' IN organism, librarysource, assay_type, platform, COUNT( DISTINCT SRA_accession ) AS num_SRA_accessions FROM read_parquet('${base_output_root}/microbial_STAT_data.parquet') AS stat_data JOIN read_parquet('${RAW_SRA_META_DATA}') AS meta_data ON (SRA_accession=acc) WHERE SRA_accession IN (SELECT SRA_accession FROM read_parquet('${base_output_root}/sandpiper-microbial_stat-overlap.parquet') ) GROUP BY ALL ORDER BY num_SRA_accessions DESC"
output_file="${base_output_root}/META_DATA/microbial_STAT_sandpiper_overlap.tsv"
generate_table "Microbial STAT Sandpiper overlap Meta-data" "${sql_query}" "$output_file" ""

base_output_root="${OUTPUT_FOLDER}/SANDPIPER_COMPARISON/"
sql_query="SELECT 'microbial STAT exclude sandpiper overlap' AS data_label, 'metagenome' IN organism, librarysource, assay_type, platform, COUNT( DISTINCT SRA_accession ) AS num_SRA_accessions FROM read_parquet('${base_output_root}/microbial_STAT_data.parquet') AS stat_data JOIN read_parquet('${RAW_SRA_META_DATA}') AS meta_data ON (SRA_accession=acc) WHERE SRA_accession NOT IN (SELECT SRA_accession FROM read_parquet('${base_output_root}/sandpiper-microbial_stat-overlap.parquet') ) GROUP BY ALL ORDER BY num_SRA_accessions DESC"
output_file="${base_output_root}/META_DATA/microbial_STAT_sandpiper_not_overlap.tsv"
generate_table "Microbial STAT Sandpiper not overlap Meta-data" "${sql_query}" "$output_file" ""


## novel microbial STAT >=1X coverage meta-data
base_output_root="${OUTPUT_FOLDER}/SANDPIPER_COMPARISON/"
sql_query=$(cat << EOF
SELECT 
    'novel microbial STAT >=1X coverage exclude sandpiper overlap' AS data_label, 
    'metagenome' IN organism, 
    librarysource, 
    assay_type, 
    platform, 
    COUNT( DISTINCT SRA_SRA_accession ) AS num_SRA_accessions
FROM 
    read_parquet('${PRIMARY_DATA_TABLES_FOLDER}/*-search_table.parquet') AS stat_data 
    JOIN 
    read_parquet('${RAW_SRA_META_DATA}') AS meta_data
    ON (SRA_SRA_accession=acc) 
WHERE 
    SRA_SRA_accession NOT IN (SELECT SRA_accession FROM read_parquet('${base_output_root}/raw_sandpiper_data.parquet') )
    AND
    (IFNULL(sequencing_project_type, '') != 'an associated sequencing project' AND STAT_root_taxonomy NOT IN SRA_what_was_sequenced_root_taxonomy_labels) = true 
    AND 
    (SRA_average_read_length*STAT_num_reads/query_mean_genome_length) >= 1 
    AND 
    STAT_root_taxonomy IN ('Archaea', 'Bacteria')     
GROUP BY ALL 
ORDER BY num_SRA_accessions DESC
EOF
)
# echo '-----------------------'
# echo "${sql_query}"
# echo '-----------------------'
output_file="${base_output_root}/META_DATA/novel_1x_microbial_STAT_sandpiper_not_overlap.tsv"
generate_table "Microbial STAT <=1 1X coverage Sandpiper not overlap Meta-data" "${sql_query}" "$output_file" ""



## how much do novel >=1 X microbial overlap with sandpiper (by accession)
base_output_root="${OUTPUT_FOLDER}/SANDPIPER_COMPARISON/"
sql_query=$(cat << EOF
WITH novel_microbial_accessions AS
(
    SELECT
        DISTINCT SRA_accession
    FROM read_parquet('${PRIMARY_DATA_TABLES_FOLDER}/*-search_table.parquet')
    WHERE 
        STAT_root_taxonomy IN ('Archaea', 'Bacteria')
        AND (${NOVEL_PROPOSED_ASSEMBLY})
        AND (${PROPOSED_ASSEMBLY_COVERAGE}) >= 1
), sandpiper_overlap AS 
(
    SELECT
        DISTINCT SRA_accession
    FROM read_parquet('${base_output_root}/raw_sandpiper_data.parquet')
    WHERE SRA_accession IN ( SELECT * FROM novel_microbial_accessions)
)
SELECT
    SUM( CASE WHEN sandpiper_overlap.SRA_accession IS NOT NULL THEN 1 ELSE 0 END ) AS num_sandpiper_overlap,
    SUM( CASE WHEN novel_microbial_accessions.SRA_accession IS NOT NULL THEN 1 ELSE 0 END ) AS num_novel_microbial_accessions,
    (100*(num_sandpiper_overlap/num_novel_microbial_accessions))::INT AS percentage
FROM novel_microbial_accessions LEFT JOIN sandpiper_overlap USING (SRA_accession)
EOF
)

output_file="${base_output_root}/novel_microbial_sandpiper_overlap.tsv"
generate_table "Microbial STAT <=1 1X coverage Sandpiper" "${sql_query}" "$output_file" ""



# ========== ppanggolin summary ==========
## how many gene families are there per sequencing type
base_output_root="${OUTPUT_FOLDER}/PPANGGOLIN_ANALYSES/"
sql_query=$(cat << EOF
SELECT 
    regexp_extract( replace(gene, 'GCF_009295725.1', '_reference'), '.*?_(.*?)_CDS.*', 1) AS assembly_type,
    COUNT( DISTINCT family ) AS num_gen_families
FROM read_csv('${PPANGGOLIN_ANALYSES}/PASS_01/BATCH_03/RESULTS/table/*.tsv')
GROUP BY ALL
EOF
)

output_file="${base_output_root}/tarantellae_overview.tsv"
generate_table "PPANGGOLIN ANALYSES overview" "${sql_query}" "$output_file" ""

## how many gene families are there per combination of sequencing types
base_output_root="${OUTPUT_FOLDER}/PPANGGOLIN_ANALYSES/"
sql_query=$(cat << EOF
WITH intermediate_data AS 
(
    PIVOT
    (
    SELECT 
        DISTINCT regexp_extract( replace(gene, 'GCF_009295725.1', '_reference'), '.*?_(.*?)_CDS.*', 1) AS assembly_type,
        family
    FROM read_csv('${PPANGGOLIN_ANALYSES}/PASS_01/BATCH_03/RESULTS/table/*.tsv')
    ) ON assembly_type USING COUNT(*)::BOOL
)
SELECT 
    * EXCLUDE(family), 
    COUNT(*) AS num_gene_families 
FROM intermediate_data
GROUP BY ALL
EOF
)

output_file="${base_output_root}/tarantellae_overlap_summary.tsv"
generate_table "PPANGGOLIN ANALYSES overlap summary" "${sql_query}" "$output_file" ""


# ====================== Sandpiper Tarantellae coverage ======================
## Fetch data tables
base_output_root="${OUTPUT_FOLDER}/SANDPIPER_COMPARISON/TARANTELLAE"
sql_query=$(cat << EOF
SELECT * FROM read_csv('https://sandpiper.qut.edu.au/api/taxonomy_search_csv_minimal/s__Sarcina%20tarantellae?taxonomy_type=gtdb')
EOF
)

output_file="${base_output_root}/sandpiper_tarantellae_gtdb_estimates.tsv"
generate_table "Sandpiper tarantellae gtdb coverage" "${sql_query}" "$output_file" ""


sql_query=$(cat << EOF
SELECT * FROM read_csv('https://sandpiper.qut.edu.au/api/taxonomy_search_csv_minimal/s__Sarcina%20tarantellae?taxonomy_type=globdb')
EOF
)

output_file="${base_output_root}/sandpiper_tarantellae_globdb_estimates.tsv"
generate_table "Sandpiper tarantellae globdb coverage" "${sql_query}" "$output_file" ""

## And merge
sql_query=$(cat << EOF
WITH sandpiper_gtdb_estimates AS
(
    SELECT 
        * 
    FROM read_csv('${base_output_root}/sandpiper_tarantellae_gtdb_estimates.tsv')
), sandpiper_globdb_estimates AS
(
    SELECT 
        * 
    FROM read_csv('${base_output_root}/sandpiper_tarantellae_globdb_estimates.tsv')
), STAT_estimates AS
(
    SELECT 
        SRA_accession, 
        ROUND(SRA_average_read_length*STAT_num_reads/query_mean_genome_length, 2) AS STAT_coverage 
    FROM read_parquet('${PRIMARY_DATA_TABLES_FOLDER}/Bacteria-search_table.parquet') 
    WHERE query_tax_id = 39493 AND SRA_accession IN ( SELECT run FROM sandpiper_gtdb_estimates UNION ALL SELECT run FROM sandpiper_globdb_estimates)
), assembly_results AS 
(
    SELECT 
        SRA_accession, 
        assembly_status,
        assembly_quality,
        ANI_similarity,
        CHECKM_Completeness
    FROM read_parquet('${INDIVIDUAL_ASSEMBLY_DATA}') WHERE assembly_data_label = 'TARANTELLAE_ANALYSIS' AND SRA_accession IN ( SELECT run FROM sandpiper_gtdb_estimates UNION ALL SELECT run FROM sandpiper_globdb_estimates)
)
    SELECT 
        SRA_accession,
        sandpiper_gtdb_estimates.coverage AS Sandpiper_gtdb_coverage,
        sandpiper_globdb_estimates.coverage AS Sandpiper_globdb_converage,
        STAT_coverage,
        assembly_results.*
    FROM STAT_estimates LEFT JOIN sandpiper_gtdb_estimates ON (SRA_accession = run) LEFT JOIN sandpiper_globdb_estimates USING (run) LEFT JOIN assembly_results USING (SRA_accession)
EOF
)

output_file="${base_output_root}/sandpiper_tarantellae_overlap.tsv"
generate_table "Sandpiper tarantellae overlap" "${sql_query}" "$output_file" ""