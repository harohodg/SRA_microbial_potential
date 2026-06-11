#!/usr/bin/env bash


#Author : Harold Hodgins <hhodgins@uwaterloo.ca>

#History:
#    Version 1.0.0 : January 15, 2025
#        - functional code with minimal error checking
#
#    Version 1.1.0 : October 16, 2025
#        - added optional alternative scratch directory

VERSION='1.1.0'
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )


>&2 echo "create_database.sh version $VERSION"

# Echo usage if something isn't right.
usage() { 
    echo "Usage: $0 [-t] <input_folder> <database> [nextflow_scratch_directory]" 1>&2;
    echo "-t : runs nextflow script and only asks for two files per SRA type" 1>&2;
    exit 1; 
}

while getopts ":t" o; do
    case "${o}" in
        t)  
            num_files=2
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

if [[ "$#" -lt 2 ]]; then
    echo 'Incorrect number of arguments.'
    usage
fi


INPUT_FOLDER=$(realpath "$1")
DATABASE=$(realpath --canonicalize-missing "$2")
NEXTFLOW_SRATCH_DIRECTORY=${3:-".nextflow_create_database"}
DATABASE_NAME=$(basename ${DATABASE})
OUTPUT_FOLDER=$(dirname ${DATABASE})
TMP_OUTPUT_FOLDER=${OUTPUT_FOLDER}.partial

num_files_parameter=${num_files+"--num_files 2"}


job_setup="mkdir -p ${TMP_OUTPUT_FOLDER}"
nextflow_setup="NXF_OPTS='-Xms1g -Xmx4g' NXF_WORK=${NEXTFLOW_SRATCH_DIRECTORY} NFX_TEMP=${NEXTFLOW_SRATCH_DIRECTORY}"
nextflow_command="nextflow run create_database.nf --input_folder ${INPUT_FOLDER} --output_folder ${TMP_OUTPUT_FOLDER} --database_name  ${DATABASE_NAME} ${num_files_parameter}"
nextflow_flags="-c ${SCRIPT_DIR}/nextflow.config -resume -with-trace ${TMP_OUTPUT_FOLDER}/nextflow_trace.txt -with-report ${TMP_OUTPUT_FOLDER}/nextflow_report.html -with-timeline ${TMP_OUTPUT_FOLDER}/nextflow_timeline.html -with-dag ${TMP_OUTPUT_FOLDER}/nextflow_flowchart.html"
job_completion="mv ${TMP_OUTPUT_FOLDER} ${OUTPUT_FOLDER}"

job="${job_setup} && ${nextflow_setup} ${nextflow_command} ${nextflow_flags} && ${job_completion}"
#And run the command
eval "${job}"