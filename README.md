# Nextstrain build for Zika virus tutorial

This repository provides the data and scripts associated with the [Zika virus tutorial](https://nextstrain.org/docs/getting-started/zika-tutorial). See the [original Zika build repository](https://github.com/nextstrain/zika) for more about the public build.

This repo is a conversion of the standard Snakemake workflow into the [Nextflow](https://www.nextflow.io/) workflow language.

```
git clone https://github.com/nextstrain/zika-tutorial-nextflow.git
cd zika-tutorial-nextflow
nextflow run main.nf
```

## Help Statement

Assuming you have a working installation of [Nextflow](https://www.nextflow.io/docs/latest/getstarted.html)

```
nextflow run nextstrain/zika-tutorial-nextflow -r main --help
```

<details><summary>See help statement</summary>

```
N E X T F L O W  ~  version 21.10.6
Launching `main.nf` [tiny_jepsen] - revision: 3efe125160

  Usage:
   The typical command for running the pipeline are as follows:
   nextflow run nextflow/zika-tutorial-nextflow -r main -profile docker
   
   Input Files:
   --sequences                        Sequences fasta [default: 'false']
   --metadata                         Metadata tsv file [default: 'false']
   --exclude                          List of excluded sequences file [default: 'false']
   --reference                        Reference genbank file [default: 'false']
   --colors                           Colors tsv file [default: 'false']
   --lat_longs                        Latitude and longituide file [default: 'false']
   --auspice_config                   Auspice config file [default: 'false']
   Optional augur arguments
   --filter_args                      Parameters passed to filter [default: '--group-by country year month --sequences-per-group 20 --min-date 2012']
   --align_args                       Parameters passed to filter [default: '--group-by country year month --sequences-per-group 20 --min-date 2012']
   --tree_args                        Parameters passed to filter [default: '--group-by country year month --sequences-per-group 20 --min-date 2012']
   --refine_args                      Parameters passed to filter [default: '--group-by country year month --sequences-per-group 20 --min-date 2012']
   --ancestral_args                   Parameters passed to filter [default: '--group-by country year month --sequences-per-group 20 --min-date 2012']
   --traits_args                      Parameters passed to filter [default: '--group-by country year month --sequences-per-group 20 --min-date 2012']
   Optional arguments:
   --augur_app                        Augur executable [default: 'augur']
   --outdir                           Output directory to place final output [default: 'results']
   --help                             This usage statement.
   --check_software                   Check if software dependencies are available.
```

</details>

## Demonstration

Augur commands were wrapped in processes (similar to Snakemake's rules) and placed in the `modules/augur.nf`. Nextflow processes were imported into `main.nf` and connected via Nextflow channels.

```
sequence_ch 
 | index                   // INDEX
 | combine(metadata_ch) 
 | combine(exclude_ch)
 | combine(channel.of("--group-by country year month --sequences-per-group 20 --min-date 2012"))
 | filter                  // FILTER
 | combine(reference_ch ) 
 | combine(channel.of("--fill-gaps"))
 | align                   // ALIGN
 | combine(channel.of(""))
 | tree                    // TREE
 | combine(align.out) 
 | combine(metadata_ch) 
 | combine(channel.of("--timetree --coalescent opt --date-confidence --date-inference marginal --clock-filter-iqd 4")) 
 | refine                  // REFINE
...
```

See `main.nf` for full details.

To run the workflow:

```
# (1) Install nextstrain or activate the nextstrain conda environment
conda activate nextstrain

# (2) Install nextflow via conda or mamba
conda install -c bioconda nextflow

# (3) Place the input files in the current directory in a "data" folder

# (4) Run pipeline on a set of input files
nextflow run nextstrain/zika-tutorial-nextflow \
         --sequences "data/sequences.fasta" \
         --metadata "data/metadata.tsv" \
         --colors "data/colors.tsv" \
         --auspice_config "data/auspice_config.json" \
         --lat_longs "data/lat_longs.tsv" \
         --colors "data/colors.tsv" \
         --exclude "data/dropped_strains.txt" \
         --reference "data/zika_outgroup.gb" \
         -resume

#> N E X T F L O W  ~  version 21.10.6
#> Launching `main.nf` [maniac_hypatia] - revision: d136460fdb
#> executor >  local (9)
#> [69/fb06ea] process > index (1)     [100%] 1 of 1 ✔
#> [14/54db50] process > filter (1)    [100%] 1 of 1 ✔
#> [c7/1a6fc7] process > align (1)     [100%] 1 of 1 ✔
#> [68/c3cfc9] process > tree (1)      [100%] 1 of 1 ✔
#> [1e/1d2fd1] process > refine (1)    [100%] 1 of 1 ✔
#> [f4/813036] process > ancestral (1) [100%] 1 of 1 ✔
#> [52/02e75d] process > translate (1) [100%] 1 of 1 ✔
#> [b7/55d75f] process > traits (1)    [100%] 1 of 1 ✔
#> [71/98c68b] process > export (1)    [100%] 1 of 1 ✔
#> WARN: Task runtime metrics are not reported when using macOS without a container engine
#> Completed at: 11-Feb-2022 10:54:14
#> Duration    : 1m 23s
#> CPU hours   : (a few seconds)
#> Succeeded   : 9
```

The output folder should look like:

```
results/
|_ 01_Index/          #<= contains output files for each step
|_ 02_Filter/
|_ 03_Align/
|_ 04_Tree/
|_ 05_Refine/
|_ 06_Ancestral/
|_ 07_Translate/
|_ 08_Traits/
|_ auspice/           #<= Final files! Use "nextstrain view results/auspice"
|
|_ report.html
|_ timeline.html      #<= runtime and memory use at each step
```

Based on Nextflow's timeline, the `refine` step seems to take the longest.

![](docs/timeline.png)
