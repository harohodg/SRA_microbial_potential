#!/usr/bin/env bash

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


SCRIPT_DIR="$(get_script_dir)"

${SCRIPT_DIR}/download_Checkm_database.sh \
    && ${SCRIPT_DIR}/download_logan_accessions.sh \
    && ${SCRIPT_DIR}/assembly_pipeline.sh --test --max_num_data_slices 2 ${SCRIPT_DIR}/test_downloads.csv ${SCRIPT_DIR}/TESTING/init_pipeline_cache  \
    && ${SCRIPT_DIR}/logan_screen.sh --test contigs ${SCRIPT_DIR}/test_downloads.csv ${SCRIPT_DIR}/TESTING/init_logan_cache \
    && rm -r ${SCRIPT_DIR}/TESTING