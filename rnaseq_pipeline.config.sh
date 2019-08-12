## Configuration file for rnaseq_pipeline.sh
##
## Place this script in a working directory and edit it accordingly.
##
## The default configuration assumes that the user unpacked the 
## chrX_data.tar.gz file in the current directory, so all the input
## files can be found in a ./chrX_data sub-directory

#how many CPUs to use on the current machine?
NUMCPUS=12

#### Program paths ####

## optional BINDIR, using it here because these programs are installed in a common directory
#BINDIR=/usr/local/bin
HISAT2=/data2/fuzl/soft/hisat2-2.1.0/hisat2
STRINGTIE=/data2/fuzl/soft/stringtie-1.3.5.Linux_x86_64/stringtie
SAMTOOLS=/data2/fuzl/soft/samtools-1.9/samtools

#if these programs are not in any PATH directories, please edit accordingly:
#HISAT2=$(which hisat2)
#STRINGTIE=$(which stringtie)
#SAMTOOLS=$(which samtools)

#### File paths for input data
### Full absolute paths are strongly recommended here.
## Warning: if using relatives paths here, these will be interpreted 
## relative to the  chosen output directory (which is generally the 
## working directory where this script is, unless the optional <output_dir>
## parameter is provided to the main pipeline script)

## Optional base directory, if most of the input files have a common path
BASEDIR="/data2/fuzl/pipeline/RNA/hg19/chrX_data"
#BASEDIR=$(pwd -P)/chrX_data
#BASEDIR="/data2/fuzl/project/508/demo"
FASTQLOC="$BASEDIR/samples"
GENOMEIDX="$BASEDIR/indexes/chrX_tran"
GTFFILE="$BASEDIR/genes/chrX.gff3"
#GTFFILE="$BASEDIR/genes/chrX.gtf"
PHENODATA="$BASEDIR/geuvadis_phenodata.csv"  #分组信息

TEMPLOC="./tmp" #this will be relative to the output directory

## list of samples 
## (only paired reads, must follow _1.*/_2.* file naming convention)
reads1=(${FASTQLOC}/*_1.*)
reads1=("${reads1[@]##*/}")
reads2=("${reads1[@]/_1./_2.}")
