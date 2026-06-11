#!/usr/bin/env bash

accession="$1"

datasets download genome accession ${accession} --filename ${accession}.zip \
    && unzip -p ${accession}.zip "ncbi_dataset/data/${accession}/*.fna" 