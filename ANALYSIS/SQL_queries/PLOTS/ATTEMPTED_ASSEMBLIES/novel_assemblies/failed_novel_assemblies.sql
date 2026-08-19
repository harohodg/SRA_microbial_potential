WITH intermediate_data AS
(
    SELECT
        *,
        {coverage_equation} AS genome_coverage,
        ntile({num_bins} ORDER BY genome_coverage ASC) OVER () AS bin 
    FROM read_parquet('{data_table}')
    WHERE 
        ({novel_assembly_equation}) = true
        AND assembly_data_label != 'TARANTELLAE_ANALYSIS'
)
SELECT
    bin,
    MIN(genome_coverage) + ( MAX(genome_coverage) - MIN(genome_coverage) )/2 AS mid_coverage,
    100*( COUNT( CASE WHEN {failure_equation} THEN 1 END ) / COUNT(*) ) AS percent_failed
FROM intermediate_data
GROUP BY bin
ORDER BY bin ASC