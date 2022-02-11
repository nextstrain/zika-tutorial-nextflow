#! /usr/bin/env nextflow

nextflow.enable.dsl=2

process index {
    publishDir "$params.outdir/01_Index", mode: 'copy'
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
    publishDir "$params.outdir/02_Filter", mode: 'copy'
    input: tuple path(sequences), path(sequence_index), path(metadata), path(exclude)
    output: path("filtered.fasta")
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
    publishDir "$params.outdir/03_Align", mode: 'copy'
    input: tuple path(filtered), path(reference)
    output: path("aligned.fasta")
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
    publishDir "$params.outdir/04_Tree", mode: 'copy'
    input: path(aligned)
    output: path("${aligned.simpleName}.nwk")
    script:
    """
    ${augur_app} tree \
        --alignment ${aligned} \
        --output ${aligned.simpleName}.nwk
    """
}

process refine {
    publishDir "$params.outdir/05_Refine", mode: 'copy'
    input: tuple path(tree_raw), path(aligned), path(metadata)
    output: tuple path("tree.nwk"), path("branch_lengths.json")
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
    publishDir "$params.outdir/06_Ancestral", mode: 'copy'
    input: tuple path(tree), path(aligned)
    output: path("nt_muts.json")
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
    publishDir "$params.outdir/07_Translate", mode: 'copy'
    input: tuple path(tree), path(nt_muts), path(reference)
    output: path("aa_muts.json")
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
    publishDir "$params.outdir/08_Traits", mode: 'copy'
    input: tuple path(tree), path(metadata)
    output: path("traits.json")
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
    publishDir "$params.outdir", mode: 'copy'
    input: tuple path(tree), path(metadata), path(branch_lengths), \
      path(traits), path(nt_muts), path(aa_muts), path(colors), \
      path(lat_longs), path(auspice_config)
    output: path("auspice")
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
}