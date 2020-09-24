version 1.0

# Currently assumes only one bam is the input

task index {
	input {
		File inputBam
		String outputBaiString = "${basename(inputBam)}.bai"
	}

	command <<<
		samtools index ~{inputBam} ~{outputBaiString}
	>>>

	output {
		File outputBai = outputBaiString
	}

	runtime {
        docker: "quay.io/biocontainers/goleft:0.2.0--0"
    }
}

task getReadLength {
	input {
		File inputBam
		File indexPath
	}

	command <<<

		# For some reason, a panic in go doesn't exit with status 1, so we
		# have to catch file not found exceptions ourselves
		if [ -f ~{inputBam} ]; then
			echo "Input bam file exists"
		else 
			echo "Input bam file (~{inputBam}) not found, panic"
			exit 1
		fi
		
		# Bai file is NEVER in the same directory as inputBam, trust me on this
		if [ -f ~{indexPath} ]; then
			echo "Input bai file exists"
		else 
			echo "Input bai file (~{inputBam}.bai) not found, panic"
			exit 1
		fi
		
		goleft covstats ~{inputBam} >> this.txt
		cat this.txt # this line is just for debugging
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

workflow goleftwdl {
	input {
		File inputBam
	}

	call index { input: inputBam = inputBam }
	call getReadLength { input: inputBam = inputBam, indexPath = index.outputBai }

	meta {
        author: "Ash O'Farrell"
        email: "aofarrel@ucsc.edu"
    }
}