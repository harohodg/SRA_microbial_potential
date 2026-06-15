SELECT
    accession AS gtdb_accession,
    string_split(ncbi_genbank_assembly_accession, '.')[1] AS base_genbank_accession,
    root_taxonomy_label AS ncbi_root_taxonomy,
    ncbi_taxid,
    ncbi_species_taxid,
    UNNEST( regexp_extract(gtdb_taxonomy, 'd__([a-z]+);.*?s__(.+)', ['gtdb_root_taxonomy', 'gtdb_species'], 'i') ),
FROM 
    read_csv('{data_table}') as gtdb_data
    LEFT JOIN 
    ROOT_TAXONOMY_LABELS
    ON (tax_id = ncbi_taxid)
