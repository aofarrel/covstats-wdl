version 1.0

# Currently assumes only one bam is the input

task index {
	input {
		File inputBam
		String outputBaiString = "${inputBam}.bai"
	}

	command <<<
		echo ~{outputBaiString}
		samtools index ~{inputBam} ~{outputBaiString}
	>>>

	output {
		File outputBai = outputBaiString
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

	meta {
        author: "Ash O'Farrell"
        email: "aofarrel@ucsc.edu"
    }
}