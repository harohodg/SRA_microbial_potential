SELECT 
    acc AS accession,
    experiment,
    bioproject,
    biosample,
    organism,
    instrument,
    assay_type,
    platform,
    avgspotlen AS average_read_length, 
    CAST( list_filter(attributes, d -> d.k = 'bases')[1].v AS UBIGINT)  AS num_bases
FROM read_parquet('PARQUET_FILE')
ORDER BY accession ASC
