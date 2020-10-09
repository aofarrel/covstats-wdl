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
		echo ${BASHFILENAME} > thisFilename

		# clean up
		rm this.txt
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

task average {
	input {
		Array[Int] readLengths
		Array[Float] coverages
		Int lenReads = length(readLengths)
		Int lenCov = length(coverages)
		Int j = 0
	}

	command <<<
	python << CODE

	# it seems impossible to sum over a WDL array in this scope so
	# we essentially duplicate the contents of the WDL array variable
	# into a variable created in the pythonic scope
	pyReadLengths = ~{sep="," readLengths} # array of ints
	pyCoverages = ~{sep="," coverages} # array of floats

	# print average read length
	avgRL = sum(pyReadLengths) / ~{lenReads}
	print("Average read length: {}".format(avgRL))
	avgCv = sum(pyCoverages) / ~{lenCov}
	print("Average coverage: {}".format(avgCv))
	CODE
	>>>

	output {
		Array[String] averages = read_lines(stdout())
	}
}

task report {
	input {
		Array[Int] readLengths
		Array[Float] coverages
		Array[File] filenames
		Array[String] averages

		# out of command section because WDL doesn't know what a comment is sometimes

		# attempt 1, exactly as it is in the spec, syntax error during runtime
		# Array[String] env = ["key1=value1", "key2=value2", "key3=value3"]
		# Array[String] env_quoted = squote(env)

		# attempts 2-6
		# filenamesQuotedA=squote(filenames) # Unexpected token at runtime
		# filenamesQuotedB=$(squote(filenames)) # NameError: name 'filenamesQuotedB' is not defined
		# filenamesQuotedC=~{squote(filenames)} # unknown engine function squote at compile
		# filenamesQuotedD=squote(~{filenames}) # array given but no sep provided at runtime
		# filenamesQuotedE=$(squote(~{filenames})) # array given but no sep provided at runtime
		# filenamesQuotedF=~{squote(~{filenames})} # syntax error at compile
	}

	command <<<
    set -euxo pipefail
    filenames_=${sep=' ' filenames}
    readLengths=${sep=' ' readLengths}

    # add new columns corresponding to cell id
    for i in ${!filenames_[*]}
    do
        filenames_basename=$(basename ${filenames_[$i]})
        sed -i "s/$/\t${readLengths[$i]}\t${filenames_basename}/" ${filenames_[$i]}
    done

    cat ${sep=' ' filenames} > interval_read_counts.bed
	>>>
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
			coverages = scatteredGetStats.outCoverage
	}

	call report {
		input:
			readLengths = scatteredGetStats.outReadLength,
			coverages = scatteredGetStats.outCoverage,
			filenames = inputBamsOrCrams,
			averages = average.averages
	}


	meta {
        author: "Ash O'Farrell"
        email: "aofarrel@ucsc.edu"
    }
}