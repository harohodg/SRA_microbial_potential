#!/bin/bash

#Script which downloads the logan v1 contigs stats parquet file
#If not told otherwise will put the results in the script directory

#Author : Harold Hodgins <hhodgins@uwaterloo.ca>

#History:
#   Version 1.0.0 : June 24, 2025
#       - Functional with minimal error checking
#
#   Version 1.0.1 : November 25, 2025
#       - Added checking for output file
#
#   Version 1.0.2 : June 9, 2026
#       - Updated sql query

get_script_dir () {
#Based on https://stackoverflow.com/questions/56962129/how-to-get-original-location-of-script-used-for-slurm-job
#Modified to handle interactive jobs
    if [[ -n "${SLURM_JOB_ID+x}" ]] && [[ "${SLURM_JOB_NAME}" != "interactive" ]]; then
        local THEPATH=$(scontrol show job "$SLURM_JOB_ID" | awk -F= '/Command=/{print $2}') 
    else
        local THEPATH=$(realpath "$0")
    fi
    echo $(dirname ${THEPATH} )
}


VERSION='1.0.2'
SCRIPT_DIR="$(get_script_dir)"
OUTPUT_FILE='logan_accessions.parquet'

SQL_QUERY="
SELECT 
    CASE WHEN seqstats_contigs_maxlen IS NOT NULL THEN accession ELSE NULL END AS contigs_accessions,
    CASE WHEN seqstats_unitigs_maxlen IS NOT NULL THEN accession ELSE NULL END AS unitigs_accessions,
FROM read_parquet('s3://logan-pub/stats/logan-seqstats-contigs-v1.2.parquet')
WHERE seqstats_contigs_maxlen IS NOT NULL OR seqstats_unitigs_maxlen IS NOT NULL
"

>&2 echo "download_logan_accessions.sh version $VERSION"

# Echo usage if something isn't right.
usage() { 
    echo "Usage: $0 [-d] [output_file (default : ${OUTPUT_FILE})]" 1>&2; 
    echo "Use -d to print what would have been run but not actually run it" 1>&2;
    exit 1; 
}

while getopts ":d" o; do
    case "${o}" in
        d)  
            debug=1
            ;;     
        \?)
            echo "ERROR: Invalid option -$OPTARG" >&2
            usage
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))


if [[ "$#" -gt 1 ]]; then
    echo 'Incorrect number of arguments.'
    usage
else
    output_file=$(realpath --canonicalize-missing "${1:-$SCRIPT_DIR/${OUTPUT_FILE}}")
fi

tmp_file="${output_file}.partial"
sql_query="COPY ( ${SQL_QUERY} ) TO '${tmp_file}' (FORMAT parquet)"
sql_query_file=$(mktemp --dry-run /tmp/sql_query.XXXX.sql)

echo "${sql_query}" > ${sql_query_file}

command="[[ ! -f ${output_file} ]] \
    && wget 'https://github.com/duckdb/duckdb/releases/download/v1.3.1/duckdb_cli-linux-amd64.zip' \
    && unzip -p duckdb_cli-linux-amd64.zip > ${SCRIPT_DIR}/duckdb \
    && chmod +x ${SCRIPT_DIR}/duckdb \
    && rm duckdb_cli-linux-amd64.zip \
    && ${SCRIPT_DIR}/duckdb < ${sql_query_file} \
    && mv ${tmp_file} ${output_file} \
    && rm ${sql_query_file} \
    && rm duckdb \
    || echo '${output_file} already exists' " 


if [ -n "$debug" ];then
    echo "$command"
else  
    echo                       >&2
    echo "${command}"          >&2
    echo                       >&2
    echo '-------------------' >&2
    eval "$command"
fi
