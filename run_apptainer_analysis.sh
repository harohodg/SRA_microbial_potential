#!/bin/bash

#Script which launches either assembly_pipeline.sh or logan_screen.sh inside
#sraminer apptainer container

#Author : Harold Hodgins <hhodgins@uwaterloo.ca>

#History:
#   Version 0.0.0 : November 26, 2025
#       - sufficiently stable
#       - minimial error checking

VERSION='0.0.0'
SCRIPT_DIR=$(dirname "$(realpath "$0")")

>&2 echo "run_apptainer_analysis.sh version $VERSION"

#Script usage
print_help() {
    cat << EOF
Usage: $0 [options] <pipeline (assembly_pipeline|logan_contigs_screen|logan_unitigs_screen)> <pipeline_input> <output_folder> [additional flags to pass to program]

Options:
    -h or --help      Show this help message
    -d or --debug     Print what would have been run without actually running it
    --reference_genomes_cache /path/to/reference/genomes/cache
    --logan_data_cache        /path/to/logan/data/cache
EOF
}

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
        -d)
            debug_mode=true
            shift
            ;;
        --debug)
            debug_mode=true
            shift
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

#Partially validate remaining inputs
if [[ "$#" -lt 3 ]]; then
    echo 'Incorrect number of arguments.'
    print_help
    exit 1
else
    target_pipeline="$1"
    [[ "$target_pipeline" == "assembly_pipeline" ]] || [[ "$target_pipeline" == "logan_contigs_screen" ]] || [[ "$target_pipeline" == "logan_unitigs_screen" ]] || { echo "${target_pipeline} is not 'assembly_pipeline' or 'logan_contigs_screen' or 'logan_unitigs_screen'"; exit 1; }

    pipeline_input=$(realpath "$2")
    output_folder=$(realpath --canonicalize-missing "$3")

    shift 3

    additional_parameters="${@}"
fi

tmp_output_folder="${output_folder}.partial"
apptainer_mounts="--bind ${pipeline_input}:/pipeline_input.csv --bind ${tmp_output_folder}:/output_folder "
apptainer_mounts+="${reference_genomes_cache:+--bind ${reference_genomes_cache}:/reference_genomes_cache} ${logan_data_cache:+--bind ${logan_data_cache}:/logan_data_cache}"

apptainer_container="${SCRIPT_DIR}/SRAminer.sif"
pipeline_arguments="${additional_parameters} $([[ $target_pipeline =~ ^[^_]+_([^_]+)_ ]] && echo ${BASH_REMATCH[1]})"
pipeline_arguments+="${reference_genomes_cache:+--reference_genomes_cache /reference_genomes_cache} ${logan_data_cache:+--logan_data_cache /logan_data_cache}"
pipeline_arguments+=" /pipeline_input.csv /output_folder"

[ "$target_pipeline" != "assembly_pipeline" ] && target_pipeline="logan_screen"


command="mkdir -p ${tmp_output_folder} \
    && apptainer run --app ${target_pipeline} ${apptainer_mounts} ${apptainer_container} ${pipeline_arguments}  \
    && mv ${tmp_output_folder} ${output_folder}"


if [ "$debug_mode" = true ]; then
    echo "$command"
else  
    echo                       >&2
    echo "${command}"          >&2
    echo                       >&2
    echo '-------------------' >&2
    eval "$command"
fi