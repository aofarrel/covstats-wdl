# covstats-wdl
[![WDL 1.0 shield](https://img.shields.io/badge/WDL-1.0-lightgrey.svg)](https://github.com/openwdl/wdl/blob/main/versions/1.0/SPEC.md)

A WDLized version of [goleft](https://github.com/brentp/goleft) covstats functions.

*covstats.wdl* runs covstats on an array of bam or cram files. The user can also specify bai files to skip the `samtools index`ing step and allow for faster completion. The result is a text file that prints the filename, read length, and coverage of every input file, then the average coverage and read length for the entire array of inputs. Although cram files are supported, they are **signifantly** slower to process than bam files and cannot estimate coverage, so if you have both, use the bams. Cram files also require the specification of a reference genome.

For more WDLs from goleft, see [goleft-wdl](https://github.com/aofarrel/goleft-wdl/blob/main/README.md).
