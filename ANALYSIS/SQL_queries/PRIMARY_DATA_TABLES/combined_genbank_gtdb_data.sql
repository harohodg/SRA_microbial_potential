with unnested_genbank AS 
(
    SELECT
        tax_id, 
        root_taxonomy,
        rank,
        UNNEST(base_genbank_accessions)   AS base_genbank_accession,
        LENGTH( base_genbank_accessions ) AS num_genbank_genomes
    FROM read_parquet('{raw_genbank_data}')
    WHERE root_taxonomy = '{genbank_root_taxonomy}'
), unnested_gtdb AS
( 
    SELECT 
        gtdb_species, 
        UNNEST( base_genbank_accessions) AS base_genbank_accession, 
        base_genbank_accessions 
    FROM read_parquet('{raw_gtdb_data}')
) 
SELECT 
    tax_id, 
    root_taxonomy,
    rank,
    num_genbank_genomes,
    array_distinct( array_agg(gtdb_species) ) AS gtdb_species, 
    array_distinct( flatten( array_agg( base_genbank_accessions ) ) ) AS genbank_base_accessions 
FROM 
    unnested_genbank 
    LEFT JOIN 
    unnested_gtdb 
    USING (base_genbank_accession) 
GROUP BY ALL