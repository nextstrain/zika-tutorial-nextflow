#! /usr/bin/env nextflow

nextflow.enable.dsl=2

process index {
    publishDir("$params.outdir")
    input: path(sequences)
    output: tuple path("$sequences"), path("sequence_index.tsv")
    script:
    """
    #! /usr/bin/env bash
    ${augur_app} index \
      --sequences ${sequences} \
      --output sequence_index.tsv
    """
}

process filter {
    publishDir("$params.outdir")

    input: tuple path(sequences), path(sequence_index), path(metadata), path(exclude)
 //   file 'sequences.fasta' from sequences
 //   file 'metadata.tsv' from metadata
 //   file 'dropped_strains.txt' from exclude

    output: path("filtered.fasta")
//    file 'filtered.fasta' into filtered

    script:
    """
    ${augur_app} filter \
        --sequences ${sequences} \
        --sequence-index ${sequence_index} \
        --metadata ${metadata} \
        --exclude ${exclude} \
        --output filtered.fasta \
        --group-by country year month \
        --sequences-per-group 20 \
        --min-date 2012
    """

}

process align {
    publishDir("$params.outdir")

    input: tuple path(filtered), path(reference)
//    file 'filtered.fasta' from filtered
//    file 'reference.gb' from reference

    output: path("aligned.fasta")
//    file 'aligned.fasta' into aligned

    script:
    """
    ${augur_app} align \
        --sequences ${filtered} \
        --reference-sequence ${reference} \
        --output aligned.fasta \
        --fill-gaps
    """

}

process tree {
    publishDir("$params.outdir")

    input: path(aligned)
//    file 'aligned.fasta' from aligned

    output: path("${aligned.simpleName}.nwk")
//    file 'tree_raw.nwk' into tree_raw

    script:
    """
    ${augur_app} tree \
        --alignment ${aligned} \
        --output ${aligned.simpleName}.nwk
    """

}

process refine {
    publishDir("$params.outdir")

    input: tuple path(tree_raw), path(aligned), path(metadata)
//    file 'tree_raw.nwk' from tree_raw
//    file 'aligned.fasta' from aligned
//    file 'metadata.tsv' from metadata

    output: tuple path("tree.nwk"), path("branch_lengths.json")
//    file 'tree.nwk' into tree // hmm, I guess I could drop the "raw"
//    file 'branch_lengths.json' into branch_lengths  // not sure if this is multiple trees or one... maybe just one

    script:
    """
    ${augur_app} refine \
        --tree ${tree_raw} \
        --alignment ${aligned} \
        --metadata ${metadata} \
        --output-tree tree.nwk\
        --output-node-data branch_lengths.json \
        --timetree \
        --coalescent opt \
        --date-confidence \
        --date-inference marginal \
        --clock-filter-iqd 4
    """
}

process ancestral {
    publishDir("$params.outdir")

    input: tuple path(tree), path(aligned)
//    file 'tree.nwk' from tree
//    file 'aligned.fasta' from aligned

    output: path("nt_muts.json")
 //   file 'nt_muts.json' into nt_muts

    script:
    """
    ${augur_app} ancestral \
        --tree ${tree} \
        --alignment ${aligned} \
        --output-node-data nt_muts.json \
        --inference joint
    """

}

process translate {
    publishDir("$params.outdir")

    input: tuple path(tree), path(nt_muts), path(reference)
//    file 'tree.nwk' from tree
//    file 'nt_muts.json' from nt_muts
//    file 'reference.gb' from reference

    output: path("aa_muts.json")
//    file 'aa_muts.json' into aa_muts

    script:
    """
    ${augur_app} translate \
        --tree ${tree} \
        --ancestral-sequences ${nt_muts} \
        --reference-sequence ${reference} \
        --output-node-data aa_muts.json
    """

}

process traits {
    publishDir("$params.outdir")

    input: tuple path(tree), path(metadata)
    //file 'tree.nwk' from tree
    //file 'metadata.tsv' from metadata

    output: path("traits.json")
//    file 'traits.json' into traits

    script:
    """
    ${augur_app} traits \
        --tree ${tree} \
        --metadata ${metadata} \
        --output traits.json \
        --columns region country \
        --confidence
    """
}

process export {
    publishDir("$params.outdir")

    input: tuple path(tree), path(metadata), path(branch_lengths), \
      path(traits), path(nt_muts), path(aa_muts), path(colors), \
      path(lat_longs), path(auspice_config)
//    file 'tree.nwk' from tree
//    file 'metadata.tsv' from metadata
//    file 'branch_lengths.json' from branch_lengths
//    file 'traits.json' from traits
//    file 'nt_muts.json' from nt_muts
//    file 'aa_muts.json' from aa_muts
//    file 'colors.tsv' from colors
//    file 'lat_longs.tsv' from lat_longs
//    file 'auspice_config.json' from auspice_config

    output: path("auspice/${tree.simpleName}.json")
// v2    path("tree_meta_finalout.json")
//    file 'tree.json' into auspice_tree
//   file 'meta.json' into auspice_meta

    script:
    """
    ${augur_app} export v2 \
        --tree ${tree} \
        --metadata ${metadata} \
        --node-data ${branch_lengths} \
                    ${traits} \
                    ${nt_muts} \
                    ${aa_muts} \
        --colors ${colors} \
        --lat-longs ${lat_longs} \
        --auspice-config ${auspice_config} \
        --output auspice/${tree.simpleName}.json
    """
//        --output tree_meta_finalout.json
}

// --output-tree tree.json \
// --output-meta meta.json