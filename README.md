# covstats-wdl
[![WDL 1.0 shield](https://img.shields.io/badge/WDL-1.0-lightgrey.svg)](https://github.com/openwdl/wdl/blob/main/versions/1.0/SPEC.md)  [![Docker Repository on Quay](https://quay.io/repository/aofarrel/goleft-covstats/status "Docker Repository on Quay")](https://quay.io/repository/aofarrel/goleft-covstats)

*Note: Although this autobuilding Docker image currently relies on a pull from Google's golang image on Docker Hub and is hosted on Quay, it is immune to the current Quay-DockerHub pull issue, as the actual building is done on CirceCI which bypasses Quay's rate-limited build infrastructure.*

A WDLized and Dockerized version of [goleft](https://github.com/brentp/goleft) covstats functions. [Also registered on Dockstore!](https://dockstore.org/my-workflows/github.com/aofarrel/covstats-wdl)

For more WDLs from goleft, see [goleft-wdl](https://github.com/aofarrel/goleft-wdl/blob/main/README.md).

# Covstats.wdl
*covstats.wdl* runs [covstats](https://github.com/brentp/goleft/tree/master/covstats#covstats) on an array of bam or cram files.
## Inputs
* an array of bam files, cram files, or a combination of both
* [optional] bai index files for bam inputs
* [optional] reference genome  

If any of the inputs are cram files then specification of a reference genome is a **requirement.**
## Outputs
The result is a text file, `reports.txt`, that prints the filename, read length, and coverage of every input file, then the average coverage and read length for the entire array of inputs. However, all covstats entries are also reported as `this.txt` in each shard's working directory, which can assist in gaining more statistics or debugging.

# Checker.wdl
*checker.wdl* is the checker workflow for covstats.wdl and draws upon a truth file in the debug folder. Note that because the order which scattered processes go through input files can vary depending on platform, and that order influcences the order that outputs appear in the final output, reports.txt, so the checker workflow will attempt sort everything including the header line in alphabetical order. A non-sorted output will be included in the execution directory, although exactly where will depend on your platform. On Terra, in the Job Manager page, you can find it in the Job Manager page. On List View you will see the third step, report, and the non-sorted output will be listed as the output of that task.  

# Limitations
* covstats cannot generate coverage information for CRAM files and will report a value of 0.00 for that statistic  
* crams tend to process slower than bams due to how covstats reprocesses them with samtools  
* if the user inputs a cram file that was aligned to a different reference genome than the one that is being provided as an input, there is a *possibility* that goleft will not give proper output if using my image rather than the legacy image (see below)  

# Alternative (Legacy) Docker Image
There already exists [another Docker image](https://quay.io/repository/biocontainers/goleft?tab=tags) for goleft, which older versions of this code relied upon. As it hasn't been updated in about two years and cannot be easily scanned for security purposes, I decided to make my own image. My image is the default and has an automated build upon pushing to this repo. The images' differences in samtools appear to make my image run faster, but the legacy image can better handle the above cram/ref mismatch situation. So if you are running on dozens of crams that may have been built with different reference genomes, consider setting `covstats.useLegacyContainer` to `true`.

### A note on debugging and silent errors
Due to the odd way error codes are handled in go and WDL, it is unfortunately possible for an error to occur in the covstats task but for the task itself to be incorrectly reported as a success. I have tried to account for the most common errors by limiting the chances of them occuring, reducing space for user errors, and adding manually checks but of course something may have slipped by me. Thankfully, a "silent" error happening in the covstats task will have a very recognizable signature, and will look like one of these two sitautions:
* The workflow overall we be reported as a success, but the final report will have values of zero for everything related to some or all of your cram files, not just coverage. This occurs during the cram/ref mismatch situation on the non-legacy container.
* The covstats task will be considered a success, but the workflow will fail on the report task. The actual error occurred in the covstats task, resulting in bogus output that the report task cannot parse.
