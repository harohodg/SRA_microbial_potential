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
        IFNULL(root_taxonomy_label, 'UNKNOWN') AS root_taxonomy, 
        tax_id,
        num_genomes,
        PARENT_SPECIES.rank, 
        parent_tax_id AS species_tax_id, 
        source_database,
        CASE
            WHEN root_taxonomy_label IS NULL THEN 'UNKNOWN'
            WHEN parent_tax_id IS NULL THEN 'above species' 
            WHEN tax_id = parent_tax_id THEN 'species' 
            WHEN tax_id != parent_tax_id THEN 'below species' 
        END AS tax_id_rank
    FROM 
        raw_counts 
        LEFT JOIN 
        ROOT_TAXONOMY_LABELS 
        USING (tax_id) 
        LEFT JOIN 
        PARENT_SPECIES 
        USING (tax_id)

    UNION ALL

    SELECT 
        IFNULL(root_taxonomy_label, 'UNKNOWN') AS root_taxonomy, 
        parent_tax_id,
        SUM(num_genomes) AS num_genomes,
        'species' AS rank, 
        parent_tax_id AS species_tax_id, 
        source_database,
        'species OR below' AS tax_id_rank
    FROM 
        raw_counts 
        LEFT JOIN 
        ROOT_TAXONOMY_LABELS 
        USING (tax_id) 
        LEFT JOIN 
        PARENT_SPECIES 
        USING (tax_id)   
    GROUP BY root_taxonomy_label, parent_tax_id, source_database
    
), genome_counts AS
(
    SELECT
        root_taxonomy,
        REPLACE(source_database, 'SOURCE_DATABASE_', '') AS source_database,
        tax_id_rank,
    
        COUNT( DISTINCT tax_id ) AS num_tax_ids,
        SUM(num_genomes) AS num_genomes,
    FROM labeled_counts
    GROUP BY root_taxonomy, source_database, tax_id_rank
), singleton_genome_counts AS
(
    SELECT
        root_taxonomy,
        REPLACE(source_database, 'SOURCE_DATABASE_', '') AS source_database,
        tax_id_rank,
    
        COUNT( DISTINCT tax_id ) AS num_tax_ids,
    FROM labeled_counts
    WHERE num_genomes = 1
    GROUP BY root_taxonomy, source_database, tax_id_rank
)
SELECT
    source_database,
    root_taxonomy,
    tax_id_rank,
    genome_counts.num_tax_ids::INT AS num_tax_ids,
    genome_counts.num_genomes::INT AS num_genomes,
    singleton_genome_counts.num_tax_ids::INT  AS num_singletons
FROM
    genome_counts FULL JOIN singleton_genome_counts USING (root_taxonomy, tax_id_rank, source_database)
ORDER BY source_database, root_taxonomy, tax_id_rank;