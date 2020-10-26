#!/bin/bash

# run as bash cov.sh because otherwise <<< won't work 

# need a bai or else covstats will fail
samtools index in.bam

goleft covstats "in.bam" >> this.txt
COVOUT=$(head -2 this.txt | tail -1 this.txt)
read -a COVARRAY <<< "$COVOUT"
echo ${COVARRAY[11]} >> final.txt
