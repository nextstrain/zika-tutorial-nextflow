#! /usr/bin/env bash
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=16
#SBATCH --time=24:00:00
#SBATCH --job-name=Zika
#SBATCH --output=R-%x.%J.out
#SBATCH --error=R-%x.%J.err
##SBATCH --mail-user=USERNAME@email.edu
##SBATCH --mail-type=begin,end

set -e
set -u

start=`date +%s`

# === Load Modules here
module load Nextflow

source /home/${USER}/miniconda3/etc/profile.d/conda.sh
conda activate /home/${USER}/miniconda3/envs/nextstrain

# === Set working directory and in/out variables
cd ${SLURM_SUBMIT_DIR}

# === Main Program
nextflow run nextstrain/zika-tutorial-nextflow \
	 --sequences "data/sequences.fasta" \
	 --metadata "data/metadata.tsv" \
	 --colors "data/colors.tsv" \
	 --auspice_config "data/auspice_config.json" \
	 --lat_longs "data/lat_longs.tsv" \
	 --colors "data/colors.tsv" \
	 --exclude "data/dropped_strains.txt" \
	 --reference "data/zika_outgroup.gb" \
	 -resume \
	 -profile slurm

end=`date +%s`

# === Log msgs and resource use                          
scontrol show job ${SLURM_JOB_ID}
echo "ran runner.slurm: " `date` "; Execution time: " $((${end}-${start})) " seconds" >> LOGGER.txt
