NOVEL_PROPOSED_ASSEMBLY="IFNULL(sequencing_project_type, '') != 'an associated sequencing project' AND STAT_root_taxonomy NOT IN SRA_what_was_sequenced_root_taxonomy_labels"
NOVEL_ATTEMPTED_ASSEMBLY="IFNULL(data_source, '') != 'is the sequencing project' AND STAT_root_taxonomy NOT IN SRA_what_was_sequenced_root_taxonomy_labels"

PROPOSED_ASSEMBLY_COVERAGE="SRA_average_read_length*STAT_num_reads/query_mean_genome_length"
ATTEMPTED_ASSEMBLY_COVERAGE="SRA_average_read_length*STAT_num_reads/reference_genome_genome_size"


LOW_CONFIDENCE_ASSEMBLY="starts_with(CHECKM_Additional_Notes,'Low confidence prediction')"
GOOD_ANI_ALIGNMENT="global_ANI_Align_fraction_ref >= 50"
SUCCESSFUL_ATTEMPTED_ASSEMBLY="assembly_status = 'assembled' AND assembly_quality IN ('Medium', 'High') AND NOT (${LOW_CONFIDENCE_ASSEMBLY}) AND  (${GOOD_ANI_ALIGNMENT})"
UNSUCCESSFUL_ATTEMPTED_ASSEMBLY=f"NOT ({SUCCESSFUL_ATTEMPTED_ASSEMBLY})"

enumerate_and_replace() {
    local replace_with="$1"
    shift
    local list_to_replace=("$@")
    local list_to_replace_length=${#list_to_replace[@]}

    local n=$((2 ** $list_to_replace_length - 1))
    local length=$(echo "obase=2; $n" | bc | awk '{print length($0)}')

    for ((i=0; i<=n; i++)); do      
        local string=$(printf "%0${length}d\n" "$(echo "obase=2; $i" | bc)" )
        local updated_list=("${list_to_replace[@]}")
        for (( j=0; j<length; j++ )); do
            char="${string:$j:1}"  # Extract each character
            if [ "$char" -ne '1' ]; then
                updated_list[$j]="${replace_with}"
            fi
        done
        echo "${updated_list[@]}"
    done
}


summarize_intermediate_files () {
    local ANALYSIS_ROOT_FOLDER="$1"
    local ANALYSIS_OUTPUT_FILE="$2"

    if [ ! -f "$ANALYSIS_OUTPUT_FILE" ]; then
      bash -c "${NEXTFLOW_SETUP} nextflow run ${SCRIPT_DIR}/summarize_assembly_intermediate_files/summarize_intermediate_files.nf \
        -resume \
	--input_folder ${ANALYSIS_ROOT_FOLDER} \
        --output_file ${ANALYSIS_OUTPUT_FILE}"
    else
        echo "${ANALYSIS_OUTPUT_FILE} already exists"
    fi
}

create_sed_replacement() {
    local input="$1"
    local replacement_string=""

    IFS=';' read -r -a pairs <<< "$input"
    for pair in "${pairs[@]}"; do
        IFS=':' read -r key value <<< "$pair"
        replacement_string+="s|{$key}|$value|g; "
    done

    echo "$replacement_string"
}


generate_table() {
    local header="$1"
    local sql_file="$2"
    local output_file="$3"
    local to_replace="$4"

    local query_header=""
    local query_footer""
    local sql_query=''

    if [[ "${output_file##*.}" == "tsv" || "${output_file##*.}" == "parquet" ]]; then
        local output_file_settings=$([[ $output_file == *.tsv ]] && echo "(DELIMITER '\t', HEADER true)" || echo "")
        query_header=" SET enable_progress_bar = true; COPY ("
        query_footer=") TO '${output_file}' ${output_file_settings} ;"
    fi


    echo "${header}"
    if [[ ! -f "$output_file" ]]; then
        echo "${output_file} does not exist. Creating parent directory..."

        #If to_replace is not "" or NULL
        #then convert to a sed subsitute command
        if [ -n "$to_replace" ]; then
            local replacement=$(create_sed_replacement "$to_replace" )
            # echo $replacement >&2
            sql_query=$( eval "sed \"${replacement}\" $sql_file" ) 
        elif [ -f "$sql_file" ]; then
            sql_query=$(cat "$sql_file")
        else
            sql_query="${sql_file}"
        fi

        sql_query="${query_header} ${sql_query} ${query_footer}"
        sql_file="${output_file%.*}.sql"

        # Create the parent directory
        mkdir -p "$(dirname $output_file)"
        
        echo "$sql_query" > "$sql_file" 
        ${DUCKDB} --readonly ${DATABASE} < "${sql_file}"
        
    else
        echo "${output_file} already exists."
    fi
    echo '-----------------------------------------------------------'
}

display_table() {
    local input_file="$1"
    local file_type=${2:-'csv'}
     ${DUCKDB} -${3:-'box'} -c "SELECT * FROM read_${file_type}('${input_file}')"
}


summarize_assemblies () {
    local primary_data_label="$1"
    local primary_data_filter="$2"
    local secondary_data_label="$3"
    local secondary_data_filter="$4"

    local grouping_columns
    IFS='|' read -r -a grouping_columns <<< "$5"

    local sql_file="$6"
    local output_root="$7"
    local base_to_replace="$8"


    enumerate_and_replace 'ANY' "${grouping_columns[@]}" | while IFS= read -r line;
    do
        IFS=' ' read -r -a updated_data_columns <<< "$line"
        
        columns_to_group_by="'${primary_data_label}' AS primary_data_label,\n  '${secondary_data_label}' AS secondary_data_label,\n"
        for (( j=0; j<${#grouping_columns[@]}; j++ )); do
            data_column="${grouping_columns[$j]}"
            replacement="${updated_data_columns[$j]}"
            if [ "$data_column" != "$replacement" ]; then
                replacement="'${replacement}'"
            fi

            columns_to_group_by+="${replacement} AS ${data_column},"
        done
        columns_to_group_by="${columns_to_group_by::-1}"

        to_replace="${base_to_replace};columns_to_group_by:${columns_to_group_by};"
        

        output_file="${output_root}-${line// /_}-data.parquet" 
        generate_table "Assemblies Overview : ${primary_data_label} & ${secondary_data_label} - ${line}" "${sql_file}" "$output_file" "${to_replace}"    
    done
}