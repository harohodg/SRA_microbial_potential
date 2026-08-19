WITH summarized_counts AS 
(
    SELECT
        query_root_taxonomy AS root_taxonomy,
        query_tax_id        AS species_tax_id,
        query_sci_name      AS species_name,
        query_num_{target_db}_genomes AS num_{target_db}_genomes,

        CASE 
            WHEN query_num_{target_db}_genomes < {genome_count_threshold} THEN query_num_{target_db}_genomes::VARCHAR 
            ELSE '>= {genome_count_threshold}' 
        END AS {target_db}_genomes_label,

        MEAN( {coverage_equation} )::DECIMAL(10,3) AS mean_estimated_genome_coverage,
        COUNT(*) AS num_SRA_accessions,

        IFNULL(GTDB_num_species, 0) AS num_gtdb_species,
        IFNULL(GTDB_num_genomes, 0) AS num_gtdb_genomes,
        CASE 
            WHEN num_gtdb_genomes < {genome_count_threshold} THEN num_gtdb_genomes::VARCHAR 
            ELSE '>= {genome_count_threshold}' 
        END AS gtdb_genomes_label,
    FROM 
        read_parquet('{data_table}')
    WHERE {data_filter}
    GROUP BY ALL
)
    SELECT
        *,
        ROW_NUMBER() OVER ( PARTITION BY root_taxonomy ORDER BY num_{target_db}_genomes DESC, mean_estimated_genome_coverage DESC) AS rn,
        CUME_DIST() OVER ( PARTITION BY root_taxonomy ORDER BY num_{target_db}_genomes DESC, mean_estimated_genome_coverage DESC)  AS x_index
    FROM summarized_counts
    ORDER BY rn ASC