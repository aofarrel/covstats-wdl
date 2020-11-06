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

  MD5REPORT=$(md5sum ~{report})
  MD5TRUTH=$(md5sum ~{truth})

  if [[${MD5REPORT}==${MD5TRUTH}]]
  then
    echo "Checksums match"
    echo $MD5REPORT
    echo $MD5TRUTH
  else
    echo "Checksums do not match, see stderr for details"
    >&2 echo "ERROR, CHECKSUMS DO NOT MATCH"
    >&2 echo "Output checksum: ${MD5REPORT}"
    >&2 echo "Truth checksum: ${MD5TRUTH}"
    >&2 echo "Contents of the output file:"
    >&2 cat ~{report}
    >&2 echo "Contents of the truth file:"
    >&2 cat ~{truth} 
    >&2 echo "Now exiting with code 1..."
    exit 1
  fi

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

  # weird workaround to see if inputIndexes are defined, used in old
  # versions but now more of an error fallback
  Array[String] wholeLottaNada = []

  if (useLegacyContainer == "true") {
    call covstats.debugEchoes1 {input: toEcho = "Using legacy Docker container"}
  }

  if (useLegacyContainer == "false") {
    call covstats.debugEchoes2 {input: toEcho = "Using updated Docker container"}
  }

  scatter(oneBamOrCram in inputBamsOrCrams) {
    Array[String] allOrNoIndexes = select_first([inputIndexes, wholeLottaNada])

    #scattered
    call covstats.getReadLengthAndCoverage as scatteredGetStats { 
      input:
        inputBamOrCram = oneBamOrCram,
        refGenome = refGenome,
        allInputIndexes = allOrNoIndexes,
        toUse = useLegacyContainer
    }
  }

  # not scattered
  call covstats.report {
    input:
      readLengths = scatteredGetStats.outReadLength,
      coverages = scatteredGetStats.outCoverage,
      filenames = scatteredGetStats.outFilenames
  }

  meta {
    author: "Ash O'Farrell"
    email: "aofarrel@ucsc.edu"
  }

 call md5sum {
    input:
        report = report.finalOut,
        truth = truth,
        refGenome = refGenome
    }
}