version 1.0

# Currently assumes only one bam is the input

task index {
	input {
		Array[File] inputBamsOrCrams
		String? outputBaiString
	}

	command {
		samtools index ${sep="," inputBamsOrCrams} ${outputBaiString}
	}

	output {
		Array[File] outputBai = outputBaiString
	}

	runtime {
        docker: "quay.io/biocontainers/goleft:0.2.0--0"
    }
}

task getReadLength {
	input {
		Array[File] inputBamsOrCrams
		Array[File] inputIndexes
	}

	command <<<

		# For some reason, a panic in go doesn't exit with status 1, so we
		# have to catch file not found exceptions ourselves
		#if [ -f ~{inputBamsOrCrams} ]; then
			#echo "Input bam file exists"
		#else 
			#echo "Input bam file (~{inputBamsOrCrams}) not found, panic"
			#exit 1
		#fi
		
		# Bai file is NEVER in the same directory as inputBamsOrCrams, trust me on this
		#if [ -f ~{inputIndexes} ]; then
			#echo "Input bai file exists"
		#else 
			#echo "Input bai file (~{inputBamsOrCrams}.bai) not found, panic"
			#exit 1
		#fi

		# goleft tries to look for the bai in the same folder as the bam, but 
		# they're never in the same folder when run via Cromwell, so we have
		# to symlink it. goleft automatically checks for both name.bam.bai and
		# name.bai so it's okay if we use either 
		inputBamDir=$(dirname ~{inputBamsOrCrams})
		ln -s ~{inputIndexes} ~{inputBamsOrCrams}.bai
		
		goleft covstats ~{inputBamsOrCrams} >> this.txt
		COVOUT=$(head -2 this.txt | tail -1 this.txt)
		read -a COVARRAY <<< "$COVOUT"
		echo ${COVARRAY[11]} >> readLength

		# clean up
		rm this.txt
	>>>
	output {
		File readLength = "readLength"
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
	scatter(oneBamOrCram in inputBamsOrCrams) {
		Array[File] batchInputAms = [oneBamOrCram]
		call index { 
			input: inputBamsOrCrams = inputBamsOrCrams 
		}

	}
	

	
	call getReadLength { input: inputBamsOrCrams = inputBamsOrCrams, inputIndexes = index.outputBai }

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