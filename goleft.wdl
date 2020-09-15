version 1.0

# Currently assumes only one bam is the input

task index {
	input {
		File bamFile
		String? bamDir
	}

	String bamName = basename(bamFile)
	
	command <<<
		pwd
		echo bamName
		echo ~{bamName}
		echo bamDir
		echo ~{bamDir}
		echo bamDir2
		echo dirname ~{bamFile}
		echo bamDir3
		echo "${bamFile%/*}"
		# how many more iterations of https://stackoverflow.com/questions/23103042/unix-command-to-get-file-path-without-basename will this take
		samtools index ~{bamFile}
	>>>

	output {
		File index = bamDir + bamName + ".bai"
	}

	runtime {
        docker: "quay.io/biocontainers/goleft:0.2.0--0"
    }
}

task getReadLength {
	input {
		File bamFile
		File index
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
		String bamDir
	}

	call index { input: bamFile = bamFile, bamDir = bamDir }
	call getReadLength { input: bamFile = bamFile, index = index.index }

	meta {
        author: "Ash O'Farrell"
        email: "aofarrel@ucsc.edu"
    }
}