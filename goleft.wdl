version 1.0

# Currently assumes only one bam is the input

task index {
	input {
		File bamFile
		String? outputBamPath
	}

	String outputPath = select_first([outputBamPath, basename(bamFile)])
	String bamIndexPath = outputPath + ".bai"


	command <<<
		bash -c '
		set -e
		# Make sure outputBamPath does not exist.
		if [ ! -f ~{outputPath} ]
		then
			mkdir -p "$(dirname ~{outputPath})"
			ln ~{bamFile} ~{outputPath}
		fi
		echo outputPath
		echo ~{outputPath}
		echo bamIndexPath
		echo ~{bamIndexPath}
		samtools index ~{outputPath} ~{bamFile}'
	>>>

	output {
		File indexedBam = outputPath
		File index = bamIndexPath
	}

	runtime {
        docker: "quay.io/biocontainers/goleft:0.2.0--0"
    }
}

task getReadLength {
	input {
		File bamFile
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
		File bamFile
		String outputBamPath
	}

	call index { input: bamFile = bamFile, outputBamPath = outputBamPath }
	call getReadLength { input: bamFile = bamFile, indexPath = index.indexedBam }

	meta {
        author: "Ash O'Farrell"
        email: "aofarrel@ucsc.edu"
    }
}