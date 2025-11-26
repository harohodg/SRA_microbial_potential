# SRAminer
A set of nextflow pipelines which applies a hybrid assembly method to a collection of SRA datasets.
All use conda enviroments and can be run locally or using Flux (with Docker). For a small # of datasets the
run time isn't substantially different, but the Flux version returns intermediate results as
it runs rather than all at once at the end. An optional set of caching folders can be used to globally
cache the reference genomes and logan data. 

Caveats : 
- The nextflow scratch folder must be on the same filesystem as the output folder if not using docker
- Flux has only been tested with the docker version.
- The docker version output files are owned by root and have to be reclaimed afterwards.

### Requirements
1) local compute : ok for a few smallish calculations
- nextflow : tested with version 25.04.4
- zstd     : tested with Zstandard CLI (64-bit) v1.5.6
- conda    : tested with version 24.11.1
- unzip    : tested with version 6.00


```
./init_cache.sh #Not strictly necessary, nextflow will populate the cache on the first full run
```


OR 

2) docker : better for contraining resources to keep the pipeline from breaking your system
- docker : tested with version 27.5.1

```
#Optional, pre-fetch databases and initialize cache
./init_cache.sh #Might fail if your conda version is different than the one in the docker image

OR
./download_Checkm_database.sh 
./download_logan_accessions.sh

docker build -t sraminer .
```


### Running the pipelines

To run with tmux and independent logging run something like `tmux new-session -s some_name 'command to run | tee some_log_file.log'`

1. Assembly variant
- Local (no caching)
`./assembly_pipeline.sh --max_num_data_slices 10 test_downloads.csv TESTING/pipeline_test | tee pipeline_test.log`

- Local (with caching)
`./assembly_pipeline.sh --reference_genomes_cache GENOMES_CACHE  --max_num_data_slices 10 test_downloads.csv TESTING/pipeline_test | tee pipeline_test.log`

- Docker (no caching)
`./run_docker_analysis.sh  --docker_flags '--volume /data:/data --volume /scratch:/scratch --cpus=32' "assembly_pipeline.sh --max_num_data_slices 10 --profile FLUX $(pwd)/test_downloads.csv /scratch/assembly_test /scratch/nextflow_scratch" | tee /scratch/pipeline_test.log`

- Docker (with caching) 
`./run_docker_analysis.sh  --docker_flags '--volume /data:/data --volume /scratch:/scratch --cpus=32' "assembly_pipeline.sh --reference_genomes_cache /scratch/GENOMES_CACHE --max_num_data_slices 10 --profile FLUX $(pwd)/test_downloads.csv /scratch/assembly_test-cached /scratch/nextflow_scratch" | tee /scratch/pipeline_test-cached.log`

2. Logan screen variant
- Local (no caching)
`./logan_screen.sh contigs test_downloads.csv TESTING/logan_contigs_test`

- Local (fully cached)
`./logan_screen.sh --reference_genomes_cache GENOMES_CACHE  --logan_data_cache LOGAN_CACHE contigs test_downloads.csv TESTING/logan_contigs_test`

- Docker (no cache)
`./run_docker_analysis.sh  --docker_flags '--volume /data:/data --volume /scratch:/scratch --cpus=32' "logan_screen.sh --profile FLUX contigs $(pwd)/test_downloads.csv /scratch/TESTING/logan_contigs_test" | tee /scratch/logan_test.log`

- Docker (fully cached)
`./run_docker_analysis.sh  --docker_flags '--volume /data:/data --volume /scratch:/scratch --cpus=32' "logan_screen.sh --reference_genomes_cache /scratch/GENOMES_CACHE  --logan_data_cache /scratch/LOGAN_CACHE --profile FLUX contigs $(pwd)/test_downloads.csv /scratch/TESTING/logan_contigs_test" | tee /scratch/logan_test-cached.log`