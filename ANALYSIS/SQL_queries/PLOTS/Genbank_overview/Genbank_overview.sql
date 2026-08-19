WITH genbank_counts AS 
(
    FROM read_parquet('{genome_counts_table}') 
    SELECT 
        DISTINCT 
            root_taxonomy, 
            CASE 
                 WHEN num_genbank_genomes < {genome_count_threshold} THEN num_genbank_genomes::VARCHAR 
                 ELSE '>= {genome_count_threshold}' 
             END AS num_genomes_category, 
        COUNT(*) OVER (PARTITION BY root_taxonomy, num_genomes_category) AS num_genbank_species, 
        COUNT(*) OVER (PARTITION BY root_taxonomy) AS total_num_genbank_species  
    WHERE num_genbank_genomes != 0 AND root_taxonomy IN ('Archaea', 'Bacteria')
), SRA_counts AS
(
    FROM read_parquet('{SRA_counts_table}') 
    SELECT 
        STAT_root_taxonomy AS root_taxonomy, 
        CASE 
             WHEN query_num_genbank_genomes < {genome_count_threshold} THEN query_num_genbank_genomes::VARCHAR 
             ELSE '>= {genome_count_threshold}' 
         END AS num_genomes_category, 
        COUNT( DISTINCT STAT_tax_id ) AS num_SRA_species, 
    WHERE {data_filter}
    GROUP BY ALL
)
SELECT
    genbank_counts.root_taxonomy,
    genbank_counts.num_genomes_category,
    genbank_counts.num_genbank_species,
    SRA_counts.num_SRA_species,
    genbank_counts.total_num_genbank_species,
    100*(num_genbank_species/total_num_genbank_species)::DECIMAL(4,3) AS percentage_1,
    100*(num_SRA_species/num_genbank_species)::DECIMAL(4,3) AS percentage_2
FROM 
    genbank_counts 
    FULL JOIN 
    SRA_counts 
    USING (root_taxonomy,num_genomes_category)