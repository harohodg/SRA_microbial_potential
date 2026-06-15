WITH pipeline_input_data AS
(
    SELECT 
        DISTINCT SRA_accession, reference_accession
    FROM read_csv('{pipeline_input_file}')
), reference_genomes_meta_data AS
(
    SELECT
        DISTINCT reference_species_tax_id, reference_accession
    FROM read_parquet('{reference_genomes_meta_data}') 
), labeled_input_data AS
(
    SELECT
        SRA_accession,
        reference_accession,
        reference_species_tax_id AS species_tax_id
    FROM pipeline_input_data JOIN reference_genomes_meta_data 
    USING (reference_accession)
)
SELECT
    STAT_data.SRA_accession,
    reference_accession,
    species_tax_id  AS STAT_species_tax_id,
    num_reads       AS STAT_num_reads,
    num_predictions AS STAT_num_predictions,
    root_taxonomy   AS STAT_root_taxonomy
FROM read_parquet('{STAT_data}') AS STAT_data
JOIN 
    labeled_input_data 
    ON  (
        labeled_input_data.species_tax_id = STAT_data.tax_id 
        AND 
        labeled_input_data.SRA_accession = STAT_data.SRA_accession 
        )
