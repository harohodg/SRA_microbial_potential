-- Load in the raw data
CREATE TEMP TABLE pipeline_input AS
(
    SELECT * FROM read_csv('{pipeline_input_file}')
);



CREATE TEMP TABLE SRA_meta_data AS
(
    SELECT * FROM read_parquet('{SRA_meta_data_file}')
);

CREATE TEMP TABLE STAT_data AS
(
    SELECT * FROM read_parquet('{STAT_data_file}')
);

CREATE TEMP TABLE genomes_meta_data AS
(
    SELECT * FROM read_parquet('{genomes_meta_data_file}')
);



CREATE TEMP TABLE binned_assemblies AS 
(
    SELECT * FROM read_csv('{binned_assemblies_file}')
);

CREATE TEMP TABLE size_filtered AS
(
    SELECT * FROM read_csv('{size_filtered_file}')
);

CREATE TEMP TABLE genomes_data AS
(
    SELECT * FROM read_csv('{genomes_data_file}')
);


CREATE TEMP TABLE checkm_results AS
(
    SELECT * FROM read_csv('{checkm_results_file}')
);

CREATE TEMP TABLE global_ANI_results AS
(
    SELECT * FROM read_csv('{global_ANI_results_file}')
);



-- Merge the various tables together
CREATE TEMP TABLE intermediate_data AS
(
    SELECT
        *
    FROM
        binned_assemblies
        FULL JOIN
        size_filtered
        USING (SRA_accession, data_type)
);

CREATE TEMP TABLE reference_genomes_data AS 
(
    WITH tmp_data AS 
    (
    SELECT
        COLUMNS('reference(.*)') AS 'reference_genome\1'
    FROM
        genomes_meta_data
        JOIN
        genomes_data
        USING (reference_accession)
    )
    SELECT
        reference_genome_accession AS reference_accession,
        * EXCLUDE reference_genome_accession
    FROM tmp_data
);


CREATE TEMP TABLE input_meta_data AS 
(
    SELECT
        *
    FROM
        SRA_meta_data
        JOIN
        STAT_data
        USING (SRA_accession)
);

CREATE TEMP TABLE pipeline_output_data AS 
(
    SELECT
        *
    FROM
        checkm_results
        FULL JOIN
        global_ANI_results
        USING (SRA_accession, reference_accession, data_type)
);

CREATE TEMP TABLE fully_merged_data AS 
(
    WITH stage_01 AS 
    (
        SELECT
            *
        FROM
            pipeline_input
            LEFT JOIN
            input_meta_data
            USING (SRA_accession, reference_accession)
    ), stage_02 AS
    (
        SELECT
            *
        FROM
            stage_01
            LEFT JOIN
            reference_genomes_data
            USING (reference_accession)
    ), stage_03 AS
    (
        SELECT
            *
        FROM
            pipeline_output_data
            FULL JOIN
            intermediate_data
            USING (SRA_accession, reference_accession, data_type)
    ), stage_04 AS
    (
        SELECT
            *
        FROM
            stage_02
            LEFT JOIN
            stage_03
            USING (SRA_accession, reference_accession)
    )
    SELECT
        *
    FROM stage_04
);

-- Export intermediate / final files
COPY intermediate_data      TO '{intermediate_data_output_file}';
COPY reference_genomes_data TO '{reference_genomes_data_output_file}';
COPY input_meta_data        TO '{input_meta_data_output_file}';
COPY pipeline_output_data   TO '{pipeline_output_data_output_file}';
COPY fully_merged_data      TO '{fully_merged_data_output_file}';