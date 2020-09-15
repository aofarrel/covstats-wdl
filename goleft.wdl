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
		# Without this, the workflow won't even
		# start as it "cannot lookup value
		# 'baseValue', it is never delcared"
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
		# The following will throw this in stderr...
		# /cromwell-executions/goleftwdl/b57ea50f-d81e-4ad9-a66f-990e47f56d7c/
		# call-index/execution/script: line 32: /cromwell-executions/goleftwdl/
		# b57ea50f-d81e-4ad9-a66f-990e47f56d7c/call-index/inputs/426711761/
		# NA12878.chrom20.ILLUMINA.bwa.CEU.low_coverage.20121211.bam: Permission denied
		# ...but on commandline will just error like...
		#[2020-09-15 13:25:40,94] [error] WorkflowManagerActor Workflow 
		#b57ea50f-d81e-4ad9-a66f-990e47f56d7c failed (during ExecutingWorkflowState): 
		#java.io.FileNotFoundException: Could not process output, file not found: 
		#/private/var/folders/vp/327wktbj3wqb65q3v3n8qpxc0000gn/T/1600201521879-0/
		#cromwell-executions/goleftwdl/b57ea50f-d81e-4ad9-a66f-990e47f56d7c/call-index/
		#execution/.bam.bai
		baseFile=basename ~{inputBam}
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

	# Tried putting baseIndex or index.baseIndex in here as
	# an input but to no avail
	call index { input: inputBam = inputBam }
	call getReadLength { input: inputBam = inputBam, bamIndex = index.bamIndex }

	meta {
        author: "Ash O'Farrell"
        email: "aofarrel@ucsc.edu"
    }
}