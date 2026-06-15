WITH input_data AS
(
    SELECT 
        DISTINCT reference_accession AS accession
    FROM read_csv('{input_file}')
)
SELECT
    parent_species.parent_tax_id    AS reference_species_tax_id,
    genomic_data.accession          AS reference_accession,
    LENGTH(gtdb_species)            AS reference_num_gtdb_species,
    LENGTH(genbank_base_accessions) AS reference_num_gtdb_genomes,
    tax_id          AS reference_original_tax_id,
    biosample       AS reference_biosample,
    bioproject      AS reference_bioproject,
    sequence_length AS reference_genome_size,
    assembly_level  AS reference_assembly_level,
    t1.sci_name AS reference_original_sci_name,
    t1.rank     AS reference_orginal_rank,
    t2.sci_name AS reference_species_sci_name
FROM 
    genomic_data
    JOIN 
    input_data USING (accession)
    JOIN taxonomy_parents('species') AS parent_species USING (tax_id)
    LEFT JOIN read_parquet('{gtdb_data}') AS gtdb_data 
    ON (gtdb_data.tax_id = parent_tax_id )
    LEFT JOIN TAXONOMY_data AS t1
    ON (t1.tax_id = tax_id)
    LEFT JOIN TAXONOMY_data AS t2
    ON (t2.tax_id = parent_species.parent_tax_id)