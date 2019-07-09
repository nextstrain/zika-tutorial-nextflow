#!/usr/bin/env nextflow

sequences = file('data/sequences.fasta')
metadata = file('data/metadata.tsv')
exclude = file('config/dropped_strains.txt')
reference = file('config/zika_outgroup.gb')
colors = file('config/colors.tsv')
lat_longs = file('config/lat_longs.tsv')
auspice_config = file ('config/auspice_config.json')

process filter {

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


filtered
  .collectFile(name: 'results/filtered.fasta', newLine: true)
  .println { "Filtered FASTA saved to file: $it" }

aligned
  .collectFile(name: 'results/aligned.fasta', newLine: true)
  .println { "Aligned FASTA saved to file: $it" }

tree_raw
  .collectFile(name: 'results/tree_raw.nwk', newLine: true)
  .println { "Raw Newick tree saved to file: $it" }

tree
  .collectFile(name: 'results/tree.nwk', newLine: true)
  .println { "Refined Newick tree saved to file: $it" }

branch_lengths
  .collectFile(name: 'results/branch_lengths.json', newLine: true)
  .println { "Branch lengths node JSON saved to file: $it" }

nt_muts
  .collectFile(name: 'results/nt_muts.json', newLine: true)
  .println { "Nucleotide mutations node JSON saved to file: $it" }

aa_muts
  .collectFile(name: 'results/aa_muts.json', newLine: true)
  .println { "Amino acid mutations node JSON saved to file: $it" }

traits
  .collectFile(name: 'results/traits.json', newLine: true)
  .println { "Traits node JSON saved to file: $it" }

auspice_tree
  .collectFile(name: 'auspice/zika_tree.json', newLine: true)
  .println { "Auspice tree JSON saved to file: $it" }

auspice_meta
  .collectFile(name: 'auspice/zika_meta.json', newLine: true)
  .println { "Auspice meta JSON saved to file: $it" }  
