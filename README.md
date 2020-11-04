# covstats-wdl
[![WDL 1.0 shield](https://img.shields.io/badge/WDL-1.0-lightgrey.svg)](https://github.com/openwdl/wdl/blob/main/versions/1.0/SPEC.md)  [![Docker Repository on Quay](https://quay.io/repository/aofarrel/goleft-covstats/status "Docker Repository on Quay")](https://quay.io/repository/aofarrel/goleft-covstats)

A WDLized version of [goleft](https://github.com/brentp/goleft) covstats functions.

*covstats.wdl* runs covstats on an array of bam or cram files. For bam files, the user can also specify bai files to skip the `samtools index`ing step and allow for faster completion. The result is a text file that prints the filename, read length, and coverage of every input file, then the average coverage and read length for the entire array of inputs. However, all covstats entries are also reported as `this.txt` in each shard's working directory, which can assist in gaining more statistics or debugging (see Limitations).

For more WDLs from goleft, see [goleft-wdl](https://github.com/aofarrel/goleft-wdl/blob/main/README.md).

## Limitations
It turns out cram files are a different beast...

### Cannot generate coverage for crams
covstats cannot generate coverage information for CRAM files and will report a value of 0.00 for that statistic. Of course, if you have 0.00 values in your output, that will bring down the reported average coverage.

### Crams tend to process slower
Although cram files are supported except for coverage, they are slower to process than bam files, so if you have both, use the bams. Cram files also require the specification of a reference genome and are not processed any faster by the inclusion of an index (crai) file. This is due to the fact they have to be reprocessed with samtools.

### Cram/Ref mismatch
If the user inputs a cram file that was aligned to a different reference genome than the one that is being provided as an input, there is a *possibility* that goleft will not give proper output. Make sure your reference genomes match up, or consider using the alternative Docker container, which is better able to handle a spaghetti-like mess of crams if that is what you need to process.

### Silent errors
Due to the odd way error codes are handled in go and WDL, it is unfortunately possible for an error to occur in the covstats task but for the task itself to be incorrectly reported as a success. I have tried to account for the most common errors by limiting the chances of them occuring, reducing space for user errors, and adding manually checks but of course something may have slipped by me. Thankfully, a "silent" error happening in the covstats task will have a very recognizable signature, and will look like one of these two sitautions:
* The workflow overall we be reported as a success, but the final report will have values of zero for everything related to some or all of your cram files (occurs on the non-legacy container if there is a reference genome mismatch), not just coverage. This occurs during the cram/ref mismatch situation.
* The covstats task will be considered a success, but the workflow will fail on the report task. The actual error occurred in the covstats task, resulting in bogus output that the report task cannot parse.

## Alternative Docker Container
There already exists [another Docker container](https://quay.io/repository/biocontainers/goleft?tab=tags) for goleft, which older versions of this code relied upon. As it hasn't been updated in about two years and cannot be easily scanned for security purposes, I decided to make my own container. My container is the default and has an automated build upon pushing to this repo. These same differences in samtools appear to make my container run faster. That being said, the legacy container can better handle the above cram/ref mismatch situation, so of you are running on dozens of crams that may have been built with different reference genomes, consider setting `covstats.useLegacyContainer` to `true`.)

