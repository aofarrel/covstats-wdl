#!/bin/bash

filePath="/Users/ash/Documents/aaa_test_files/bam-1000genomes/NA12878.chrom20.ILLUMINA.bwa.CEU.low_coverage.20121211.bam"
baseFile=$(basename "${filePath}")
echo ${filePath} # output as expected
echo ${baseFile} # output as expected