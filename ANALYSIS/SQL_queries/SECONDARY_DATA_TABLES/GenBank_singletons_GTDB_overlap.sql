WITH genbank_genome_bounds AS
(
    SELECT 
        * 
    FROM ( VALUES {genbank_bounds}  ) AS t(genbank_min_genomes, genbank_max_genomes)
), gtdb_genome_bounds AS
(
    SELECT 
        * 
    FROM ( VALUES {gtdb_bounds}  ) AS t(gtdb_min_genomes, gtdb_max_genomes)
)
SELECT
    root_taxonomy,
    genbank_min_genomes,
    genbank_max_genomes,
    gtdb_min_genomes,
    gtdb_max_genomes,
    COUNT( tax_id )             AS num_ncbi_species,
    SUM( num_genbank_genomes )  AS num_genbank_genomes,
    array_unique( flatten( array_agg(gtdb_species) ) )              AS num_gtdb_species,
    array_unique( flatten( array_agg(genbank_base_accessions) ) )   AS num_gtdb_genomes,
FROM 
    read_parquet('{data_table}'), genbank_genome_bounds, gtdb_genome_bounds
WHERE
    genbank_min_genomes <= num_genbank_genomes AND  num_genbank_genomes <= genbank_max_genomes
    AND
    gtdb_min_genomes <= LENGTH(genbank_base_accessions) AND  LENGTH(genbank_base_accessions) <= gtdb_max_genomes
GROUP BY ALL