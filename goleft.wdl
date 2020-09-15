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
		String? baseFile
	}

	command <<<
		samtools index ~{inputBam}
		# syntax error:
		#baseFile=~(basename "${inputBam}")
		#baseFile=~(basename "~{inputBam}")
		#
		# sets baseFile to an empty string:
		#baseFile=basename "${inputBam}"
		#baseFile=basename "~{inputBam}"
		#
		# Permission denied error:
		#baseFile=basename ~{inputBam}
		echo ~{inputBam} # prints full path, as expected
		echo ~{baseFile} # empty strings if you're LUCKY
	>>>

	output {
		# Unfortunately,
		#File bamIndex = "~{inputBam}.bai"
		# doesn't work due to a file not found error.
		# I think the issue is that samtools index
		# when operating in cromwell creates the 
		# file in its working directory instead of
		# the inputs directory. Normally samtools
		# would put it in the directory the bam is
		# located though.
		File bamIndex = "~{baseFile}.bam.bai"
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