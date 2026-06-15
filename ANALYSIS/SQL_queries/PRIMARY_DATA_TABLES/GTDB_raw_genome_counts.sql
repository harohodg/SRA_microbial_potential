WITH intermediate_data AS
(
    SELECT
        string_split(ncbi_genbank_assembly_accession, '.')[1] AS base_genbank_accession,
        UNNEST( regexp_extract(gtdb_taxonomy, 'd__([a-z]+);.*?s__(.+)', ['gtdb_root_taxonomy', 'gtdb_species'], 'i') ),
    FROM read_csv('{data_table}') as gtdb_data
)
SELECT
    gtdb_root_taxonomy,
    gtdb_species,
    array_agg( base_genbank_accession ) AS base_genbank_accessions
FROM intermediate_data
GROUP BY ALL
