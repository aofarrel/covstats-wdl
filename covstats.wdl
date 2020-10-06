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
		#ln -s ~{inputIndex} ~{inputBamOrCram}.crai
		ln -s ~{inputIndex} ~{inputBamOrCram}.bai
		
		goleft covstats ~{inputBamOrCram} >> this.txt
		COVOUT = $(head -2 this.txt | tail -1 this.txt)
		read -a COVARRAY <<< "$COVOUT"
		echo ${COVARRAY[11]} >> readLength

		# clean up
		#rm this.txt
	>>>
	output {
		File readLength = "readLength"
		File this = "this.txt" # debugging purposes, will be removed later
	}
	runtime {
        docker: "quay.io/biocontainers/goleft:0.2.0--0"
    }
}

task gather {
	input {
		Array[File] readLengthFiles
	}

	command <<<

		# based on lines 670-680 of topmed variant caller
		readLengthFiles_string = ~{readLengthFiles
		echo ~{readLengthFiles_string}


		# this line throws a syntax error??????
		#readLengthFiles_list = readLengthFiles_string.split()

		#print("variantCalling: Input CRAM files names list is {}".format(readLengthFiles_list))
		#for bam in readLengthFiles_list:
			# Get the Cromwell basename  of the BAM file
			# The worklow will be able to access them
			# since the Cromwell path is mounted in the
			# docker run commmand that Cromwell sets up
			#base_name = os.path.basename(bam)
	>>>
}

workflow covstats {
	input {
		Array[File] inputBamsOrCrams
		Array[File]? inputIndexes
		File? refGenome # required if using crams... if crams can work at all

		# debug attempt to implement crams, ignore
		# because crams probably will never work
		# without a source code edit
		Boolean truedude = true
	}

	#if (truedude) {echo "true"}

	scatter(oneBamOrCram in inputBamsOrCrams) {
		Array[File] batchInputAms = [oneBamOrCram]
		
		#String outputCraiString = "${basename(oneBamOrCram)}.crai"
		String outputBaiString = "${basename(oneBamOrCram)}.bai"
		call index { 
			input:
				inputBamOrCram = oneBamOrCram,
				outputIndexString = outputBaiString
				#outputIndexString = outputCraiString
		}

		call getReadLength as scatteredGetReadLength { 
			input:
				inputBamOrCram = oneBamOrCram,
				inputIndex = index.outputIndex,
				refGenome = refGenome
		}
	}

	Array[File] readLengthFiles = scatteredGetReadLength.readLength

	call gather {
		input: readLengthFiles = readLengthFiles
	}
	
	# assert refGenome is defined if using crams
	#if [[ $inputBamsOrCrams =~ \.cram$ ]];

	# skip calling index if the indeces are provided
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