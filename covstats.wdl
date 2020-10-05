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

task getReadLength {
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
		ln -s ~{inputIndex} ~{inputBamOrCram}.crai
		
		goleft covstats ~{inputBamOrCram} >> this.txt
		COVOUT=$(head -2 this.txt | tail -1 this.txt)
		read -a COVARRAY <<< "$COVOUT"
		echo ${COVARRAY[11]} >> readLength

		# clean up
		#rm this.txt
	>>>
	output {
		File readLength = "readLength"
		File this = "debug"
	}
	runtime {
        docker: "quay.io/biocontainers/goleft:0.2.0--0"
    }
}

workflow covstats {
	input {
		Array[File] inputBamsOrCrams
		Array[File]? inputIndexes
		File? refGenome # required if using crams
	}

	if(True) {
		echo "true"
	}

	scatter(oneBamOrCram in inputBamsOrCrams) {
		Array[File] batchInputAms = [oneBamOrCram]
		if($inputBamsOrCrams =~ \.cram$) {
			echo "cram files"
			String outputCraiString = "${basename(oneBamOrCram)}.crai"
			call index { 
				input:
					inputBamOrCram = oneBamOrCram,
					outputIndexString = outputCraiString
			}
		}

		if($inputBamsOrCrams =~ \.bam$) {
			echo "bam files"
			String outputBaiString = "${basename(oneBamOrCram)}.bai"
			call index { 
				input:
					inputBamOrCram = oneBamOrCram,
					outputIndexString = outputBaiString
			}
		}

		call getReadLength { 
			input:
				inputBamOrCram = oneBamOrCram,
				inputIndex = index.outputIndex,
				refGenome = refGenome
		}
	}
	
	# assert refGenome is defined if using crams
	#if [[ $inputBamsOrCrams =~ \.cram$ ]];

	#if inputIndexes
	#then
		#call getReadLength { input: inputBamsOrCrams = inputBamsOrCrams, inputIndexes = inputIndexes }
	#else
		#call index { input: inputBamsOrCrams = inputBamsOrCrams }
		#call getReadLength { input: inputBamsOrCrams = inputBamsOrCrams, inputIndexes = index.outputBai }
	#fi
	
	

	meta {
        author: "Ash O'Farrell"
        email: "aofarrel@ucsc.edu"
    }
}