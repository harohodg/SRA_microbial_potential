WITH intermediate_data AS
(
    SELECT 
        IFNULL(parent_tax_id, tax_id) AS tax_id,
        array_agg( string_split(accession,'.')[1] ) AS base_genbank_accessions, 
    FROM 
        genomic_data 
        LEFT JOIN 
        taxonomy_parents('species') 
        USING (tax_id) 
    WHERE 'GENBANK' IN source_database
    GROUP BY ALL
)
SELECT
    ROOT_TAXONOMY_LABELS.rank,
    ROOT_TAXONOMY_LABELS.sci_name,
    IFNULL(ROOT_TAXONOMY_LABELS.root_taxonomy_label, 'UNKNOWN') AS root_taxonomy,
    intermediate_data.*
FROM 
    intermediate_data
    LEFT JOIN
    ROOT_TAXONOMY_LABELS
    USING (tax_id)