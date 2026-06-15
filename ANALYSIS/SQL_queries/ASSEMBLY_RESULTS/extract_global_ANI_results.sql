SELECT
    {columns_to_keep},
    ANI AS global_ANI,
    Align_fraction_ref      AS global_ANI_Align_fraction_ref,
    Align_fraction_query    AS global_ANI_Align_fraction_query
FROM read_csv('{data_files}')