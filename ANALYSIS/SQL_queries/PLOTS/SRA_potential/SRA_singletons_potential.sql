WITH thresholds AS
(
    SELECT * AS coverage_threshold FROM UNNEST({thresholds})
), gtdb_counts AS 
(
    SELECT
        tax_id,
        LENGTH(gtdb_species) AS num_gtdb_species,
        LENGTH(genbank_base_accessions) AS num_gtdb_genomes
    FROM read_parquet('{gtdb_data}')
)
(
    SELECT
        'GenBank singletons' AS data_label,
        query_root_taxonomy      AS root_taxonomy,
        coverage_threshold,
        COUNT(*) AS num_genomes,
        COUNT( DISTINCT query_tax_id ) AS {species_label},
    FROM 
        read_parquet('{data_table}')
        JOIN
        thresholds
        ON {coverage_equation} >= coverage_threshold
    WHERE {data_filter} AND query_num_genbank_genomes = 1
    GROUP BY ALL
    ORDER BY coverage_threshold ASC
)
UNION ALL

(
    SELECT
        'DOUBLE singletons' AS data_label,
        query_root_taxonomy AS root_taxonomy,
        coverage_threshold,
        COUNT(*) AS num_genomes,
        COUNT( DISTINCT query_tax_id ) AS {species_label},
    FROM 
        read_parquet('{data_table}')
        JOIN
        thresholds
        ON {coverage_equation} >= coverage_threshold
        LEFT JOIN 
        gtdb_counts
        ON (STAT_tax_id = tax_id)
    WHERE {data_filter} AND query_num_genbank_genomes = 1 AND num_gtdb_genomes = 1
    GROUP BY ALL
    ORDER BY coverage_threshold ASC
)