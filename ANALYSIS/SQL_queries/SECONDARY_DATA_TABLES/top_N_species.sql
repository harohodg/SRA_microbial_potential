WITH data_table AS
(
    FROM LABELED_REFSEQ_GENBANK_COUNTS('species') 
    SELECT 
        IFNULL(root_taxonomy, 'UNKNOWN') AS root_taxonomy,
        sci_name,
        tax_id,
        num_{target_db}_genomes,
), top_N_data AS
(
    SELECT
        *
    FROM    
    (    
    FROM data_table
        SELECT 
            unnest( max_by(data_table, num_{target_db}_genomes, {top_N}), recursive := 1)
    GROUP BY root_taxonomy
    ) AS top_N
    JOIN
    (
    FROM data_table
    SELECT
        root_taxonomy,
        SUM(num_{target_db}_genomes) AS total_self_genomes
    GROUP BY root_taxonomy
    ) AS total_counts
    USING (root_taxonomy)
), overall_counts AS
(
    FROM data_table
    SELECT
        SUM(num_{target_db}_genomes) AS total_all_genbank_genomes,
        SUM( CASE WHEN root_taxonomy NOT IN ('UNKNOWN', 'other entries', 'unclassified entries') THEN num_{target_db}_genomes END) AS total_subset_all_genbank_genomes
), itermediate_data_table AS 
(
    FROM top_N_data, overall_counts
    SELECT *
), secondary_data_table AS
(
FROM itermediate_data_table
SELECT *

UNION ALL

FROM itermediate_data_table
SELECT 
    'ANY' AS root_taxonomy,
    unnest( max_by(COLUMNS(* EXCLUDE(root_taxonomy)), num_{target_db}_genomes, {top_N}), recursive := 1)
), tertiary_data_table AS
(
    FROM secondary_data_table
    SELECT
        *,

    UNION ALL

    FROM secondary_data_table
    SELECT
        root_taxonomy,
        'TOP_{top_N}_species' AS sci_name,
        NULL AS tax_id,
        SUM(num_{target_db}_genomes) AS num_{target_db}_genomes,
        SUM( DISTINCT( COLUMNS('^total.*') ) ) AS '\0'
    GROUP BY root_taxonomy
)
FROM tertiary_data_table
SELECT 
    *,
    (num_{target_db}_genomes / COLUMNS('^total_(.*)') )::DECIMAL(6,3) AS 'fraction_of_\1'
ORDER BY root_taxonomy, num_{target_db}_genomes DESC