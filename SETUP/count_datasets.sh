#!/usr/bin/env bash

#Author : Harold Hodgins <hhodgins@uwaterloo.ca>

#History:
#    Version 1.0.0 : January 15, 2025
#        - functional code with minimal error checking


VERSION='1.0.0'
NEXTFLOW_SRATCH_DIRECTORY=".nextflow_count_datasets"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )


DEFAULT_SIZE_THRESHOLDS='1000 10000 100000 1000000'
DEFAULT_COVERAGE_THRESHOLDS='1 10 100 1000'
TEST_SIZE_THRESHOLDS='1000 10000'
TEST_COVERAGE_THRESHOLDS='1 10'

>&2 echo "count_datasets.sh version $VERSION"

# Echo usage if something isn't right.
usage() { 
    echo "Usage: $0 [-t] [-b bases_thresholds 'a b c d'] [-c coverage_thesholds 'a b c d'] <extracted_database> <output_folder>" 1>&2;
    echo "-d : prints what would have been run but not actually run it" 1>&2;
    echo "-t : runs the nextflow script and only asks for a single set of thresholds" 1>&2;
    exit 1; 
}



size_thresholds=${DEFAULT_SIZE_THRESHOLDS}
coverage_thresholds=${DEFAULT_COVERAGE_THRESHOLDS}
while getopts ":dtb:c:" o; do
    case "${o}" in
        d)  
            debug=1
            ;;
        t)  
            size_thresholds=${TEST_SIZE_THRESHOLDS}
            coverage_thresholds=${TEST_COVERAGE_THRESHOLDS}
            ;;
        b)
            size_thresholds="$OPTARG"
            ;;
        c)
            coverage_thresholds="$OPTARG"
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

if [[ "$#" -ne 2 ]]; then
    echo 'Incorrect number of arguments.'
    usage
fi


database=$(realpath "$1")
output_folder=$(realpath --canonicalize-missing  "$2")
tmp_output_folder="${output_folder}".partial

job_setup="mkdir -p ${tmp_output_folder}"
nextflow_setup="NXF_OPTS='-Xms1g -Xmx4g' NXF_WORK=${NEXTFLOW_SRATCH_DIRECTORY} NFX_TEMP=${NEXTFLOW_SRATCH_DIRECTORY}"
nextflow_command="nextflow run  ${SCRIPT_DIR}/count_datasets.nf --extracted_database ${database} --output_folder ${tmp_output_folder} --SRA_size_threshold '${size_thresholds}' --genome_coverage_threshold '${coverage_thresholds}'"
nextflow_flags="-c ${SCRIPT_DIR}/nextflow.config -resume -with-trace ${tmp_output_folder}/nextflow_trace.txt -with-report ${tmp_output_folder}/nextflow_report.html -with-timeline ${tmp_output_folder}/nextflow_timeline.html -with-dag ${tmp_output_folder}/nextflow_flowchart.html"
job_completion="mv ${tmp_output_folder} ${output_folder}"

job="${job_setup} && ${nextflow_setup} ${nextflow_command} ${nextflow_flags} && ${job_completion}"

if [ -n "$debug" ];then
    echo "$job"
else  
    echo                       >&2
    echo "${job}"          >&2
    echo                       >&2
    echo '-------------------' >&2
    eval "$job"
fi