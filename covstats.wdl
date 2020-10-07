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
		echo ${COVARRAY[1]} >> coverage.txt
		echo ${COVARRAY[11]} >> readLength.txt

		# NEED TO ADD A NEWLINE IN READLENGTH.TXT!!!!
		# except in python version?? ugh!

		# clean up
		rm this.txt
	>>>
	output {
		File readLength = "readLength.txt"
		File coverage = "coverage.txt"
		#File this = "this.txt" # debugging purposes, will be removed later
	}
	runtime {
        docker: "quay.io/biocontainers/goleft:0.2.0--0"
    }
}

task pythonGather {
	# is this cheating? a little bit.
	input {
		Array[File] readLengthFiles
		Array[File] coverageFiles
		File pythonParser
	}
	command <<<
		echo ~{sep=' ' readLengthFiles} >> bug.txt
		echo ~{sep=' ' coverageFiles} >> bug.txt
		python "/Users/ash/Repos/goleft-wdl/debug/pythonParse.py" readLengthFiles
	>>>

}

task gather {
	input {
		Array[File] readLengthFiles
		Array[File] coverageFiles # currently unused
		Array[String]? allReadLengths
	}

	command <<<
		for file in ~{sep=' ' readLengthFiles}
		do
			while read line
			do
				echo "${line}" >> allReadLengths.txt
				~{allReadLengths} += "${line}"
			done < ${file}
		done

		for value in "${allReadLengths[@]}"
		do
			echo ${value} >> out.txt
		done

	>>>

	output {
		File out = "out.txt"
	}
	runtime {
        docker: "quay.io/biocontainers/goleft:0.2.0--0"
    }
}

workflow covstats {
	input {
		Array[File] inputBamsOrCrams
		Array[File]? inputIndexes
		File? refGenome # required if using crams... if crams can work at all
		File pythonParser = "/Users/ash/Repos/goleft-wdl/debug/pythonParse.py"
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

	Array[File] readLengthFiles = scatteredGetStats.readLength
	Array[File] coverageFiles = scatteredGetStats.coverage

	call gather {
		input:
			readLengthFiles = readLengthFiles,
			coverageFiles = coverageFiles
	}

	#call pythonGather {
		#input:
			#readLengthFiles = scatteredGetStats.readLength,
			#coverageFiles = scatteredGetStats.coverage,
			#pythonParser = pythonParser
	#}

	meta {
        author: "Ash O'Farrell"
        email: "aofarrel@ucsc.edu"
    }
}