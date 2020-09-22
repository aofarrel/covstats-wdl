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
	call getReadLength { input: inputBam = inputBam, indexPath = index.outputBaiString }

	meta {
        author: "Ash O'Farrell"
        email: "aofarrel@ucsc.edu"
    }
}