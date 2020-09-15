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

	command <<<
		OUT=$(goleft covstats ~{inputBam} | awk 'FNR == 2 {print $(NF-3)}')
		echo $(OUT)
	>>>

	output {
		File readLength
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