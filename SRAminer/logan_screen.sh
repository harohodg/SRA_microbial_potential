#!/bin/bash

#Script which launches a nextflow pipeline which runs a set of LOGAN
#datasets through binning, and checkm analysis.

#Author : Harold Hodgins <hhodgins@uwaterloo.ca>

#History:
#   Version 0.0.0 : June 26, 2025
#       - sufficiently stable
#       - based on version 0.0.0 of assembly_pipeline.sh
#   Version 0.0.1 : June 27, 2025
#       - added parameters for reference genome/logan data caches

get_script_dir () {
#Based on https://stackoverflow.com/questions/56962129/how-to-get-original-location-of-script-used-for-slurm-job
#Modified to handle interactive jobs
    if [[ -n "${SLURM_JOB_ID+x}" ]] && [[ "${SLURM_JOB_NAME}" != "interactive" ]] && scontrol --help >/dev/null 2>&1; then
        local THEPATH=$(scontrol show job "$SLURM_JOB_ID" | awk -F= '/Command=/{print $2}') 
    else
        local THEPATH=$(realpath "$0")
    fi
    echo $(dirname ${THEPATH} )
}

VERSION='0.0.1'
SCRIPT_DIR="$(get_script_dir)"


>&2 echo "logan_screen.sh version $VERSION"

#Script usage
print_help() {
    cat << EOF
Usage: $0 [options] <data_type> <downloads_files> <output_folder> [nextflow scratch]

Options:
    -h or --help      Show this help message
    -t or --test      Run Nextflow script in stub mode (overrides --profile)
    -d or --debug     Print what would have been run without actually runing it
    -r or --resume    Resume a previous Nextflow run
    -p or --profile   Which nextflow profile to use (default standard which runs locally)
    --ANI_threshold # (0-100 : default 95%)

    --checkm_database path/to/checkm/database/file
    --reference_genomes_cache /path/to/reference/genomes/cache
    --logan_data_cache        /path/to/logan/data/cache

EOF
}

# Default values
test_mode=false
debug_mode=false
resume=false
profile=standard
extract_reads=false
ANI_threshold=95
checkm_database=''
show_help=false
reference_genomes_cache=''
logan_data_cache=''

# Parse flags
while (( $# > 0 )); do
    case "$1" in
        -h)
            show_help=true
            shift
            ;;
        --help)
            show_help=true
            shift
            ;;
        -t)
            test_mode=true
            shift
            ;;
        --test)
            test_mode=true
            shift
            ;;
        -d)
            debug_mode=true
            shift
            ;;
        --debug)
            debug_mode=true
            shift
            ;;
        -r)
            resume=true
            shift
            ;;
        --resume)
            resume=true
            shift
            ;;
        --checkm_database)
            if [ -n "$2" ]; then
                checkm_database=$(realpath "$2")
                shift 2
            else
                echo "Error: --checkm_database requires a value." >&2
                exit 1
            fi
            ;;
        --ANI_threshold)
            if [ -n "$2" ]; then
                ANI_threshold="$2"
                shift 2
            else
                echo "Error: --ANI_threshold requires a value" >&2
                exit 1
            fi
            ;;
        -p)
            if [ -n "$2" ]; then
                profile="$2"
                shift 2
            else
                echo "Error: -p requires a value" >&2
                exit 1
            fi
            ;;
        --profile)
            if [ -n "$2" ]; then
                profile="$2"
                shift 2
            else
                echo "Error: --profile requires a value" >&2
                exit 1
            fi
            ;;
        --reference_genomes_cache)
            if [ -n "$2" ]; then
                reference_genomes_cache=$(realpath "$2")
                shift 2
            else
                echo "Error: --reference_genomes_cache requires a value." >&2
                exit 1
            fi
            ;;
        --logan_data_cache)
            if [ -n "$2" ]; then
                logan_data_cache=$(realpath "$2")
                shift 2
            else
                echo "Error: --logan_data_cache requires a value." >&2
                exit 1
            fi
            ;;
        --*|-*)
            echo "Error: Unknown option $1" >&2
            print_help
            exit 1
            ;;
        *)  # Save remaining arguments
            break
            ;;
    esac
done

# Show help if requested
if [ "$show_help" = true ]; then
    print_help
    exit 0
fi


#Partially validate remaining inputs
if [[ "$#" -lt 3 ]]; then
    echo 'Incorrect number of arguments.'
    print_help
    exit 1
else
    data_type="$1"
    downloads_file=$(realpath "$2")
    output_folder=$(realpath --canonicalize-missing "$3")
    NEXTFLOW_SRATCH_DIRECTORY=${4:-"${output_folder}/.nextflow_LOGAN_screen"}
fi




#Set flags to pass to nextflow
[ "$profile" != '' ] && profile_flag="-profile $profile"
[ "$resume" = true ] && resume_flag="-resume"
[ "$test_mode" = true ] && profile_flag="-stub -profile testing" 


ANI_threshold_flag="--ANI_threshold ${ANI_threshold}"
[ "$checkm_database" != '' ] && database_var="CHECKM2DB='${checkm_database}'"
[ "$reference_genomes_cache" != '' ] && reference_genomes_cache_flag="--reference_genomes_cache ${reference_genomes_cache}"
[ "$logan_data_cache" != '' ] && logan_data_cache_flag="--logan_data_cache ${logan_data_cache}"

job_flags="${ANI_threshold_flag} ${resume_flag} ${profile_flag}"
[ "$checkm_database" == '' ]  && [[ -f ${SCRIPT_DIR}/CheckM_database/uniref100.KO.1.dmnd ]] && database_var="CHECKM2DB='${SCRIPT_DIR}/CheckM_database/uniref100.KO.1.dmnd'"
command="NXF_OPTS='-Xms1g -Xmx4g' ${database_var} \
    NXF_WORK=${NEXTFLOW_SRATCH_DIRECTORY} \
    NFX_TEMP=${NEXTFLOW_SRATCH_DIRECTORY} \
    nextflow run ${SCRIPT_DIR}/logan_screen.nf ${job_flags} \
    --data_type ${data_type} \
    --downloads_file ${downloads_file} \
    --output_folder ${output_folder} \
    ${reference_genomes_cache_flag} \
    ${logan_data_cache_flag} \
    -c ${SCRIPT_DIR}/nextflow.config \
    -with-trace ${output_folder}/nextflow_trace.txt \
    -with-report ${output_folder}/nextflow_report.html \
    -with-timeline ${output_folder}/nextflow_timeline.html \
    -with-dag ${output_folder}/nextflow_flowchart.html"



if [ "$debug_mode" = true ]; then
    echo "$command"
else  
    echo                       >&2
    echo "${command}"          >&2
    echo                       >&2
    echo '-------------------' >&2
    eval "$command"
fi
