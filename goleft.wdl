version 1.0

# Currently assumes only one bam is the input


# First of all, we must generate a bai file.
# Yes, for this particular task I could in
# theory get around this by just forcing the
# user to provide their own bai file, but
# sort of thing is a common use case for WDL
# so it shouldn't be difficult, and I'll need
# to learn how to do it sooner or later.
task index {
	input {
		File inputBam
		String? outputBamPath
	}

	String outputPath = select_first([outputBamPath, basename(inputBam)])
	String bamIndexPath = sub(outputPath, "\.bam$", ".bai")


	command <<<
		samtools index ~{inputBam}
	>>>

	output {
		File bamIndex = outputPath
		File indexPath = bamIndexPath
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

	# Tried putting baseIndex or index.baseIndex in here as
	# an input but to no avail
	call index { input: inputBam = inputBam, fileName = fileName }
	call getReadLength { input: inputBam = inputBam, bamIndex = index.bamIndex }

	meta {
        author: "Ash O'Farrell"
        email: "aofarrel@ucsc.edu"
    }
}