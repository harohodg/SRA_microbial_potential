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


CREATE TEMP TABLE mapped_reads AS 
(
    SELECT * FROM read_csv('{mapped_reads_file}')
);

CREATE TEMP TABLE assembled_contigs AS 
(
    SELECT * FROM read_csv('{megahit_assemblies_file}')
);


CREATE TEMP TABLE binned_contigs AS 
(
    SELECT * FROM read_csv('{binned_assemblies_file}')
);

CREATE TEMP TABLE size_filtered_contigs AS
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
    WITH stage_01 AS
    (
        SELECT
            *
        FROM 
            mapped_reads
            JOIN 
            pipeline_input 
            USING (SRA_accession, reference_accession)
    ), stage_02 AS
    (
        SELECT
            *
        FROM
        assembled_contigs
        FULL JOIN  size_filtered_contigs USING (reference_accession, group_label)
        FULL JOIN  binned_contigs        USING (reference_accession, group_label)
    ), stage_03 AS
    (
        SELECT
            *
        FROM stage_01 FULL JOIN stage_02 USING (reference_accession, group_label)   
    )

    SELECT
        reference_accession, 
        group_label,
        ARRAY_agg(SRA_accession ORDER BY SRA_accession ASC)  AS grouped_mapped_SRA_accession,
        SUM(mapped_reads_num_files)  AS mapped_reads_num_files,
        SUM(mapped_reads_num_seqs)   AS mapped_reads_num_seqs,
        SUM(mapped_reads_sum_len)    AS mapped_reads_sum_len,
        MIN(mapped_reads_min_len)    AS mapped_reads_min_len,
        MAX(mapped_reads_max_len)    AS mapped_reads_max_len,
        stage_03.* EXCLUDE (SRA_accession, reference_accession, group_label, mapped_reads_num_files, mapped_reads_num_seqs, mapped_reads_sum_len, mapped_reads_min_len, mapped_reads_max_len)
    FROM stage_03
    GROUP BY ALL
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
    WITH stage_01 AS
    (
        SELECT
            reference_accession,
            group_label,
            array_agg( COLUMNS(* EXCLUDE(reference_accession, group_label, STAT_species_tax_id ) ) ORDER BY SRA_accession ASC) AS 'grouped_\0' 
        FROM
            pipeline_input
            FULL JOIN
            STAT_data
            USING (SRA_accession, reference_accession)
            FULL JOIN
            SRA_meta_data
            USING (SRA_accession)
        GROUP BY ALL
    )
    SELECT 
        *  
    FROM 
        stage_01
        FULL JOIN
        reference_genomes_data
        USING (reference_accession)
);

CREATE TEMP TABLE pipeline_output_data AS 
(
SELECT
    *
FROM    
    intermediate_data
    FULL JOIN
    checkm_results
    USING (reference_accession, group_label)
    FULL JOIN
    global_ANI_results
    USING (reference_accession, group_label)
);

CREATE TEMP TABLE fully_merged_data AS 
(
    SELECT
        *
    FROM
        input_meta_data
        FULL JOIN  
        pipeline_output_data
        USING (reference_accession, group_label)
);

-- Export intermediate / final files
COPY intermediate_data      TO '{intermediate_data_output_file}';
COPY reference_genomes_data TO '{reference_genomes_data_output_file}';
COPY input_meta_data        TO '{input_meta_data_output_file}';
COPY pipeline_output_data   TO '{pipeline_output_data_output_file}';
COPY fully_merged_data      TO '{fully_merged_data_output_file}';