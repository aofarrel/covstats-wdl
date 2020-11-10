version 1.0

# NOTE: If you wish to adapt this checker and make your own truth files, go ahead, but
# I recommend that you always check both of the following:
# 1) A cram file 
# 2) A bam file, without also inputting its index
# Both of these cases require calling samtools and as we all know different versions of
# samtools can work a little differently. Keep that in mind especially if you wish to
# roll your own Docker image here.

import "https://raw.githubusercontent.com/aofarrel/covstats-wdl/master/covstats/covstats.wdl" as covstats

task md5sum {
  input {
    File report
    File truth
    File refGenome
  }

  command <<<

  # Terra can mix up files 

  sort ~{report} > newreport.txt
  sort ~{truth} > newtruth.txt

  md5sum newreport.txt > sum.txt
  md5sum newtruth.txt > debugtruth.txt

  # temporarily outputting to stderr for clarity's sake
  >&2 echo "Output checksum:"
  >&2 cat sum.txt
  >&2 echo "-=-=-=-=-=-=-=-=-=-"
  >&2 echo "Truth checksum:"
  >&2 cat debugtruth.txt
  >&2 echo "-=-=-=-=-=-=-=-=-=-"
  >&2 echo "Contents of the output file:"
  >&2 cat ~{report}
  >&2 echo "-=-=-=-=-=-=-=-=-=-"
  >&2 echo "Contents of the truth file:"
  >&2 cat ~{truth}
  >&2 echo "-=-=-=-=-=-=-=-=-=-"
  >&2 cat newreport.txt
  >&2 echo "-=-=-=-=-=-=-=-=-=-"
  >&2 echo "Contents of the sorted truth file:"
  >&2 cat newtruth.txt
  >&2 echo "-=-=-=-=-=-=-=-=-=-"
  >&2 cmp --verbose sum.txt debugtruth.txt
  >&2 diff sum.txt debugtruth.txt
  >&2 diff -w sum.txt debugtruth.txt

  cat ~{truth} | md5sum --check sum.txt

  >>>

  runtime {
    docker: "python:3.8-slim"
    preemptible: 2
  }

}

workflow checker {
  input {
    File truth
    Array[File] inputBamsOrCrams
    Array[File]? inputIndexes # optional
    File refGenome # not optional, because you should want to test CRAMs
    String useLegacyContainer # also not optional by design
  }

  # Fallback if no indecies are defined. Other methods exist but this is
  # one of the cleaner ways to go about it.
  Array[String] wholeLottaNada = []

  # Figure out which Docker to use
  # The choose container is printed in the task itself
  String toUse = select_first([useLegacyContainer, "false"])

  # Catching input typos from user doesn't seem possible due to how variables 
  # are scoped unfortunately, but I did make an attempt which I stored here
  # https://gist.github.com/aofarrel/ef71e1a27d824cbcc8acb11b6abe6e19
  # in case some brave soul wants to take a crack at it

  # Call covstats
  scatter(oneBamOrCram in inputBamsOrCrams) {
    Array[String] allOrNoIndexes = select_first([inputIndexes, wholeLottaNada])
    
    call getReadLengthAndCoverage as scatteredGetStats { 
      input:
        inputBamOrCram = oneBamOrCram,
        refGenome = refGenome,
        allInputIndexes = allOrNoIndexes,
        toUse = toUse
    }
  }

  # not scattered
  call report {
    input:
      readLengths = scatteredGetStats.outReadLength,
      coverages = scatteredGetStats.outCoverage,
      filenames = scatteredGetStats.outFilenames
  }

  meta {
    author: "Ash O'Farrell"
    email: "aofarrel@ucsc.edu"
    }
}
