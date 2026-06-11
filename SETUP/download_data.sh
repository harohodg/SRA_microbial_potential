#!/usr/bin/env bash


#Author : Harold Hodgins <hhodgins@uwaterloo.ca>

#History:
#    Version 1.0.0 : January 14, 2025
#        - functional code with minimal error checking


VERSION='1.0.0'
NEXTFLOW_SRATCH_DIRECTORY=".nextflow_data_download_scratch"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DEFAULT_OUTPUT_FOLDER=RAW_DATA/$(date +'%Y_%m_%d')


>&2 echo "download_data.sh version $VERSION"

# Echo usage if something isn't right.
usage() { 
    echo "Usage: $0 [output_folder]" 1>&2;
    exit 1; 
}


if [[ "$#" -ge 2 ]]; then
    echo 'Incorrect number of arguments.'
    usage
fi



output_folder=$(realpath --canonicalize-missing ${1:-$DEFAULT_OUTPUT_FOLDER})
tmp_output_folder=${output_folder}.partial


job_setup="mkdir -p ${tmp_output_folder}"
nextflow_setup="NXF_OPTS='-Xms1g -Xmx4g' NXF_WORK=${NEXTFLOW_SRATCH_DIRECTORY} NFX_TEMP=${NEXTFLOW_SRATCH_DIRECTORY}"
nextflow_command="nextflow run download_data.nf --output_folder ${tmp_output_folder}"
nextflow_flags="-c ${SCRIPT_DIR}/nextflow.config -with-trace ${tmp_output_folder}/nextflow_trace.txt -with-report ${tmp_output_folder}/nextflow_report.html -with-timeline ${tmp_output_folder}/nextflow_timeline.html -with-dag ${tmp_output_folder}/nextflow_flowchart.html"
job_completion="mv ${tmp_output_folder} ${output_folder}"

job="${job_setup} && ${nextflow_setup} ${nextflow_command} ${nextflow_flags} && ${job_completion}"
#And run the command
eval "${job}"
