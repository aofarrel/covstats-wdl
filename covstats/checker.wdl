version 1.0

import "https://raw.githubusercontent.com/aofarrel/covstats-wdl/blob/master/covstats/covstats.wdl" as covstats

task md5sum {

}

workflow checkerWorkflow {
  File truth
  String docker_image
  Array[File] inputBamsOrCrams
  File refGenome # not optional, because you should want to test CRAMs

  # weird workaround to see if inputIndexes are defined
  Array[String] wholeLottaNada = []

  scatter(oneBamOrCram in inputBamsOrCrams) {
    Array[String] allOrNoIndexes = select_first([inputIndexes, wholeLottaNada])

    #scattered
    call covstats.getReadLengthAndCoverage as scatteredGetStats { 
      input:
        inputBamOrCram = oneBamOrCram,
        refGenome = refGenome,
        allInputIndexes = allOrNoIndexes
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
}

 call md5sum {
    input:
        inputCRAMFile = aligner.aligner_output_cram,
        inputTruthCRAMFile = inputTruthCRAMFile,
        referenceFile = ref_fasta,
        docker_image = docker_image }
}