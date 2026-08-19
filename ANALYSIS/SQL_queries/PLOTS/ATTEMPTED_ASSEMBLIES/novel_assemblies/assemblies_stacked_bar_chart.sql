WITH intermediate_data AS
(
    SELECT
        assembly_status, 
        assembly_quality, 
        CHECKM_Additional_Notes,
        CASE
            WHEN assembly_status != 'assembled' THEN 'Failed'
            WHEN IFNULL(CHECKM_Additional_Notes, 'None') = 'None' AND global_ANI_Align_fraction_ref >= 50 THEN assembly_quality ELSE 'Low'
        END as plot_label,
        SRA_average_read_length*STAT_num_reads/reference_genome_genome_size AS genome_coverage,
        ntile({num_bins} ORDER BY genome_coverage ASC) OVER () AS bin 
    FROM read_parquet('{data_table}')
    WHERE 
        ({novel_assembly} ) AND assembly_data_label != 'TARANTELLAE_ANALYSIS'
), bins_data AS
(
    SELECT
        bin,
        MIN(genome_coverage) AS min_coverage,
        MAX(genome_coverage) AS max_coverage,
        (max_coverage + min_coverage)/2 AS mid_coverage,
        COUNT(*) AS num_points_in_bin,
    FROM intermediate_data
    GROUP BY bin
    ORDER BY bin ASC
), adjusted_bins_data AS
(
    SELECT
        *,
        ( IFNULL( LAG(max_coverage) OVER (), min_coverage) + min_coverage)/2 AS adjusted_min_coverage,
        ( IFNULL( LEAD(min_coverage) OVER (), max_coverage) + max_coverage)/2 AS adjusted_max_coverage
    FROM bins_data
)
SELECT
    bin,
    min_coverage,
    max_coverage,
    mid_coverage,
    adjusted_min_coverage,
    adjusted_max_coverage,
    num_points_in_bin,
    (adjusted_min_coverage + adjusted_max_coverage)/2 AS adjusted_mid_coverage,
    plot_label,
    map_extract( map(['Failed', 'Poor', 'Low', 'Medium', 'High'], [1, 2, 3, 4, 5]), plot_label )[1]::INT AS label_order,
    {x_label} AS x_label
FROM intermediate_data JOIN adjusted_bins_data USING (bin)
ORDER BY bin ASC