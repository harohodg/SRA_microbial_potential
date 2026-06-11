#!/bin/bash

#Script which launches either assembly_pipeline.sh or logan_screen.sh inside
#sraminer docker container

#Author : Harold Hodgins <hhodgins@uwaterloo.ca>

#History:
#   Version 0.0.0 : July 10, 2025
#       - sufficiently stable
#       - minimial error checking

VERSION='0.0.0'

>&2 echo "run_docker_analysis.sh version $VERSION"

#Script usage
print_help() {
    cat << EOF
Usage: $0 [options] <program> <downloads_files> <output_folder> <nextflow scratch> [additional flags]

Options:
    -h or --help      Show this help message
    -d or --debug     Print what would have been run without actually running it
    --docker_flags 'Any thing else to pass to docker run eg cpus=4'
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
        --docker_flags)
            if [ -n "$2" ]; then
                docker_flags="$2"
                shift 2
            else
                echo "Error: --docker_flags requires a value." >&2
                exit 1
            fi
            ;;
        --flux_flags)
            if [ -n "$2" ]; then
                flux_flags="$2"
                shift 2
            else
                echo "Error: --flux_flags requires a value." >&2
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
if [[ "$#" -lt 1 ]]; then
    echo 'Incorrect number of arguments.'
    print_help
    exit 1
else
    what_to_run="${@}"
fi


command="docker run \
    -it \
    ${docker_flags} \
    sraminer flux start ${flux_flags} \
    ${what_to_run}"


if [ "$debug_mode" = true ]; then
    echo "$command"
else  
    echo                       >&2
    echo "${command}"          >&2
    echo                       >&2
    echo '-------------------' >&2
    eval "$command"
fi