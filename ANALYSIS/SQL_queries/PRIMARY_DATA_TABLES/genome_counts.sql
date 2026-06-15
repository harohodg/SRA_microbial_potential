SELECT 
    *,
    LENGTH(gtdb_species) AS num_gtdb_species,
    LENGTH(genbank_base_accessions) AS num_gtdb_genomes
FROM 
    LABELED_REFSEQ_GENBANK_COUNTS('species') 
    LEFT JOIN
    read_parquet('{data_file}')
    USING( tax_id )