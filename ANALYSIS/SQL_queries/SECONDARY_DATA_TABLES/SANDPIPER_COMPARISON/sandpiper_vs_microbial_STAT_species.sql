
WITH double_singletons AS
(
    SELECT
        tax_id,
        gtdb_species[1] AS gtdb_species
    FROM read_parquet('{merged_genbank_gtdb_data}')
    WHERE num_genbank_genomes = 1 AND LENGTH(genbank_base_accessions) = 1
), sandpiper_data AS 
(
    SELECT
        sample AS SRA_accession,
        coverage AS sandpiper_coverage,
        taxonomy AS sandpiper_taxonomy
    FROM read_csv('{sandpiper_data}')
    WHERE 
        string_split(taxonomy, ';')[-1][2] = 's'
        AND
        string_split(taxonomy, ';')[-1][5:] IN ( SELECT gtdb_species FROM double_singletons)
), STAT_data AS
(
    SELECT
        query_taxid,
        SRA_SRA_accession AS SRA_accession,
        ? AS STAT_coverage 
    FROM read_parquet('{STAT_data}')
    WHERE 
        query_root_taxonomy = 'Archaea' or query_root_taxonomy = 'Bacteria'
        AND
        query_tax_id IN ( SELECT tax_id FROM double_singletons)
)

-- SELECT 
--     'all ranks|raw_data' AS data_label,
--     'Sandpiper' AS data_source,
--     COUNT( DISTINCT sample ) AS num_SRA_accessions,
--     COUNT( * ) AS num_predictions,
--     COUNT( DISTINCT taxonomy ) AS num_taxonomy
-- FROM read_csv('{sandpiper_data}')

-- UNION ALL

-- SELECT 
--     'all ranks|raw_data'  AS data_label,
--     'microbial STAT' AS data_source,
--     COUNT( DISTINCT SRA_accession ) AS num_SRA_accessions,
--     COUNT( * ) AS num_predictions,
--     COUNT( DISTINCT tax_id ) AS num_taxonomy
-- FROM read_parquet('{microbial_STAT_data}')

-- UNION ALL

-- SELECT 
--     'all ranks|overlap' AS data_label,
--     'Sandpiper' AS data_source,
--     COUNT( DISTINCT sample ) AS num_SRA_accessions,
--     COUNT( * ) AS num_predictions,
--     COUNT( DISTINCT taxonomy ) AS num_taxonomy
-- FROM read_csv('{sandpiper_data}')
-- WHERE sample IN ( SELECT SRA_accession FROM read_parquet('{overlapping_accessions}') )

-- UNION ALL

-- SELECT 
--     'all ranks|overlap'  AS data_label,
--     'microbial STAT' AS data_source,
--     COUNT( DISTINCT SRA_accession ) AS num_SRA_accessions,
--     COUNT( * ) AS num_predictions,
--     COUNT( DISTINCT tax_id ) AS num_taxonomy
-- FROM read_parquet('{microbial_STAT_data}')
-- WHERE SRA_accession IN ( SELECT SRA_accession FROM read_parquet('{overlapping_accessions}') )