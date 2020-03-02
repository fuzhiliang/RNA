#!/usr/bin/env bash
usage() {
    NAME=$(basename $0)
    cat <<EOF
Usage:
  ${NAME} [output_dir]
Wrapper script for HISAT2/StringTie RNA-Seq analysis protocol.
In order to configure the pipeline options (input/output files etc.)
please copy and edit a file rnaseq_pipeline.config.sh which must be
placed in the current (working) directory where this script is being launched.

Output directories "hisat2" and "ballgown" will be created in the 
current working directory or, if provided, in the given <output_dir>
(which will be created if it does not exist).

EOF
}

OUTDIR="."
if [[ "$1" ]]; then
 if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  exit 1
 fi
 OUTDIR=$1
fi

## load variables
if [[ ! -f ./rnaseq_pipeline.config.sh ]]; then
 usage
 echo "Error: configuration file (rnaseq_pipeline.config.sh) missing!"
 exit 1
fi

source ./rnaseq_pipeline.config.sh
WRKDIR=$(pwd -P)
errprog=""
if [[ ! -x $SAMTOOLS ]]; then
    errprog="samtools"
fi
if [[ ! -x $HISAT2 ]]; then
    errprog="hisat2"
fi
if [[ ! -x $STRINGTIE ]]; then
    errprog="stringtie"
fi

if [[ "$errprog" ]]; then    
  echo "ERROR: $errprog program not found, please edit the configuration script."
  exit 1
fi

if [[ ! -f rnaseq_ballgown.R ]]; then
   echo "ERROR: R script rnaseq_ballgown.R not found in current directory!"
   exit 1
fi

#determine samtools version
newsamtools=$( ($SAMTOOLS 2>&1) | grep 'Version: 1\.')

set -e
#set -x

if [[ $OUTDIR != "." ]]; then
  mkdir -p $OUTDIR
  cd $OUTDIR
fi

SCRIPTARGS="$@"
ALIGNLOC=./hisat2
BALLGOWNLOC=./ballgown

LOGFILE=./run.log

for d in "$TEMPLOC" "$ALIGNLOC" "$BALLGOWNLOC" ; do
 if [ ! -d $d ]; then
    mkdir -p $d
 fi
done

# main script block
pipeline() {

echo [`date +"%Y-%m-%d %H:%M:%S"`] "#> START: " $0 $SCRIPTARGS

for ((i=0; i<=${#reads1[@]}-1; i++ )); do
    sample="${reads1[$i]%%.*}"
    sample="${sample%_*}"
    stime=`date +"%Y-%m-%d %H:%M:%S"`
    echo "[$stime] Processing sample: $sample"
    echo [$stime] "   * Alignment of reads to genome (HISAT2)"
    $HISAT2 -p $NUMCPUS --dta -x ${GENOMEIDX} \
     -1 ${FASTQLOC}/${reads1[$i]} \
     -2 ${FASTQLOC}/${reads2[$i]} \
     -S ${TEMPLOC}/${sample}.sam 2>${ALIGNLOC}/${sample}.alnstats
    echo [`date +"%Y-%m-%d %H:%M:%S"`] "   * Alignments conversion (SAMTools)"
    if [[ "$newsamtools" ]]; then
     $SAMTOOLS view -S -b ${TEMPLOC}/${sample}.sam | \
      $SAMTOOLS sort -@ $NUMCPUS -o ${ALIGNLOC}/${sample}.bam -
    else
     $SAMTOOLS view -S -b ${TEMPLOC}/${sample}.sam | \
      $SAMTOOLS sort -@ $NUMCPUS - ${ALIGNLOC}/${sample}
    fi
    #$SAMTOOLS index ${ALIGNLOC}/${sample}.bam
    #$SAMTOOLS flagstat ${ALIGNLOC}/${sample}.bam
    
    #echo "..removing intermediate files"
    rm ${TEMPLOC}/${sample}.sam
    #rm ${TEMPLOC}/${sample}.unsorted.bam

    echo [`date +"%Y-%m-%d %H:%M:%S"`] "   * Assemble transcripts (StringTie)"
    $STRINGTIE -p $NUMCPUS -G ${GTFFILE} -o ${ALIGNLOC}/${sample}.gtf \
     -l ${sample} ${ALIGNLOC}/${sample}.bam
    echo "$STRINGTIE -p $NUMCPUS -G ${GTFFILE} -o ${ALIGNLOC}/${sample}.gtf \
     -l ${sample} ${ALIGNLOC}/${sample}.bam "
done

## merge transcript file
echo [`date +"%Y-%m-%d %H:%M:%S"`] "#> Merge all transcripts (StringTie)"
ls -1 ${ALIGNLOC}/*.gtf > ${ALIGNLOC}/mergelist.txt

$STRINGTIE --merge -p $NUMCPUS -G  ${GTFFILE} \
    -o ${BALLGOWNLOC}/stringtie_merged.gtf ${ALIGNLOC}/mergelist.txt
echo "$STRINGTIE --merge -p $NUMCPUS -G  ${GTFFILE} \
    -o ${BALLGOWNLOC}/stringtie_merged.gtf ${ALIGNLOC}/mergelist.txt"
## estimate transcript abundance
echo [`date +"%Y-%m-%d %H:%M:%S"`] "#> Estimate abundance for each sample (StringTie)"
for ((i=0; i<=${#reads1[@]}-1; i++ )); do
    sample="${reads1[$i]%%.*}"
    dsample="${sample%%_*}"
    sample="${sample%_*}"
    if [ ! -d ${BALLGOWNLOC}/${dsample} ]; then
       mkdir -p ${BALLGOWNLOC}/${dsample}
    fi
    $STRINGTIE -e -B -p $NUMCPUS -G ${BALLGOWNLOC}/stringtie_merged.gtf \
    -o ${BALLGOWNLOC}/${dsample}/${dsample}.gtf ${ALIGNLOC}/${sample}.bam
    echo "$STRINGTIE -e -B -p $NUMCPUS -G ${BALLGOWNLOC}/stringtie_merged.gtf \
    -o ${BALLGOWNLOC}/${dsample}/${dsample}.gtf ${ALIGNLOC}/${sample}.bam"
done

echo [`date +"%Y-%m-%d %H:%M:%S"`] "#> Generate the DE tables (Ballgown)"

/usr/bin/Rscript ${WRKDIR}/rnaseq_ballgown.R ${PHENODATA}
echo "/usr/bin/Rscript ${WRKDIR}/rnaseq_ballgown.R ${PHENODATA}"
### This should generate the DE tables in the output directory: 
###      chrX_transcripts_results.csv
###      chrX_genes_results.csv

echo [`date +"%Y-%m-%d %H:%M:%S"`] "#> DONE."
} #pipeline end

pipeline 2>&1 | tee $LOGFILE
