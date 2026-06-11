# Code for fetching [SRA cloud tables](https://www.ncbi.nlm.nih.gov/sra/docs/sra-cloud-based-examples/) and [summary of GenBank/RefSeq](https://www.ncbi.nlm.nih.gov/datasets/)

Assumes conda, unzip, java, duckdb, and nextflow are already installed

1. Download the latest data
```
./download_data.sh RAW_DATA/

#If you want to compare with gtdb (currently r226)
wget --output-document=ar53_metadata_r226.tsv.gz 'https://data.gtdb.aau.ecogenomic.org/releases/release226/226.0/ar53_metadata_r226.tsv.gz'
wget --output-document=bac120_metadata_r226.tsv.gz 'https://data.gtdb.aau.ecogenomic.org/releases/release226/226.0/bac120_metadata_r226.tsv.gz'
```
Downloading the data (~175 GB) takes ~8 hours (back in 2025). Most of that is the genomic data.
- If I was to redo this, I'd probably use rclone instead of the aws cli. 


2. Extract the data and convert to a duckdb database
See `templates/init_database.sql` for layout, macros etc
```
./create_database.sh RAW_DATA EXTRACTED_DATA/extracted_data.db
```