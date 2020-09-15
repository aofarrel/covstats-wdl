version 1.0

# Currently assumes only one bam is the input

task index {
	input {
		File inputBam
	}

	command {
		samtools index ~{inputBam}
	}

	output {
		File bamIndex = "${inputBam}.bai"
	}

	runtime {
        docker: "quay.io/biocontainers/goleft:0.2.0--0"
    }
}

task getReadLength {
	input {
		File inputBam
		File bamIndex
	}

	command <<<
		goleft covstats "in.bam" >> this.txt
		COVOUT=$(head -2 this.txt | tail -1 this.txt)
		read -a COVARRAY <<< "$COVOUT"
		echo ${COVARRAY[11]} >> readLength
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
	call getReadLength { input: inputBam = inputBam, bamIndex = index.bamIndex }

	meta {
        author: "Ash O'Farrell"
        email: "aofarrel@ucsc.edu"
    }
}