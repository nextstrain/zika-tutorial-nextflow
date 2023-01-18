#! /usr/bin/env nextflow

nextflow.enable.dsl=2

// ===== MODULES ==============//
// Import reusable and bespoke modules
include { index;
          filter;
          align;
          tree;
          refine;
          ancestral;
          translate;
          traits;
          export } from './modules/augur.nf'

// This section could include but is not limited to:
// 1) any bespoke modules for preprocessing data
// 2) any fine-tuned flags for different viruses
// 3) any specific default references for different viruses

process get_versions {
  publishDir "${params.outdir}", mode: 'copy'
  output: path("versions.txt")
  script:
  """
  #! /usr/bin/env bash
  augur --version &> versions.txt
  """
}

process fetch_zika_tutorial {
  publishDir "${params.outdir}/00_Data", mode: 'copy'
  output: tuple path("sequences.fasta"), path("metadata.tsv"), \
      path("auspice_config.json"), path("colors.tsv"), path("dropped_strains.txt"), path("lat_longs.tsv"), path("zika_outgroup.gb")
  script:
  """
  #! /usr/bin/env bash

  # pull data
  wget https://raw.githubusercontent.com/nextstrain/zika-tutorial/master/data/sequences.fasta
  sleep 0.5
  wget https://raw.githubusercontent.com/nextstrain/zika-tutorial/master/data/metadata.tsv
  sleep 0.5
  
  # pull default configs
  wget https://raw.githubusercontent.com/nextstrain/zika-tutorial/master/config/auspice_config.json
  sleep 0.5
  wget https://raw.githubusercontent.com/nextstrain/zika-tutorial/master/config/colors.tsv
  sleep 0.5
  wget https://raw.githubusercontent.com/nextstrain/zika-tutorial/master/config/dropped_strains.txt
  sleep 0.5
  wget https://raw.githubusercontent.com/nextstrain/zika-tutorial/master/config/lat_longs.tsv
  sleep 0.5
  wget https://raw.githubusercontent.com/nextstrain/zika-tutorial/master/config/zika_outgroup.gb
  """
}

def setDefaultIfNotDefined(given_filepath, default_ch, index_i){
  if(given_filepath == false){
    return(default_ch | map {n -> n.get(index_i)})
  } else {
    return(Channel.fromPath(given_filepath, checkIfExists:true))
  }
}

// ===== MAIN WORKFLOW ========//

workflow {
  // Define Input channels
  fetch_zika_tutorial()
  sequences_ch = setDefaultIfNotDefined(params.sequences, fetch_zika_tutorial.out, 0)
  metadata_ch = setDefaultIfNotDefined(params.metadata, fetch_zika_tutorial.out, 1)
  exclude_ch = setDefaultIfNotDefined(params.exclude, fetch_zika_tutorial.out, 5)
  reference_ch = setDefaultIfNotDefined(params.reference, fetch_zika_tutorial.out, 6)
  colors_ch = setDefaultIfNotDefined(params.colors, fetch_zika_tutorial.out, 3)
  lat_longs_ch = setDefaultIfNotDefined(params.lat_longs, fetch_zika_tutorial.out, 4)
  auspice_config_ch = setDefaultIfNotDefined(params.auspice_config, fetch_zika_tutorial.out, 2)

  // Run pipeline (chain together processes and add other params on the way)
  channel.of("zika")
    | combine(sequences_ch)
    | index                 // INDEX
    | combine(metadata_ch) 
    | combine(exclude_ch) 
    | combine(channel.of(params.filter_args))
    | filter                // FILTER
    | combine(reference_ch )
    | combine(channel.of(params.align_args))
    | align                 // ALIGN
    | combine(channel.of(params.tree_args))
    | tree                  // TREE
    | join(align.out) 
    | combine(metadata_ch)
    | combine(channel.of(params.refine_args)) 
    | refine                // REFINE
  // split augur refine's output into tree and branch length files
  tree_ch = refine.out 
    | map { n-> [n.get(0), n.get(1)] }
  branch_length_ch = refine.out 
    | map{ n-> [n.get(0), n.get(2)] }
  tree_ch 
    | join(align.out) 
    | combine(channel.of(params.ancestral_args))
    | ancestral             // ANCESTRAL
  tree_ch 
    | join(ancestral.out) 
    | combine(reference_ch) 
    | translate             // TRANSLATE
  tree_ch 
    | combine(metadata_ch) 
    | combine(channel.of(params.traits_args))
    | traits                // TRAITS
  node_data_ch = branch_length_ch
    | join(traits.out)
    | join(ancestral.out)
    | join(translate.out)
    | map {n -> [n.drop(1)]}
  tree_ch
    | combine(metadata_ch)
    | combine(node_data_ch)
    | combine(colors_ch) 
    | combine(lat_longs_ch) 
    | combine(auspice_config_ch)
    | export                // EXPORT
}
