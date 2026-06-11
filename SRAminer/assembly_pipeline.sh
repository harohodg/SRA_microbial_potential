#!/bin/bash

#Script which launches a nextflow pipeline which runs a set of SRA
#datasets through meta-genomic assembly, binning, and checkm analysis.

#Author : Harold Hodgins <hhodgins@uwaterloo.ca>

#History:
#   Version 0.0.0 : January 31, 2025
#       - sufficiently stable
#   Version 0.0.1 : June 26, 2025
#       - added profile flag
#       - added checkm database flag
#       - added reference_genome_cache flag


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


>&2 echo "assembly_pipeline.sh version $VERSION"

#Script usage
print_help() {
    cat << EOF
Usage: $0 [options] <downloads_files> <output_folder> [nextflow scratch]

Options:
    -h or --help      Show this help message
    -t or --test      Run Nextflow script in stub mode (overrides -p)
    -d or --debug     Print what would have been run without actually runing it
    -r or --resume    Resume a previous Nextflow run
    -p or --profile   Which nextflow profile to use (default standard which runs locally)

    --checkm_database path/to/checkm/database/file
    --reference_genomes_cache /path/to/reference/genomes/cache

    --prefetch_datasets lite|full|FALSE  Prefetch SRA data using light or full quality scores
    --extract_reads SE|PE|FALSE          Extract reads in SE or PE format
    --mapped_reads  SE|PE                Save mapped reads in SE or PE format (default SE)
    --ANI_threshold #              (0-100 : default 95%)
    --percent_identity_threshold # (0-100 : default 95%)
    --max_num_data_slices # >= 1   (the maximum number of slices to split each dataset into, default 1) 
    --min_data_slice_size # >= 1   (the minimum number of spots per slice, default 1E6)

    If prefetch is not set and extract_reads is then reads will be streamed while extracting.
    If prefetch is not set and extract_reads is not set reads will be streamed while mapping.
EOF
}

# Default values
test_mode=false
debug_mode=false
resume=false
profile=standard
prefetch_datasets=false
extract_reads=false
mapped_reads=SE
ANI_threshold=95
percent_identity_threshold=95
max_num_data_slices=1
min_data_slice_size=1000000
show_help=false
checkm_database=''
reference_genomes_cache=''

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
        --prefetch_datasets)
            if [ -n "$2" ]; then
                prefetch_datasets="$2"
                shift 2
            else
                echo "Error: --prefetch_datasets requires a value. lite or full" >&2
                exit 1
            fi
            ;;
        --extract_reads)
            if [ -n "$2" ]; then
                extract_reads="$2"
                shift 2
            else
                echo "Error: --extract_reads requires a value. SE or PE" >&2
                exit 1
            fi
            ;;
        --mapped_reads)
            if [ -n "$2" ]; then
                mapped_reads="$2"
                shift 2
            else
                echo "Error: --mapped_reads requires a value. SE or PE" >&2
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
        --percent_identity_threshold)
            if [ -n "$2" ]; then
                percent_identity_threshold="$2"
                shift 2
            else
                echo "Error: --percent_identity_threshold requires a value" >&2
                exit 1
            fi
            ;;
        --max_num_data_slices)
            if [ -n "$2" ]; then
                max_num_data_slices="$2"
                shift 2
            else
                echo "Error: --max_num_data_slices requires a value" >&2
                exit 1
            fi
            ;;
        --min_data_slice_size)
            if [ -n "$2" ]; then
                min_data_slice_size="$2"
                shift 2
            else
                echo "Error: --min_data_slice_size requires a value" >&2
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
        --checkm_database)
            if [ -n "$2" ]; then
                checkm_database=$(realpath "$2")
                shift 2
            else
                echo "Error: --checkm_database requires a value." >&2
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
if [[ "$#" -lt 2 ]]; then
    echo 'Incorrect number of arguments.'
    print_help
    exit 1
else
    downloads_file=$(realpath "$1")
    output_folder=$(realpath --canonicalize-missing "$2")
    NEXTFLOW_SRATCH_DIRECTORY=${3:-"${output_folder}/.nextflow_SRA_analysis"}
fi




#Set flags to pass to nextflow
[ "$profile" != '' ] && profile_flag="-profile $profile"
[ "$resume" = true ] && resume_flag="-resume"
[ "$test_mode" = true ] && profile_flag="-stub -profile testing"

prefetch_flag="--prefetch_datasets ${prefetch_datasets}"
reads_flag="--extract_reads ${extract_reads}"
mapped_reads_flag="--mapped_reads ${mapped_reads}"

ANI_threshold_flag="--ANI_threshold ${ANI_threshold}"
percent_identity_flag="--percent_identity_threshold ${percent_identity_threshold}"
max_num_chuncks_flag="--max_num_data_slices ${max_num_data_slices}"
min_data_slice_size_flag="--min_data_slice_size ${min_data_slice_size}"
[ "$reference_genomes_cache" != '' ] && reference_genomes_cache_flag="--reference_genomes_cache ${reference_genomes_cache}"


[ "$checkm_database" != '' ] && database_var="CHECKM2DB='${checkm_database}'"

job_flags="${ANI_threshold_flag} ${percent_identity_flag} ${resume_flag} ${profile_flag} ${prefetch_flag} ${reads_flag} ${mapped_reads_flag} ${max_num_chuncks_flag} ${min_data_slice_size_flag}"

[ "$checkm_database" == '' ]  && [[ -f ${SCRIPT_DIR}/CheckM_database/uniref100.KO.1.dmnd ]] && database_var="CHECKM2DB='${SCRIPT_DIR}/CheckM_database/uniref100.KO.1.dmnd'"
command="NXF_OPTS='-Xms1g -Xmx4g' ${database_var} \
NXF_WORK=${NEXTFLOW_SRATCH_DIRECTORY} \
NFX_TEMP=${NEXTFLOW_SRATCH_DIRECTORY} \
nextflow run ${SCRIPT_DIR}/assembly_pipeline.nf ${job_flags} \
--downloads_file ${downloads_file} \
--output_folder ${output_folder} \
${reference_genomes_cache_flag} \
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
