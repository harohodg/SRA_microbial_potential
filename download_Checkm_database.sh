#!/bin/bash

#Script which downloads the checkm2 database
#If not told otherwise will put the results in CheckM_database under the script directory

#Author : Harold Hodgins <hhodgins@uwaterloo.ca>

#History:
#   Version 0.0.0 : October 18, 2024
#       - Functional with minimal error checking


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


VERSION='0.0.0'
SCRIPT_DIR="$(get_script_dir)"
DATABASE_URL='https://zenodo.org/record/5571251/files/checkm2_database.tar.gz?download=1'
DB_NAME='uniref100.KO.1.dmnd'

>&2 echo "download_Checkm_database.sh version $VERSION"

# Echo usage if something isn't right.
usage() { 
    echo "Usage: $0 [-d] [output_folder]" 1>&2; 
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
    output_folder=$(realpath --canonicalize-missing "${1:-$SCRIPT_DIR/CheckM_database}")
fi

database_file="${output_folder}/${DB_NAME}"
tmp_file="${database_file}.partial"

command="[[ ! -f ${database_file} ]] \
    && mkdir -p ${output_folder} \
    && wget -O - '${DATABASE_URL}' | tar --to-stdout -xzvf - CheckM2_database/${DB_NAME} > ${tmp_file} \
    && mv ${tmp_file} ${database_file} \
    || echo 'Database already exists?'"


if [ -n "$debug" ];then
    echo "$command"
else  
    echo                       >&2
    echo "${command}"          >&2
    echo                       >&2
    echo '-------------------' >&2
    eval "$command"
fi
