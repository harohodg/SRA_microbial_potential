import duckdb, re
import numpy as np
import pandas as pd
import altair as alt
import plotly.express as px
from pathlib import Path
import os, shutil
from plotnine import ggplot, aes, geom_violin, scale_y_continuous, labs, theme_bw, theme, element_text

alt.data_transformers.enable("vegafusion")

from data_sources import *
from functions    import *


NOVEL_PROPOSED_ASSEMBLY="IFNULL(sequencing_project_type, '') != 'an associated sequencing project' AND STAT_root_taxonomy NOT IN SRA_what_was_sequenced_root_taxonomy_labels"
NOVEL_ATTEMPTED_ASSEMBLY="IFNULL(data_source, '') != 'is the sequencing project' AND STAT_root_taxonomy NOT IN SRA_what_was_sequenced_root_taxonomy_labels"

PROPOSED_ASSEMBLY_COVERAGE="SRA_average_read_length*STAT_num_reads/query_mean_genome_length"
ATTEMPTED_ASSEMBLY_COVERAGE="SRA_average_read_length*STAT_num_reads/reference_genome_genome_size"

SUCCESSFUL_ATTEMPTED_ASSEMBLY="assembly_status = 'assembled' AND assembly_quality IN ('Medium', 'High') AND NOT starts_with(CHECKM_Additional_Notes,'Low confidence prediction') AND  global_ANI_Align_fraction_ref >= 50"
UNSUCCESSFUL_ATTEMPTED_ASSEMBLY=f"NOT ({SUCCESSFUL_ATTEMPTED_ASSEMBLY})"

POTENTIAL_ASSEMBLIES_DATA = f"{PRIMARY_DATA_TABLES_FOLDER}/*-search_table.parquet"
ATTEMPTED_ASSEMBLIES_DATA = f"{ASSEMBLY_DATA_TABLES_FOLDER}/pipeline-individual_assemblies.parquet"

#Function which is just a wrapper for a specific plotting function
#adds checking for existing data, saving the sql, plot data, and plot
def create_plot(plot_function, output_folder, overwrite_existing=False, func_args={}, save_to_disk=True):
    print(f'Createing plots with {str(plot_function.__name__)} -> {output_folder}')
    if overwrite_existing == False and Path(output_folder).is_dir():
        print(f'{output_folder} already exists. Skipping')
        return None, None
    elif overwrite_existing == True and Path(output_folder).is_dir() and save_to_disk == True:
        print(f'{output_folder} already exists. Removing')
        shutil.rmtree( output_folder )
    
    intermediate_data = plot_function(**func_args)
    if save_to_disk == True:
        os.makedirs(output_folder)
        for fname in intermediate_data:
            sql_query, plot_data_table, figure = intermediate_data[fname]
    
            if plot_data_table is not None:
                data_table_fname = f"{output_folder}/{fname}.{plot_data_table[0]}"
                data_table = plot_data_table[-1]
                export_flags = "(DELIMITER '\t', HEADER true)" if plot_data_table[0] == "tsv" else ""
        
                duckdb.sql( f"COPY data_table TO '{data_table_fname}' {export_flags}" )
            
            if sql_query != '':
                with open(f'{output_folder}/{fname}.sql', 'w') as f:
                    f.write(sql_query)
    
            if figure is not None:
                plot_type, plot, plot_config = figure
                plot_fname = f"{output_folder}/{fname}"
                
                if plot_type == 'altair':
                    export_altair_plot(plot, plot_fname)
                elif plot_type == 'plotly':
                    export_plotly_plot(plot, plot_fname)
                elif plot_type == 'ggplot':
                    export_ggplot_plot(plot, plot_fname, plot_config)
    return intermediate_data


def plot_genbank_overview(plot_width=250, plot_height=250, plot_title='', genome_count_threshold=5):
    sql_parameters = {
    'genome_count_threshold' : genome_count_threshold,
    'SRA_counts_table' : POTENTIAL_ASSEMBLIES_DATA,
    'genome_counts_table' : f"{PRIMARY_DATA_TABLES_FOLDER}/genome_counts.parquet",
    'data_filter' : f"({PROPOSED_ASSEMBLY_COVERAGE}) >= 1 AND ({NOVEL_PROPOSED_ASSEMBLY}) = true AND query_num_genbank_genomes != 0 AND STAT_root_taxonomy IN ('Archaea', 'Bacteria')"
    }
    sql_file = 'SQL_queries/PLOTS/Genbank_overview/Genbank_overview.sql'
    plot_query, plot_data = run_sql_query(sql_file, parameters = sql_parameters)
    
    base_plot = alt.Chart(plot_data, title=plot_title).encode(
        alt.X('root_taxonomy').title(''),
        alt.Color("num_genomes_category", legend=alt.Legend(symbolOpacity=1,  gradientOpacity=1)).title('# of Genomes'),
        alt.Order(
          # Sort the segments of the bars by this field
          'num_genomes_category',
          sort='ascending'
        ),
    )
    
    plot_1 = base_plot.mark_bar().encode( 
        alt.Y('percentage_1', sort='-color' ).title('% of species').scale(domain=[0,100]),
        opacity=alt.when( alt.datum.num_genomes_category != '1' ).then( alt.value(1) ).otherwise( alt.value(0.95) )
    )
    plot_2 = base_plot.mark_bar(opacity=1).encode( alt.Y('percentage_2', sort='-color' ).title('% of species').scale(domain=[0,100]) ).transform_filter(
        alt.datum.num_genomes_category == '1'
    )
    
    
    plot = (plot_1 + plot_2).properties(
        width=plot_width,
        height=plot_height,
    ).configure_axis(
        grid=False,
        labelFontSize=20,
        titleFontSize=20
    ).configure_legend(
        labelFontSize=20,
        titleFontSize=20
    )
    
    return {'genbank_overview': (plot_query, ('tsv', plot_data), ('altair', plot, {}) )}


# #How much potential data is there in the SRA 
# #"novel" assemblies with >= 1X coverage
def plot_overall_SRA_potential(target_db='genbank', genome_count_threshold=5, top_n=10):
    results = {}
    
    sql_parameters = {
    'genome_count_threshold' : genome_count_threshold,
    'target_db' : target_db,
    'TOP_N' : top_n,
    'coverage_equation' : f"{PROPOSED_ASSEMBLY_COVERAGE}",
    'data_filter' : f"({PROPOSED_ASSEMBLY_COVERAGE}) >= 1 AND ({NOVEL_PROPOSED_ASSEMBLY}) = true"
    }
    sql_file = 'SQL_queries/PLOTS/SRA_potential/SRA_potential_overview.sql'
    intermediate_data = []
    for root_taxonomy in ('Archaea', 'Bacteria'):
            query, data = run_sql_query(sql_file, parameters = sql_parameters | {'data_table':f"{PRIMARY_DATA_TABLES_FOLDER}/{root_taxonomy}-search_table.parquet"})
            results[f'SRA_overall_potential-{root_taxonomy}'] = (query, ('tsv', data), None)
            intermediate_data.append( data )
    plot_data = pd.concat(intermediate_data, axis=0, ignore_index=True, sort=False)

    
    sql_file = 'SQL_queries/PLOTS/SRA_potential/SRA_potential_overview-top_N.sql'
    with open(sql_file, 'r') as f:
        top_N_query =  f.read().format( **(sql_parameters | {'data_table': "plot_data"}) ) 
    top_N_data = duckdb.sql(top_N_query).df()  
    results['top_N_species'] = (top_N_query, ('tsv',top_N_data), None)
    
    top_N_species  = duckdb.sql(r"SELECT array_agg(DISTINCT species_tax_id)  FROM top_N_data WHERE regexp_full_match(data_label,'(Archaea|Bacteria)($|( GenBank((\|GTDB : 1\|)|( : ))1))') AND adjusted_rn <= 3").fetchall()[0][0]
    
    regex = r"(?P<genus>^[A-Z])[a-z]+\s(?P<species>.+?)((\s.+?.+?)?)$"
    plot_data['simple_species_name'] = plot_data.species_name.apply(lambda species_name: re.search(regex, species_name, re.MULTILINE) )
    plot_data['simple_species_name'] = plot_data.simple_species_name.apply(lambda matches : f"{matches['genus']}. {matches['species']}" if matches is not None else '' ) 
    
    plot_data['label_angle'] = 0
    plot_data['dx'] = 10
    plot_data['dy'] = 0
    plot_data['align'] = 'left'
    plot_data['baseline'] = 'middle'
    
    
    plot_data.loc[plot_data['species_tax_id'] == 350, 'dx'] = -10
    plot_data.loc[plot_data['species_tax_id'] == 350, 'align'] = 'right'
    plot_data.loc[plot_data['species_tax_id'] == 2763051, 'baseline'] = 'bottom'
    plot_data.loc[plot_data['species_tax_id'] == 2763672, 'baseline'] = 'top'
    plot_data.loc[plot_data['species_tax_id'] == 562, 'baseline'] = 'bottom'
    plot_data.loc[plot_data['species_tax_id'] == 562, 'dy'] = -9
    plot_data.loc[plot_data['species_tax_id'] == 573, 'dy'] = 4
    plot_data.loc[plot_data['species_tax_id'] == 573, 'baseline'] = 'top'
    
    
    plot_width  = 750*2
    plot_height = 500 
    plot_title = ''
    plot_fname = 'PLOTS/plot_02/plot_02'
    
    
    base_plot = alt.Chart(plot_data, title=plot_title).mark_point().encode(
        alt.X('x_index', axis=alt.Axis(labels=False, ticks=False) ).title('Mean(genome coverage) high → low'),
        alt.Y('num_SRA_accessions').title('').scale(type="log"),
        alt.Tooltip( list( plot_data.columns) ),
        color=alt.when( alt.FieldOneOfPredicate('species_tax_id', top_N_species) ).then( alt.value('black') ).otherwise( alt.Color('genbank_genomes_label:N').title('# of GenBank Genomes') ),
        shape=alt.when( (alt.datum.num_genbank_genomes == 1) & (alt.datum.num_gtdb_genomes == 1) ).then( alt.value('triangle') ).otherwise( alt.value('circle') ),
        size=alt.when( (alt.datum.root_taxonomy == 'Archaea')  ).then( alt.value(50) ).otherwise( alt.value(20) ),
        opacity=alt.when( (alt.FieldOneOfPredicate('species_tax_id', top_N_species) ) | (alt.datum.root_taxonomy == 'Archaea')  ).then( alt.value(1) ).otherwise( alt.value(0.5) )
    ).properties(
        width=plot_width,
        height=plot_height
    )
    
    background_strips = alt.Chart(plot_data).mark_rect(opacity=0.5).encode(
        x='min_x:Q',
        x2='max_x:Q',
        color=alt.when( (alt.datum.threshold_label == '>= 5') | (alt.datum.threshold_label == '3') | (alt.datum.threshold_label == '1') ).then( alt.value('#f0f0f0') ).otherwise( alt.value('white') )
    ).transform_aggregate(
        min_x='min(x_index)',
        max_x='max(x_index)',
        groupby=['root_taxonomy', 'genbank_genomes_label']
    ).properties(
        width=plot_width,
        height=plot_height
    )
    
    
    text_layer = alt.Chart(plot_data).transform_filter( alt.FieldOneOfPredicate('species_tax_id', top_N_species) ).mark_text(
        align=alt.expr(alt.expr.if_(alt.datum.species_tax_id in top_N_species, alt.datum.align, 0)),
        baseline=alt.expr(alt.expr.if_(alt.datum.species_tax_id in top_N_species, alt.datum.baseline, 0)),
        dy=alt.expr(alt.expr.if_(alt.datum.species_tax_id in top_N_species, alt.datum.dy, 0)),
        dx=alt.expr(alt.expr.if_(alt.datum.species_tax_id in top_N_species, alt.datum.dx, 0)),
        fontSize=15,
        angle=alt.expr(alt.expr.if_(alt.datum.species_tax_id in top_N_species, alt.datum.label_angle, 0))
    ).encode(
        text='simple_species_name',
        x='x_index',
        y='num_SRA_accessions',
    )
    
    facet_chart = (background_strips + base_plot + text_layer ).facet(
        row=alt.Row('root_taxonomy').title("log(# of potentially novel genomes)").header(titleOrient="left", labels=True, titleFontSize=20)
    ).configure_axis(
        grid=False,
        labelFontSize=20,
        titleFontSize=20
    ).configure_headerRow(
        labelFontSize=20
    ).configure_legend(
        labelFontSize=20,
        titleFontSize=15,
        orient='none',
        legendX=1300, 
        legendY=15,
        labelAlign='right',
        labelOffset=50 
    )
    results['SRA_overall_potential'] = ('', ('tsv', plot_data), ('altair', facet_chart, {}) )
    return results


def plot_singletons_SRA_potential( plot_width=250, plot_height=250, plot_title='', thresholds=[1,2,5,10,100,1000] ):
    results = {}
    
    sql_parameters = {
    'thresholds' : thresholds,
    'gtdb_data' : f"{PRIMARY_DATA_TABLES_FOLDER}/*-merged_GTDB_Genbank_data.parquet",
    'coverage_equation' : f"{PROPOSED_ASSEMBLY_COVERAGE}",
    'data_filter' : f"({PROPOSED_ASSEMBLY_COVERAGE}) >= 1 AND ({NOVEL_PROPOSED_ASSEMBLY}) = true",
    'species_label' : 'num_singleton_species'
    }
    sql_file = 'SQL_queries/PLOTS/SRA_potential/SRA_singletons_potential.sql'
    intermediate_data = []
    for root_taxonomy in ('Archaea', 'Bacteria'):
            query, data = run_sql_query(sql_file, parameters = sql_parameters | {'data_table':f"{PRIMARY_DATA_TABLES_FOLDER}/{root_taxonomy}-search_table.parquet"})
            results[f'SRA_singletons_potential-{root_taxonomy}'] = (query, ('tsv', data), None)
            intermediate_data.append( data )
    plot_data = pd.concat(intermediate_data, axis=0, ignore_index=True, sort=False)

    plot = alt.Chart(plot_data, title='').mark_circle().encode(
        alt.X('num_singleton_species').title('# of singleton species').scale(type='log', domain=[1,10**7]),
        alt.Y('num_genomes').title('Estimated # of novel genomes in the SRA').scale(type='log', domain=[1,10**7]),
        alt.Color('root_taxonomy').title('Root Taxonomy'),
        alt.Size('coverage_threshold:N', scale=alt.Scale(range=[50, 300])).title('Minimum coverage'),
        alt.Tooltip( list( plot_data.columns) ),
        opacity=alt.when( (alt.datum.data_label == 'DOUBLE singletons') ).then( alt.value(0.25) ).otherwise( alt.value(0.75) )
    ).properties(
        width=plot_width,
        height=plot_height,
    ).configure_axis(
        grid=False
    )
    
    return {'SRA_singletons_potential': ('', ('tsv', plot_data), ('altair', plot, {}) )} 


def plot_novel_fraction_failed( plot_width=250, plot_height=250, num_bins=10, failure_equation="assembly_status != 'assembled'" ):
    sql_parameters = {
    'num_bins' : num_bins,
    'data_table' : ATTEMPTED_ASSEMBLIES_DATA,
    'coverage_equation' : f"{ATTEMPTED_ASSEMBLY_COVERAGE}",
    'novel_assembly_equation' : f"{NOVEL_ATTEMPTED_ASSEMBLY}",
    'failure_equation' : failure_equation
    }
    sql_file = 'SQL_queries/PLOTS/ATTEMPTED_ASSEMBLIES/novel_assemblies/failed_novel_assemblies.sql'
    plot_query, plot_data = run_sql_query(sql_file, parameters = sql_parameters)

    plot = alt.Chart(
        plot_data,
    ).mark_point().encode(
        x=alt.X("mid_coverage").title('Genome Coverage').scale(type="log", domain=[1,30000]),
        y=alt.Y('percent_failed:Q').title('Percent Failed').scale(domain=[0,27]),
    ).configure_axis(
        grid=False,
        labelFontSize=20,
        titleFontSize=20
    ).properties(
        width=plot_width,
        height=plot_height
    )
    
    return {'novel_fraction_failed': (plot_query, ('tsv', plot_data), ('altair', plot, {}) )} 

def plot_novel_successful_checkm_distribution( plot_width=750*2, plot_height=500):
    sql_parameters = {
    'data_table' : ATTEMPTED_ASSEMBLIES_DATA,
    'coverage_equation' : f"{ATTEMPTED_ASSEMBLY_COVERAGE}",
    'novel_assembly_equation' : f"{NOVEL_ATTEMPTED_ASSEMBLY}",
    'succesfull_assembly_equation' : f"{SUCCESSFUL_ATTEMPTED_ASSEMBLY}"
    }
    sql_file = 'SQL_queries/PLOTS/ATTEMPTED_ASSEMBLIES/novel_assemblies/successful_checkm_distribution.sql'
    intermediate_query, intermediate_data = run_sql_query(sql_file, parameters = sql_parameters)
    results = {'successful_checkm_distribution-intermediate' : (intermediate_query, ('tsv', intermediate_data), None) }

    plot_data = intermediate_data.copy()
    plot_data['log_genome_coverage'] = np.log10( plot_data.genome_coverage)
    plot_data['bin'] = pd.cut(plot_data.log_genome_coverage, 20)
    plot_data['bin'] = plot_data['bin'].astype("str") 

    plot = alt.Chart(plot_data).mark_boxplot(
        extent="min-max", 
        box={'stroke': 'black', 'fill':'#cccccc'},
        median={'stroke':'black', 'strokeWidth':2},
        rule={'stroke':'black', 'strokeDash':[4,4]},
        ).encode(
        alt.X("bin", title="Genome Coverage (log10 binned)"),
        alt.Y("CHECKM_Completeness", title="CheckM2 Completeness").scale(zero=True),
    ).configure_axis(
        grid=False,
        labelFontSize=20,
        titleFontSize=20
    ).properties(
        width=plot_width,
        height=plot_height
    )
    
    return results | {'novel_successful_checkm_distribution': ('', ('tsv', plot_data), ('altair', plot, {}) )} 


def plot_novel_successful_contig_length_distribution( plot_width=750, plot_height=500):
    sql_parameters = {
    'data_table' : ATTEMPTED_ASSEMBLIES_DATA,
    'data_filter' : f"{NOVEL_ATTEMPTED_ASSEMBLY} = true AND ({ATTEMPTED_ASSEMBLY_COVERAGE}) >= 1000 AND {SUCCESSFUL_ATTEMPTED_ASSEMBLY} AND assembly_data_label != 'TARANTELLAE_ANALYSIS'"
    }
    sql_file = 'SQL_queries/PLOTS/ATTEMPTED_ASSEMBLIES/novel_assemblies/max_contig_length_distributions.sql'
    plot_query, plot_data = run_sql_query(sql_file, parameters = sql_parameters)
    
    y_ticks_raw = range(1,7)
    y_ticks_adjusted = [ r'$10^{' + str(i) + '}$' for i in y_ticks_raw ]
    plot = (
        ggplot(plot_data, aes("assay_type", "log10_max_Contig_Length"))
        + geom_violin(plot_data, draw_quantiles=[0.50], fill='#cccccc')
        # + geom_point()
        + scale_y_continuous(breaks=y_ticks_raw, labels=y_ticks_adjusted)
        + labs(
            # title="Use labs() to quickly set labels",
            x="",
            y="Max Contig Length",
        )
        + theme_bw() 
        +  theme(axis_text_x=element_text(rotation=45, hjust=1) )
    )
    
    return {'novel_successful_medium_high_contig_length_distribution': (plot_query, ('tsv', plot_data), ('ggplot', plot, {'width' : 6, 'height' : 4, 'dpi' : 100}) )} 


def plot_meta_data(plot_data, labels, plot_width  = 1723, plot_height = 525, all_colors = ['#1f77b4','#ff7f0e','#2ca02c','#d62728','#9467bd','#8c564b','#e377c2','#7f7f7f','#bcbd22','#17becf', '#1f77b4','#ff7f0e','#2ca02c','#d62728','#9467bd','#8c564b','#e377c2','#7f7f7f','#bcbd22','#17becf'], rotations=[0,0]):     
   
    num_categories = len(plot_data[labels].unique() )
    plot_colors    = {a:b for a,b in zip( plot_data[labels].unique(), all_colors )}
    
    
    fig = px.pie(plot_data, values='num_assemblies', names=labels, hole=0.4, facet_col='root_taxonomy', width=plot_width, height=plot_height)
    fig.update_traces(hoverinfo="label+percent+name")

    current_annotations = [annotation.text.split('=')[1] for annotation in fig.layout.annotations]
    new_annotations = []
    for i in range( len(fig.data) ):
        fig.data[i].domain = {'x': [0.30, 1], 'y': [0.0, 1.0]} if i == 1 else fig.data[i].domain
        new_annotations.append( dict(text=current_annotations[i], x=sum(fig.data[i].domain.x) / 2, y=0.45,
                          font_size=25, showarrow=False, xanchor="center", font_family='sans-serif') )
    fig.update_layout(
        showlegend=False,
        # Add annotations in the center of the donut pies.
        annotations=new_annotations,
        font=dict(
            family='sans-serif',
            size=18,  # Set the font size here
        ),
    )
    fig.update_traces(texttemplate='%{label} %{percent:.2%}', insidetextorientation = 'horizontal' )
    
    fig.data[0].rotation = rotations[0]
    if len(fig.data) != 1:
        fig.data[1].rotation = rotations[1]
    
    for plot_index in range( len(fig.data) ):
        fig.data[plot_index].marker.colors = [ plot_colors[label] for label in fig.data[plot_index].labels ] 
    return fig
    
def plot_sequencing_targets(data_label='', data_table='', data_filter='', rotations=[0,0]):
    intermediate_query = f"""
    SELECT
        '{data_label}' AS data_label,
        STAT_root_taxonomy AS root_taxonomy,
        SRA_what_was_sequenced AS sequencing_target,
        'Eukaryota' IN SRA_what_was_sequenced_root_taxonomy_labels  AS eurkaryotic_sequencing_target,
        CASE
            WHEN SRA_what_was_sequenced LIKE '%metagenome%' THEN 'Metagenome'
            WHEN SRA_what_was_sequenced IN ('Homo sapiens', 'Mus musculus', 'Canis lupus familiaris', 'Gallus gallus') THEN SRA_what_was_sequenced
            WHEN LENGTH(SRA_what_was_sequenced_root_taxonomy_labels) = 1 AND SRA_what_was_sequenced_root_taxonomy_labels[1] IN ('Archaea', 'Bacteria') THEN 'Microbial sequencing project'
        ELSE 'Other'
        END AS sequencing_target_category,
        COUNT(*) AS num_assemblies
    FROM read_parquet('{data_table}')
    WHERE {data_filter}
    GROUP BY ALL    
    """
    intermediate_data = duckdb.sql( intermediate_query ).df()
    results = {f'sequencing_targets-intermediate' : (intermediate_query, ('tsv', intermediate_data), None) }

    plot_query = f"""
    SELECT
        data_label,
        root_taxonomy,
        sequencing_target_category,
        SUM(num_assemblies) AS num_assemblies
    FROM intermediate_data
    GROUP BY ALL
    """
    plot_data = duckdb.sql( plot_query ).df()
    fig = plot_meta_data(plot_data, 'sequencing_target_category', rotations=rotations)
    return results | {f'sequencing_targets': (plot_query, ('tsv', plot_data), ('plotly', fig, {}) )}


def plot_sequencing_types(data_label='', data_table='', data_filter='', rotations=[0,0], threshold='0.02'):
    intermediate_query = f"""
    WITH intermediate_data AS
    (
        SELECT
            '{data_label}' AS data_label,
            STAT_root_taxonomy AS root_taxonomy,
            concat_ws('|', SRA_library_source, SRA_assay_type) AS library_assay,
            COUNT(*) AS num_assemblies
        FROM read_parquet('{data_table}')
        WHERE {data_filter}
        GROUP BY ALL   
    )
    SELECT
        *,
        SUM(num_assemblies) OVER (PARTITION BY data_label, root_taxonomy) AS total_assemblies
    FROM intermediate_data
    """
    intermediate_data = duckdb.sql( intermediate_query ).df()
    results = {f'sequencing_types-intermediate' : (intermediate_query, ('tsv', intermediate_data), None) }

    plot_query = f"""
    WITH middle_data AS
    (
        SELECT 
            data_label, 
            root_taxonomy, 
            CASE 
                WHEN (num_assemblies/total_assemblies) >= {threshold} THEN library_assay 
                ELSE 'OTHER' 
            END AS library_assay,
            num_assemblies,
            total_assemblies
        FROM intermediate_data
    )
    SELECT
        data_label,
        root_taxonomy,
        library_assay,
        SUM(num_assemblies) AS num_assemblies,
        total_assemblies
    FROM middle_data
    GROUP BY ALL
    """
    plot_data = duckdb.sql( plot_query ).df()
    fig = plot_meta_data(plot_data, 'library_assay', rotations=rotations)
    return results | {f'sequencing_types': (plot_query, ('tsv', plot_data), ('plotly', fig, {}) )}
    


def plot_quality_ANI_distribution(target_quality='High'):
    sql_parameters = {
    'target_quality' : target_quality,
    'data_table' : ATTEMPTED_ASSEMBLIES_DATA,
    'successful_assembly' : SUCCESSFUL_ATTEMPTED_ASSEMBLY,
    'novel_assembly' : NOVEL_ATTEMPTED_ASSEMBLY
    }
    sql_file = 'SQL_queries/PLOTS/ATTEMPTED_ASSEMBLIES/novel_assemblies/ANI_distribution.sql'
    plot_query, plot_data = run_sql_query(sql_file, parameters = sql_parameters)
    
    plot = alt.Chart(plot_data).transform_density(
        'global_ANI',
        groupby=['assembly_data_label'],
        as_=['global_ANI', 'density'],
    ).mark_line().encode(
        x=alt.X("global_ANI:Q").title('ANI (%)'),
        y='density:Q',
        color=alt.Color('assembly_data_label', legend=alt.Legend(title=''))
    )
        
    return {f'{target_quality}_quality-ANI_distribution': (plot_query, ('tsv', plot_data), ('altair', plot, {}) ) }


def plot_assembly_outcomes(num_bins=50):
    x_label=f"printf('[%,.2f %,.2f%s', adjusted_min_coverage, adjusted_max_coverage, CASE WHEN bin = {num_bins} THEN ']' ELSE ')' END )"
    x_axis_title='Estimated Coverage (min coverage, max_coverage)'
    color_map = {"High":"#54a24bff","Medium":"#3e4989","Low":"#72b7b2ff","Poor":"#f58518ff","Failed":"#e45756ff"}

    sql_parameters = {
    'num_bins' : num_bins,
    'data_table' : ATTEMPTED_ASSEMBLIES_DATA,
    'novel_assembly' : NOVEL_ATTEMPTED_ASSEMBLY,
    'x_label' : x_label
    }
    sql_file = 'SQL_queries/PLOTS/ATTEMPTED_ASSEMBLIES/novel_assemblies/assemblies_stacked_bar_chart.sql'
    plot_query, plot_data = run_sql_query(sql_file, parameters = sql_parameters)
    
    bars_order = duckdb.sql("SELECT DISTINCT x_label FROM plot_data ORDER BY bin ASC").df().x_label.to_list()
    plot = alt.Chart(plot_data).mark_bar().encode(
            x=alt.X("x_label:N", title=x_axis_title, sort=bars_order ),
            y=alt.Y(
                "count(plot_label):Q",
                stack="normalize",                 # <-- converts stacked totals to percentages
                axis=alt.Axis(format=".0%"),     # show 0–100%
                title="Percent of Assemblies",
                
            ),
            color=alt.Color("plot_label:N", title="Assembly Status",
                            sort=alt.Sort( list(color_map.keys()) ),
                            scale=alt.Scale( domain=list(color_map.keys()), range=list(color_map.values())) ),
            order=alt.Order('label_order:Q'),
            tooltip=list(plot_data.columns)
    )
    return {f'assembly_outcomes': (plot_query, ('tsv', plot_data), ('altair', plot, {}) ) }