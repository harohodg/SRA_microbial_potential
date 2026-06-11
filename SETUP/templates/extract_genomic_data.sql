SELECT
    accession,
    organism.tax_id AS tax_id,
    assembly_info.biosample.accession  AS biosample,
    assembly_info.bioproject_accession AS bioproject,
    assembly_info.refseq_category,
    CAST(assembly_stats.total_sequence_length AS UBIGINT) AS sequence_length,
    source_database,
    paired_accession,
    assembly_info.assembly_level AS assembly_level,
    annotation_info.stats::JSON  AS assembly_stats
FROM read_json('NCBI_DATA.jsonl.gz')
WHERE 
    accession = current_accession
    AND 
    assembly_info.suppression_reason IS NULL
ORDER BY tax_id ASC
