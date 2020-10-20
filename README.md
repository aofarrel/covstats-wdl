# goleft-wdl
 🎶 As he goleft, and you stay right 🎶

A WDLized version of some [goleft](https://github.com/brentp/goleft) functions.

*goleft.wdl* is a proof-of-concept. It runs samtools index, covstats, and indexcov on a single bam file input, then reports the read length and coverage along with all of indexcov's usual outputs.

*covstats.wdl* is focused on covstats. It runs covstats on an array of bam or cram files. The user can also specify bai files to skip the `samtools index`ing step and allow for faster completion. The result is a text file that prints the filename, read length, and coverage of every input file, then the average coverage and read length for the entire array of inputs. Although cram files are supported, they are **signifantly** slower to process than bam files, so if you have both, use the bams. Cram files also require the specification of a reference genome.