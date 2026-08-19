#!/usr/bin/env python
# coding: utf-8

from data_sources import *
from plotting_functions import *
import argparse



PROPOSED_ASSEMBLIES_FILTER = f"({NOVEL_PROPOSED_ASSEMBLY}) = true AND ({PROPOSED_ASSEMBLY_COVERAGE}) >= 1 AND STAT_root_taxonomy IN ('Archaea', 'Bacteria')"
ATTEMPTED_ASSEMBLIES_FILTER = f"({NOVEL_ATTEMPTED_ASSEMBLY}) = true AND {SUCCESSFUL_ATTEMPTED_ASSEMBLY}"
NO_SANDPIPER = "SRA_accession NOT IN ( SELECT SRA_accession FROM read_parquet('SECONDARY_DATA_TABLES/SANDPIPER_COMPARISON/raw_sandpiper_data.parquet') )"

def TO_PLOT(output_folder):
    SRA_POTENTIAL_OUTPUT_ROOT               = f'{output_folder}/SRA_potential'
    SRA_OVERALL_POTENTIAL                   = f'{SRA_POTENTIAL_OUTPUT_ROOT}/overall_SRA_potential'
    SRA_SINGLETONS_POTENTIAL                = f'{SRA_POTENTIAL_OUTPUT_ROOT}/singletons_SRA_potential'
    
    ATTEMPTED_ASSEMBLIES_OUPUT_ROOT         = f'{output_folder}/attempted_assemblies'
    ATTEMPTED_NOVEL_OUTPUT_ROOT             = f'{ATTEMPTED_ASSEMBLIES_OUPUT_ROOT}/novel_assemblies'
    ATTEMPTED_NOVEL_SUCCESSFULL_OUTPUT_ROOT = f'{ATTEMPTED_NOVEL_OUTPUT_ROOT}/successful'
    
    GENERAL_PLOTS = [
                (plot_genbank_overview, f'{output_folder}/GenBank_overview/', {}),
                (plot_overall_SRA_potential, SRA_OVERALL_POTENTIAL, {}),
                (plot_singletons_SRA_potential, SRA_SINGLETONS_POTENTIAL, {}),
                (plot_novel_fraction_failed, f'{ATTEMPTED_NOVEL_OUTPUT_ROOT}/failed/fraction_failed', {'failure_equation':"assembly_status != 'assembled'"}),
                (plot_novel_fraction_failed, f'{ATTEMPTED_NOVEL_OUTPUT_ROOT}/unsuccessful/fraction_failed',  {'failure_equation':UNSUCCESSFUL_ATTEMPTED_ASSEMBLY}),
                (plot_novel_successful_checkm_distribution, f'{ATTEMPTED_NOVEL_SUCCESSFULL_OUTPUT_ROOT}/checkm_distribution', {}),
                (plot_novel_successful_contig_length_distribution, f'{ATTEMPTED_NOVEL_SUCCESSFULL_OUTPUT_ROOT}/medium_high_contig_lengths', {}),
                (plot_quality_ANI_distribution, f'{ATTEMPTED_NOVEL_SUCCESSFULL_OUTPUT_ROOT}/High_ANI_distribution', {}),
                (plot_assembly_outcomes, f'{ATTEMPTED_NOVEL_SUCCESSFULL_OUTPUT_ROOT}/assembly_outcomes', {})
    ]
    
    META_DATA_PLOTS = []
    for folder, sql_filter in (('SANDPIPER_INCLUDED', ''), ('SANDPIPER_EXCLUDED', f'AND {NO_SANDPIPER}')):
        for func, label in ((plot_sequencing_targets, 'sequencing_targets'), (plot_sequencing_types, 'sequencing_types')):
            final_folder = f'{folder}/{label}'
            label = folder.replace('_', ' ')
    
            META_DATA_PLOTS += [
                        (func, f'{SRA_OVERALL_POTENTIAL}/{final_folder}', {'data_table':POTENTIAL_ASSEMBLIES_DATA, 'data_filter': f'{PROPOSED_ASSEMBLIES_FILTER} {sql_filter}', 'rotations': [35, 90+45], 'data_label' : 'novel microbial SRA potential >= 1X'}),
                        
                        (func, f'{ATTEMPTED_NOVEL_SUCCESSFULL_OUTPUT_ROOT}/RANDOM-1000X/{final_folder}', {'data_table':ATTEMPTED_ASSEMBLIES_DATA, 'data_filter': f"{ATTEMPTED_ASSEMBLIES_FILTER} AND assembly_data_label != 'TARANTELLAE_ANALYSIS' {sql_filter}", 'rotations': [-85, 90+45+45], 'data_label' : f'{label}|1000X,Random|novel|successful'}),
                         (func, f'{ATTEMPTED_NOVEL_SUCCESSFULL_OUTPUT_ROOT}/RANDOM/{final_folder}', {'data_table':ATTEMPTED_ASSEMBLIES_DATA, 'data_filter': f"{ATTEMPTED_ASSEMBLIES_FILTER} AND assembly_data_label = 'RANDOM_SINGLETONS' {sql_filter}", 'rotations': [-85, 90+45+45], 'data_label' : f'{label}|Random|novel|successful'}),
                         (func, f'{ATTEMPTED_NOVEL_SUCCESSFULL_OUTPUT_ROOT}/1000X/{final_folder}', {'data_table':ATTEMPTED_ASSEMBLIES_DATA, 'data_filter': f"{ATTEMPTED_ASSEMBLIES_FILTER} AND assembly_data_label = 'TOP_N_SINGLETONS' {sql_filter}", 'rotations': [-85, 90+45+45], 'data_label' : f'{label}|1000X|novel|successful'}),
                         (func, f'{ATTEMPTED_NOVEL_SUCCESSFULL_OUTPUT_ROOT}/TARANTELLAE/{final_folder}', {'data_table':ATTEMPTED_ASSEMBLIES_DATA,  'data_filter': f"{ATTEMPTED_ASSEMBLIES_FILTER} AND assembly_data_label = 'TARANTELLAE_ANALYSIS' {sql_filter}", 'rotations': [-85, 90+45+45], 'data_label' : f'{label}|Tarantellae|novel|successful',}),
            ]
    
    
    return GENERAL_PLOTS + META_DATA_PLOTS

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Create plots")
    parser.add_argument(
        "-f", "--force",
        action="store_true",
        help="Overwrite existing plots"
    )
    parser.add_argument(
        "-o", "--output_folder",
        default='PLOTS',
        help="Where to put the plots"
    )
    
    args = parser.parse_args()

    for plotting_function, output_folder, func_parameters in TO_PLOT(args.output_folder):
        plot_output = create_plot(plotting_function, output_folder, args.force, func_parameters)
