WITH raw_counts AS
(
    SELECT
        tax_id,
        source_database,
        COUNT(*) AS num_genomes
    FROM genomic_data
    GROUP BY tax_id, source_database
), labeled_counts AS
(
    SELECT 
        root_taxonomy_label AS root_taxonomy, 
        SUM(num_genomes) AS num_genomes,
        parent_tax_id AS species_tax_id, 
        source_database,
    FROM 
        raw_counts 
        JOIN 
        ROOT_TAXONOMY_LABELS 
        USING (tax_id) 
        JOIN 
        PARENT_SPECIES 
        USING (tax_id)
    GROUP BY root_taxonomy, source_database, species_tax_id
)
SELECT
    REPLACE(source_database, 'SOURCE_DATABASE_', '') AS source_database,
    root_taxonomy,
    COUNT( DISTINCT species_tax_id)  AS num_species,
    COUNT( CASE WHEN num_genomes = 1 THEN 1 END ) AS num_singleton_species
FROM
    labeled_counts
GROUP BY root_taxonomy, source_database
ORDER BY source_database, root_taxonomy;