SELECT
    tax_id,
    parent_tax_id,
    ROOT_TAXONOMY_LABELS.rank,
    root_taxonomy_label AS root_taxonomy
FROM
    ROOT_TAXONOMY_LABELS
    LEFT JOIN
    taxonomy_parents('species')
    USING (tax_id)
ORDER BY root_taxonomy, tax_id