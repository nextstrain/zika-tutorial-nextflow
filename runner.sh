#! /usr/bin/env bash

nextflow run nextstrain/zika-tutorial-nextflow \
 -resume

# Example of passing in your own files
#  nextflow run nextstrain/zika-tutorial-nextflow \
#  --sequences "data/sequences.fasta" \
#  --metadata "data/metadata.tsv" \
#  --colors "data/colors.tsv" \
#  --auspice_config "data/auspice_config.json" \
#  --lat_longs "data/lat_longs.tsv" \
#  --colors "data/colors.tsv" \
#  --exclude "data/dropped_strains.txt" \
#  --reference "data/zika_outgroup.gb" \
#  -resume

