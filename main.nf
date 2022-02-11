#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// == Import reusable modules
include { index; filter; align; tree; refine;
          ancestral; translate; traits; export } from './modules/augur.nf'
// include any preprocessing modules, can add a flag for different viruses, can add default references for different viruses

// ===== MAIN WORKFLOW ========//

workflow {
    // Define input channels (could auto detect if input is gisaid auspice json file)
    // TODO: read in a fofn (file of file names, tsv) to run in parallel
    seq_ch = Channel.fromPath(params.sequences, checkIfExists:true)
    met_ch = Channel.fromPath(params.metadata, checkIfExists:true)
    exclude_ch = Channel.fromPath(params.exclude, checkIfExists:true)
    ref_ch = Channel.fromPath(params.reference, checkIfExists:true)
    colors_ch = Channel.fromPath(params.colors, checkIfExists:true)
    lat_longs_ch = Channel.fromPath(params.lat_longs, checkIfExists:true)
    auspice_config_ch = Channel.fromPath(params.auspice_config, checkIfExists:true)

    // === Preprocessing could go here, scripts can go into the bin folder

    // Run pipeline (chain together processes and add other params on the way)
    seq_ch 
      | index                 // INDEX
      | combine(met_ch) 
      | combine(exclude_ch) 
      | filter                // FILTER
      | combine(ref_ch ) 
      | align                 // ALIGN
      | tree                  // TREE
      | combine(align.out) 
      | combine(met_ch) 
      | refine                // REFINE

    // split augur refine's output into tree and branch length files
    tree_ch = refine.out | map{ n-> n.get(0) }
    bl_ch = refine.out | map{ n-> n.get(1) }

    tree_ch 
      | combine(align.out) 
      | ancestral             // ANCESTRAL

    tree_ch 
      | combine(ancestral.out) 
      | combine(ref_ch) 
      | translate             // TRANSLATE

    tree_ch 
      | combine(met_ch) 
      | traits                // TRAITS

    tree_ch 
      | combine(met_ch) 
      | combine(bl_ch) 
      | combine(traits.out) 
      | combine(ancestral.out) 
      | combine(translate.out) 
      | combine(colors_ch) 
      | combine(lat_longs_ch) 
      | combine(auspice_config_ch) 
      | export                // EXPORT
}
