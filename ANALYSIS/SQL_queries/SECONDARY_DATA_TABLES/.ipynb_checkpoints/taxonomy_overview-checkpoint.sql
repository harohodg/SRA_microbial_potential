WITH taxonomy_labels AS
(
    SELECT
        root_taxonomy_label AS root_taxonomy,
        CASE
            WHEN root_taxonomy_label IS NULL THEN 'UNKNOWN'
            WHEN parent_tax_id IS NULL THEN 'above species' 
            WHEN tax_id = parent_tax_id THEN 'species' 
            WHEN tax_id != parent_tax_id THEN 'below species' 
        END AS tax_id_rank
    FROM 
        ROOT_TAXONOMY_LABELS
        LEFT JOIN
        PARENT_SPECIES
        USING (tax_id)
), tax_id_counts AS
(
    SELECT
        root_taxonomy,
        tax_id_rank,
        COUNT(*) AS num_tax_ids
    FROM taxonomy_labels
    GROUP BY ALL
)
SELECT
    root_taxonomy,
    "below species",
    "species",
    "above species"
FROM
(
    PIVOT
        tax_id_counts
    ON tax_id_rank
    USING IFNULL( SUM(num_tax_ids), 0)::INT
)
ORDER BY "below species" + "species" + "above species" ASC;