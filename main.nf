#!/usr/bin/env nextflow

sequences = file('data/sequences.fasta')
metadata = file('data/metadata.tsv')
exclude = file('config/dropped_strains.txt')
reference = file('config/zika_outgroup.gb')
colors = file('config/colors.tsv')
lat_longs = file('config/lat_longs.tsv')
auspice_config = file ('config/auspice_config.json')

process filter {

    publishDir("results/")

    input:
    file 'sequences.fasta' from sequences
    file 'metadata.tsv' from metadata
    file 'dropped_strains.txt' from exclude

    output:
    file 'filtered.fasta' into filtered

    script:
    """
    augur filter \
        --sequences sequences.fasta \
        --metadata metadata.tsv \
        --exclude dropped_strains.txt \
        --output filtered.fasta \
        --group-by country year month \
        --sequences-per-group 20 \
        --min-date 2012
    """

}

process align {

    publishDir("results/")

    input:
    file 'filtered.fasta' from filtered
    file 'reference.gb' from reference

    output:
    file 'aligned.fasta' into aligned

    script:
    """
    augur align \
        --sequences filtered.fasta \
        --reference-sequence reference.gb \
        --output aligned.fasta \
        --fill-gaps
    """

}

process tree {

    publishDir("results/")

    input:
    file 'aligned.fasta' from aligned

    output:
    file 'tree_raw.nwk' into tree_raw

    script:
    """
    augur tree \
        --alignment aligned.fasta \
        --output tree_raw.nwk
    """

}

process refine {

    publishDir("results/")

    input:
    file 'tree_raw.nwk' from tree_raw
    file 'aligned.fasta' from aligned
    file 'metadata.tsv' from metadata

    output:
    file 'tree.nwk' into tree
    file 'branch_lengths.json' into branch_lengths

    script:
    """
    augur refine \
        --tree tree_raw.nwk \
        --alignment aligned.fasta \
        --metadata metadata.tsv \
        --output-tree tree.nwk \
        --output-node-data branch_lengths.json \
        --timetree \
        --coalescent opt \
        --date-confidence \
        --date-inference marginal \
        --clock-filter-iqd 4
    """

}

process ancestral {

    publishDir("results/")

    input:
    file 'tree.nwk' from tree
    file 'aligned.fasta' from aligned

    output:
    file 'nt_muts.json' into nt_muts

    script:
    """
    augur ancestral \
        --tree tree.nwk \
        --alignment aligned.fasta \
        --output nt_muts.json \
        --inference joint
    """

}

process translate {

    publishDir("results/")

    input:
    file 'tree.nwk' from tree
    file 'nt_muts.json' from nt_muts
    file 'reference.gb' from reference

    output:
    file 'aa_muts.json' into aa_muts

    script:
    """
    augur translate \
        --tree tree.nwk \
        --ancestral-sequences nt_muts.json \
        --reference-sequence reference.gb \
        --output aa_muts.json
    """

}

process traits {

    publishDir("results/")

    input:
    file 'tree.nwk' from tree
    file 'metadata.tsv' from metadata

    output:
    file 'traits.json' into traits

    script:
    """
    augur traits \
        --tree tree.nwk \
        --metadata metadata.tsv \
        --output traits.json \
        --columns region country \
        --confidence
    """

}

process export {

    publishDir("auspice/", mode: 'copy')

    input:
    file 'tree.nwk' from tree
    file 'metadata.tsv' from metadata
    file 'branch_lengths.json' from branch_lengths
    file 'traits.json' from traits
    file 'nt_muts.json' from nt_muts
    file 'aa_muts.json' from aa_muts
    file 'colors.tsv' from colors
    file 'lat_longs.tsv' from lat_longs
    file 'auspice_config.json' from auspice_config

    output:
    file 'tree.json' into auspice_tree
    file 'meta.json' into auspice_meta

    script:
    """
    augur export \
        --tree tree.nwk \
        --metadata metadata.tsv \
        --node-data branch_lengths.json traits.json nt_muts.json aa_muts.json \
        --colors colors.tsv \
        --lat-longs lat_longs.tsv \
        --auspice-config auspice_config.json \
        --output-tree tree.json \
        --output-meta meta.json
    """

}
