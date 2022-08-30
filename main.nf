#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// ===== MODULES ==============//
// Import reusable and bespoke modules
include { index; filter; align; tree; refine;
          ancestral; translate; traits; export } from './modules/augur.nf'

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

// ===== MAIN WORKFLOW ========//

workflow {
    // Define input channels
    sequences_ch = Channel.fromPath(params.sequences, checkIfExists:true)
    metadata_ch = Channel.fromPath(params.metadata, checkIfExists:true)
    exclude_ch = Channel.fromPath(params.exclude, checkIfExists:true)
    reference_ch = Channel.fromPath(params.reference, checkIfExists:true)
    colors_ch = Channel.fromPath(params.colors, checkIfExists:true)
    lat_longs_ch = Channel.fromPath(params.lat_longs, checkIfExists:true)
    auspice_config_ch = Channel.fromPath(params.auspice_config, checkIfExists:true)

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
