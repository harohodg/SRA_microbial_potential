
/*
Extracts SRA and NCBI data into individual parquet files
*/
process EXTRACT_data {
    cpus 4

    input:
        path data, stageAs: 'INPUT_FILE'
        val table
        val input_file_name
    
    output:
       path "${table}-${task.index}.parquet"
        
    script:
        """
        cat << EOF > query.sql
        SET threads=${task.cpus};

        SET autoinstall_known_extensions=1;
        SET autoload_known_extensions=1;

        COPY (
        EOF
        
        cat ${projectDir}/templates/extract_${table}.sql >>  query.sql
        
        cat << EOF >> query.sql 
        ) TO "${table}-${task.index}.parquet"; 
        EOF

        mv INPUT_FILE ${input_file_name}
        
        duckdb < query.sql
        """
}




/*
Create Database from extracted data
*/
process CREATE_DATABASE {
    publishDir "${output_folder}", mode: 'copy', overwrite: true
    
    input:
        path input_files
        val database_name
        val output_folder
        
    output:
        path "${database_name}"
        
    script:
        """        
        duckdb ${database_name} < ${projectDir}/templates/create_database.sql
        duckdb ${database_name} < ${projectDir}/templates/init_database.sql
        """ 
}