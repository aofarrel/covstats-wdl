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
		Float? thisCoverage
		Int? thisReadLength
	}

	command <<<

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

		# clean up
		rm this.txt
	>>>
	output {
		Int outReadLength = read_int("thisReadLength")
		Float outCoverage = read_float("thisCoverage")
	}
	runtime {
        docker: "quay.io/biocontainers/goleft:0.2.0--0"
    }
}

task average {
	input {
		Array[Int] readLengths
		Array[Float] coverages
		Array[File] filenames
		Int lenReads = length(readLengths)
		Int lenCov = length(coverages)
		Int j = 1
	}

	command <<<
	python << CODE

	# it seems impossible to sum over a WDL array in this scope so
	# we essentially duplicate the contents of the WDL array variable
	# into a variable created in the pythonic scope
	pyReadLengths = [] 
	pyCoverages = []

	while ~{j} < ~{lenReads}+1:
		print(~{j}) #debug
		pyReadLengths.append(~{readLengths[j]})
		pyCoverages.append(~{coverages[j]})

		# print "table" with each inputs' read length and coverage
		#print("~{filenames[j]} -->", ~{readLengths[j]}, ~{coverages[j]})
		~{j} = ~{j}+1

	# print average read length
	avgRL = sum(pyReadLengths) / ~{lenReads}
	print("Average read length:", avgRL)
	avgCv = sum(pyCoverages) / ~{lenCov}
	print("Average read length:", avgCv)
	CODE
	>>>

	output {
		File out = read_lines(stdout())
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

	call average {
		input:
			readLengths = scatteredGetStats.outReadLength,
			coverages = scatteredGetStats.outCoverage,
			filenames = inputBamsOrCrams
	}


	meta {
        author: "Ash O'Farrell"
        email: "aofarrel@ucsc.edu"
    }
}