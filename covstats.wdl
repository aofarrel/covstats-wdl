version 1.0

# Currently assumes only one bam is the input

task index {
	input {
		File inputBamOrCram
		String outputIndexString
	}

	command {
		samtools index ${inputBamOrCram} ${outputIndexString}
	}

	output {
		File outputIndex = outputIndexString
	}

	runtime {
        docker: "quay.io/biocontainers/goleft:0.2.0--0"
    }
}

task getReadLengthAndCoverage {
	input {
		File inputBamOrCram
		File inputIndex
		File? refGenome
		Float? thisCoverage # might be removable
		Int? thisReadLength # might be removable
	}

	command <<<

		#if defined(refGenome)

		# For some reason, a panic in go doesn't exit with status 1, so we
		# have to catch file not found exceptions ourselves
		if [ -f ~{inputBamOrCram} ]; then
			echo "Input bam file exists"
		else 
			echo "Input bam file (~{inputBamOrCram}) not found, panic"
			exit 1
		fi
		
		# Bai file is NEVER in the same directory as inputBamOrCram, trust me on this
		if [ -f ~{inputIndex} ]; then
			echo "Input bai file exists"
		else 
			echo "Input bai file (~{inputBamOrCram}.bai) not found, panic"
			exit 1
		fi

		# goleft tries to look for the bai in the same folder as the bam, but 
		# they're never in the same folder when run via Cromwell, so we have
		# to symlink it. goleft automatically checks for both name.bam.bai and
		# name.bai so it's okay if we use either 
		inputBamDir=$(dirname ~{inputBamOrCram})
		ln -s ~{inputIndex} ~{inputBamOrCram}.bai
		
		goleft covstats ~{inputBamOrCram} >> this.txt
		COVOUT=$(tail -n +2 this.txt)
		read -a COVARRAY <<< "$COVOUT"
		echo ${COVARRAY[1]} > thisCoverage
		echo ${COVARRAY[11]} > thisReadLength
		BASHFILENAME=$(basename ~{inputBamOrCram})
		echo "'${BASHFILENAME}'" > thisFilename

	>>>
	output {
		Int outReadLength = read_int("thisReadLength")
		Float outCoverage = read_float("thisCoverage")
		String outFilenames = read_string("thisFilename")
	}
	runtime {
        docker: "quay.io/biocontainers/goleft:0.2.0--0"
    }
}

task report {
	input {
		Array[Int] readLengths
		Array[Float] coverages
		Array[String] filenames
		Int lenReads = length(readLengths)
		Int lenCov = length(coverages)
	}

	command <<<
	python << CODE

	f = open("reports.txt", "a")

	pyReadLengths = ~{sep="," readLengths} # array of ints
	pyCoverages = ~{sep="," coverages} # array of floats
	pyFilenames = ~{sep="," filenames}
	i = 0

	# print "table" with each inputs' read length and coverage
	f.write("Filename\tRead length\tCoverage\n")
	while i < len(pyReadLengths):
		f.write("{}\t{}\t{}\n".format(pyFilenames[i], pyReadLengths[i], pyCoverages[i]))
		i += 1

	# print average read length
	avgRL = sum(pyReadLengths) / ~{lenReads}
	f.write("Average read length: {}\n".format(avgRL))
	avgCv = sum(pyCoverages) / ~{lenCov}
	f.write("Average coverage: {}\n".format(avgCv))

	f.close()

	CODE
	>>>

	output {
		File finalOut = "reports.txt"
	}
}

workflow covstats {
	input {
		Array[File] inputBamsOrCrams
		Array[File]? inputIndexes
		File? refGenome # required if using crams... if crams can work at all
	}

	scatter(oneBamOrCram in inputBamsOrCrams) {
		Array[File] batchInputAms = [oneBamOrCram]
		
		String outputBaiString = "${basename(oneBamOrCram)}.bai"
		call index { 
			input:
				inputBamOrCram = oneBamOrCram,
				outputIndexString = outputBaiString
		}

		call getReadLengthAndCoverage as scatteredGetStats { 
			input:
				inputBamOrCram = oneBamOrCram,
				inputIndex = index.outputIndex,
				refGenome = refGenome
		}
	}

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