# goleft-wdl
 🎶 As he goleft, and you stay right 🎶

A WDLized version of some [goleft](https://github.com/brentp/goleft) functions. As of now this is more of a proof-of-concept rather than a workflow with a clear use case.

*goleft.wdl* is a proof-of-concept. It runs samtools index, covstats, and indexcov on a single bam file input, then reports the read length and coverage.

*covstats.wdl* is focused on covstats. It runs covstats on an array of bam files. The user can also specify bai files to skip the `samtools index`ing step and allow for faster completion. The result is a text file that prints the filename, read length, and coverage of every input file, then the average coverage and read length for the entire array of inputs.

Currently it does not support sam or cram files.