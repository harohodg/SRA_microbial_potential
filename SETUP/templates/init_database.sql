-- Hierarchy of data sources for length calculations
CREATE TYPE genome_type AS  ENUM 
(
    'refseq_reference_genome', 
    'refseq_representative_genome',
    'refseq',
    'genbank_reference_genome',
    'genbank_representative_genome',
    'genbank'
);

-- ==================================================================================
-- Some useful data views
-- ==================================================================================

-- Genomic Length Data, accession dropped, refseq_category and source_database converted to source_label
CREATE VIEW LENGTH_DATA AS 
(
    SELECT 
        tax_id, 
        concat_ws('_', 
                  lower( replace(source_database,'SOURCE_DATABASE_','') ), 
                  lower( replace(refseq_category, ' ','_')) 
                 ) AS genome_source_label,
        sequence_length 
    FROM genomic_data
);


-- For any given tax id who is the associated root taxonomy
CREATE VIEW ROOT_TAXONOMY_LABELS AS
(
    WITH RECURSIVE root_taxonomy_tree(tax_id, rank, sci_name, root_tax_id, root_taxonomy_label) AS 
    (
        SELECT 
            tax_id,
            rank,
            sci_name,
            tax_id,
            sci_name 
        -- Only want one of "other entries", "unclassified entries", "Eukaryota",  "Bacteria", "Archaea", or "Viruses"               
        FROM TAXONOMY_data WHERE (parent_tax_id = 1 and tax_id != 131567) or parent_tax_id = 131567
        
        UNION ALL   
        
        SELECT 
            taxonomy_data.tax_id, 
            taxonomy_data.rank, 
            taxonomy_data.sci_name,
            root_taxonomy_tree.root_tax_id,
            root_taxonomy_tree.root_taxonomy_label,
        FROM taxonomy_data, root_taxonomy_tree 
        WHERE taxonomy_data.parent_tax_id = root_taxonomy_tree.tax_id 
    ) 
    SELECT * FROM root_taxonomy_tree
);


-- For each scientific name what are the root taxonomies
CREATE VIEW TAXONOMY_LABELS AS
(
    SELECT
        sci_name,
        array_agg(rank                ORDER BY root_taxonomy_label) AS ranks,
        array_agg(tax_id              ORDER BY root_taxonomy_label) AS tax_ids,
        array_agg(root_taxonomy_label ORDER BY root_taxonomy_label) AS root_taxonomy_labels,
    FROM 
        ROOT_TAXONOMY_LABELS
    GROUP BY sci_name
);


-- SRA meta data with what was sequenced root taxonomy appended
CREATE VIEW LABELED_SRA_meta_data AS
(
    SELECT
        SRA_meta_data.accession AS SRA_accession,
        biosample,
        bioproject,
        experiment,
        average_read_length,
        assay_type,
        platform,
        num_bases AS dataset_size,
        organism AS what_was_sequenced,

        analyzed_spot_count,
        total_spot_count,

        IFNULL(TAXONOMY_LABELS.ranks, [])                    AS what_was_sequenced_ranks,
        IFNULL(TAXONOMY_LABELS.tax_ids, [])                  AS what_was_sequenced_tax_ids,
        IFNULL(TAXONOMY_LABELS.root_taxonomy_labels, [])     AS what_was_sequenced_root_taxonomy_labels,
    FROM 
        SRA_meta_data 
        LEFT JOIN
        TAXONOMY_LABELS
        ON (SRA_meta_data.organism = TAXONOMY_LABELS.sci_name)
        LEFT JOIN 
        STAT_meta_data
        ON (SRA_meta_data.accession = STAT_meta_data.accession)
);

-- ==================================================================================
-- Some useful macros
-- ==================================================================================

-- For any given taxonomy rank who are its children
-- Example : taxonomy_parents('species') will return who is the nearest parent species for all tax ids which are species or lower
CREATE MACRO taxonomy_parents(target_rank) AS TABLE
(
    WITH RECURSIVE parent_taxonomy_ids(tax_id, rank, sci_name, parent_tax_id, parent_rank, parent_sci_name) AS 
    (
        SELECT 
            tax_id,
            rank,
            sci_name,
            tax_id,
            rank,
            sci_name 
        FROM taxonomy_data
        WHERE rank = target_rank
        
        UNION ALL
        
        SELECT 
            taxonomy_data.tax_id,
            taxonomy_data.rank,
            taxonomy_data.sci_name,
            parent_taxonomy_ids.parent_tax_id, 
            parent_taxonomy_ids.parent_rank,
            parent_taxonomy_ids.parent_sci_name
        FROM taxonomy_data, parent_taxonomy_ids 
        WHERE taxonomy_data.parent_tax_id = parent_taxonomy_ids.tax_id
    )
    SELECT * FROM parent_taxonomy_ids
);


-- For a given taxid what tax ids have said taxid as an ancestor
CREATE MACRO taxonomy_children(target_tax_id) AS TABLE
(
    WITH RECURSIVE taxonomy_tree(tax_id, root_tax_id) AS 
    (
        SELECT 
            target_tax_id,
            target_tax_id          
        
        UNION ALL   
        
        SELECT 
            taxonomy_data.tax_id, 
            taxonomy_tree.root_tax_id,
        FROM taxonomy_data, taxonomy_tree 
        WHERE taxonomy_data.parent_tax_id = taxonomy_tree.tax_id 
    ) 
    SELECT * FROM taxonomy_tree
);

--Map all GenBank/RefSeq genomes to the nearest parent rank
--And filter for unique tax_id biosample sets
CREATE MACRO SEQUENCING_PROJECTS(target_rank) AS TABLE
(
    SELECT 
        biosample, 
        LIST( DISTINCT IFNULL(parent_tax_id, tax_id) ) AS tax_ids 
    FROM 
        genomic_data 
        LEFT JOIN 
        taxonomy_parents(target_rank)
        USING (tax_id)
    WHERE biosample IS NOT NULL
    GROUP BY biosample
);



-- STAT data mapped to nearest target_rank 
CREATE MACRO MAPPED_STAT_DATA(target_rank, target_root_taxonomy) AS TABLE
(
    SELECT
        tax_id,
        accession,
        parent_tax_id,
        total_count AS num_reads,
        ROOT_TAXONOMY_LABELS.rank,
        IFNULL(root_taxonomy_label, 'UNKNOWN') AS root_taxonomy,
    FROM 
        STAT_data 
        LEFT JOIN 
        taxonomy_parents(target_rank)
        USING (tax_id)
        LEFT JOIN
        ROOT_TAXONOMY_LABELS
        USING (tax_id)
    WHERE 
        STAT_data.rank = target_rank
        AND
        root_taxonomy = target_root_taxonomy
);



-- STAT data mapped to nearest target rank
-- with read counts rolled up by tax_id, sra accession
-- AND tax_id rank tacked on
CREATE MACRO SUMMARIZED_STAT_DATA(target_rank, target_root_taxonomy) AS TABLE
(

    SELECT
        IFNULL(parent_tax_id, tax_id) AS tax_id,
        accession AS SRA_accession,
        SUM(num_reads) AS num_reads,
        COUNT(*) AS num_predictions,
        
        CASE
            WHEN parent_tax_id IS NOT NULL THEN target_rank
            ELSE rank
        END AS rank,
        
        root_taxonomy
    FROM MAPPED_STAT_DATA(target_rank, target_root_taxonomy)
    GROUP BY ALL
);



-- Length data mapped to nearest target rank
-- With ranking value based on genome source
-- STAT data mapped to nearest target_rank 
CREATE MACRO MAPPED_LENGTH_DATA(target_rank) AS TABLE
(
    SELECT
        tax_id, 
        parent_tax_id,
        genome_source_label,
        enum_code(genome_source_label::genome_type) AS genome_source_rank,
        sequence_length
    FROM 
        LENGTH_DATA 
        LEFT JOIN 
        taxonomy_parents(target_rank) 
        USING (tax_id)
);


-- Calculate mean length etc based on parent taxid
CREATE MACRO RANKED_LENGTHS(target_rank) AS TABLE
(
    SELECT
        IFNULL(parent_tax_id, tax_id) AS tax_id,
        genome_source_label,
        genome_source_rank,
        COUNT(*)              AS num_genomes,
        MEAN(sequence_length) AS mean_genome_length,
        MAX(sequence_length)  AS max_genome_length,
        MIN(sequence_length)  AS min_genome_length,
        stddev_pop(sequence_length)  AS population_stddev_genome_length,
        stddev_samp(sequence_length) AS sample_stddev_genome_length,
    FROM MAPPED_LENGTH_DATA(target_rank)
    GROUP BY ALL
);

-- Filter the ranked data and return the 'best' genome length per target_rank tax_id
CREATE MACRO FILTERED_LENGTHS(target_rank) AS TABLE
(
    SELECT 
        tax_id,
        FIRST(genome_source_label ORDER BY genome_source_rank ASC)             AS genome_source_label,
        FIRST(mean_genome_length  ORDER BY genome_source_rank ASC)             AS mean_genome_length,
        FIRST(max_genome_length   ORDER BY genome_source_rank ASC)             AS max_genome_length,
        FIRST(min_genome_length   ORDER BY genome_source_rank ASC)             AS min_genome_length,
        FIRST(num_genomes         ORDER BY genome_source_rank ASC)             AS num_genomes,
        FIRST(population_stddev_genome_length ORDER BY genome_source_rank ASC) AS population_stddev_genome_length,
        FIRST(sample_stddev_genome_length     ORDER BY genome_source_rank ASC) AS sample_stddev_genome_length,
    FROM RANKED_LENGTHS(target_rank)
    GROUP BY tax_id
);


-- Count RefSeq, GenBank datasets based on their nearest mapped parent rank
CREATE MACRO REFSEQ_GENBANK_COUNTS(target_rank) AS TABLE
(   
     WITH mapped_data AS 
    (
        SELECT 
            IFNULL(parent_tax_id, tax_id) AS tax_id,
            genome_source_label,
            sequence_length
        FROM MAPPED_LENGTH_DATA(target_rank)
    ), PIVOTED_DATA AS
    (
        PIVOT 
        mapped_data ON genome_source_label 
        IN 
        (
            'refseq_reference_genome', 
            'refseq_representative_genome',
            'refseq',
            'genbank_reference_genome',
            'genbank_representative_genome',
            'genbank',
        ) 
        USING COUNT(sequence_length)
    )
    SELECT
        *,
        refseq_reference_genome  + refseq_representative_genome  + refseq     AS num_refseq_genomes,
        genbank_reference_genome + genbank_representative_genome + genbank    AS num_genbank_genomes,
    FROM PIVOTED_DATA
);

-- RefSeq, GenBank, datasets counts with root taxonomy labels and the stats for the "best" genome for the taxid
CREATE MACRO LABELED_REFSEQ_GENBANK_COUNTS(target_rank) AS TABLE
(
    SELECT 
        counts.*,
        lengths.* EXCLUDE(tax_id),
        ROOT_TAXONOMY_LABELS.root_taxonomy_label AS root_taxonomy,
        ROOT_TAXONOMY_LABELS.rank,
        ROOT_TAXONOMY_LABELS.sci_name,
    FROM 
        REFSEQ_GENBANK_COUNTS(target_rank) AS counts
        JOIN 
        FILTERED_LENGTHS(target_rank) AS lengths
        USING (tax_id)
        LEFT JOIN 
        ROOT_TAXONOMY_LABELS 
        USING (tax_id)
);