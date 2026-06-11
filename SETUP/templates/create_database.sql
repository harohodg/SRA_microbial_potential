

-- ==================================================================================
-- Raw data tables
-- ==================================================================================

CREATE TABLE genomic_data 
(
    accession             VARCHAR,
    tax_id                UINTEGER,
    biosample             VARCHAR,
    bioproject            VARCHAR,
    refseq_category       VARCHAR,
    sequence_length       UBIGINT,
    source_database       VARCHAR,
    paired_accession      VARCHAR,
    assembly_level        VARCHAR,
    assembly_stats        JSON
);


CREATE TABLE SRA_meta_data 
(
    accession           VARCHAR,
    experiment          VARCHAR,
    bioproject          VARCHAR,
    biosample           VARCHAR,
    organism            VARCHAR, 
    instrument          VARCHAR, 
    assay_type          VARCHAR, 
    platform            VARCHAR,
    average_read_length UBIGINT,
    num_bases           UBIGINT,
);


CREATE TABLE STAT_meta_data
(
    accession           VARCHAR, 
    analyzed_spot_count UBIGINT,
    total_spot_count    UBIGINT
);


CREATE TABLE STAT_data
(
    accession   VARCHAR, 
    tax_id      UINTEGER,
    rank        VARCHAR,
    total_count UBIGINT,
    self_count  UBIGINT
);

CREATE TABLE TAXONOMY_data
(
    tax_id          UINTEGER,
    parent_tax_id   UINTEGER,
    rank            VARCHAR,
    sci_name        VARCHAR
);




COPY genomic_data   FROM 'genomic_data-*.parquet'   (FORMAT PARQUET);
COPY SRA_meta_data  FROM 'SRA_meta_data-*.parquet' (FORMAT PARQUET);
COPY STAT_meta_data FROM 'STAT_meta_data-*.parquet' (FORMAT PARQUET);
COPY STAT_data      FROM 'STAT_data-*.parquet' (FORMAT PARQUET);
COPY TAXONOMY_data  FROM 'taxonomy_data-*.parquet'  (FORMAT PARQUET);