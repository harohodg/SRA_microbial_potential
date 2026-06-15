WITH thresholds AS
(
    SELECT * AS coverage_threshold FROM UNNEST({thresholds})
), intermediate_data AS
(
    SELECT
        coverage_threshold,
        SRA_assay_type AS assay_type,
        CHECKM_Genome_Size / reference_genome_sum_len AS genome_size_ratio,
        CHECKM_Contig_N50 AS N50,
        CHECKM_Max_Contig_Length AS max_contig_length
    FROM 
        read_parquet('{data_table}')
        JOIN
        thresholds
        ON {coverage_equation} >= coverage_threshold
    WHERE {data_filter}
)
SELECT
    coverage_threshold,
    assay_type,
    array[MIN(genome_size_ratio)::DECIMAL(10,2), MEAN(genome_size_ratio)::DECIMAL(10,2), MAX(genome_size_ratio)::DECIMAL(10,2)] AS genome_size_ratio_stats,
    array[MIN(N50), MEAN(N50)::DECIMAL(10,2), MAX(N50)] AS N50_stats,
    array[MIN(max_contig_length), MEAN(max_contig_length)::DECIMAL(10,2), MAX(max_contig_length)] AS max_contig_length_stats
FROM intermediate_data
GROUP BY ALL
ORDER BY coverage_threshold, assay_type