version 1.0

# Currently assumes only one bam is the input

task index {
	input {
		File inputBam
	}

	command {
		samtools index ~{inputBam}
	}

	# we shouldn't need to capture the output

	runtime {
        docker: "quay.io/biocontainers/goleft:0.2.0--0"
    }
}

task getReadLength {
	input {
		File inputBam
	}

	command {
		goleft covstats ~inputBam >> allOutput.txt
		
		# why is this considered declared...
		COVOUT=$(head -2 allOutput.txt | tail -1 allOutput.txt)

		#but this isn't?
		read -a COVARRAY << "$COVOUT"
		echo ${COVARRAY[11]} >> readLength.txt
		rm allOutput.txt
	}

	output {
		File readLength = readLength
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
	call getReadLength { input: inputBam = inputBam }

	meta {
        author: "Ash O'Farrell"
        email: "aofarrel@ucsc.edu"
    }
}