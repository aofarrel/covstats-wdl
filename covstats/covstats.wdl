version 1.0

task getReadLengthAndCoverage {
	input {
		File inputBamOrCram
		Array[File] allInputIndexes
		File? refGenome
		String toUse
		# runtime attributes with defaults
		Int memSize = 2
		Int preemptible = 0
		Int additionalDisk = 0
	}

	command <<<

		if [ toUse == "true" ]; then
			echo "Using legacy Docker container"
		else
			echo "Using updated Docker container"
		fi

		start=$SECONDS

		set -eux -o pipefail

		if [ -f ~{inputBamOrCram} ]; then
				echo "Input bam or cram file exists"
		else
				>&2 echo "Input bam or cram file ~{inputBamOrCram} not found, panic"
				exit 1
		fi

		AMIACRAM=$(echo ~{inputBamOrCram} | sed 's/\.[^.]*$//')

		if [ -f ${AMIACRAM}.cram ]; then
			echo "Cram file detected"
			if [ "~{refGenome}" != '' ]; then
				goleft covstats -f ~{refGenome} ~{inputBamOrCram} >> this.txt
				# Sometimes this.txt seems to be missing the header... investigate
				COVOUT=$(tail -n +2 this.txt)
				read -a COVARRAY <<< "$COVOUT"
				echo ${COVARRAY[0]} > thisCoverage
				echo ${COVARRAY[11]} > thisReadLength
				BASHFILENAME=$(basename ~{inputBamOrCram})
				echo "'${BASHFILENAME}'" > thisFilename
			else
				# Cram file but no reference genome
				>&2 echo "Cram detected but cannot find reference genome."
				>&2 echo "A reference genome is required for cram inputs."
				exit 1
			fi

		else
			# Bam file

			OTHERPOSSIBILITY=$(echo ~{inputBamOrCram} | sed 's/\.[^.]*$//')

			if [ -f ~{inputBamOrCram}.bai ]; then
				# foo.bam.bai
				echo "Bai file already exists with pattern *.bam.bai"
			elif [ -f ${OTHERPOSSIBILITY}.bai ]; then
				# foo.bai
				echo "Bai file already exists with pattern *.bai"
			else
				echo "Input bai file not found. We searched for:"
				echo "  ~{inputBamOrCram}.bai"
				echo "  ${OTHERPOSSIBILITY}.bai"
				echo "Finding neither, we will index with samtools."
				samtools index ~{inputBamOrCram} ~{inputBamOrCram}.bai
			fi

			goleft covstats -f ~{refGenome} ~{inputBamOrCram} >> this.txt

			COVOUT=$(tail -n +2 this.txt)
			read -a COVARRAY <<< "$COVOUT"
			echo ${COVARRAY[0]} > thisCoverage
			echo ${COVARRAY[11]} > thisReadLength
			BASHFILENAME=$(basename ~{inputBamOrCram})
			echo "'${BASHFILENAME}'" > thisFilename
		fi

		duration=$(( SECONDS - start ))
		echo ${duration} > duration

	>>>

	# Estimate disk size required
	Int refSize = ceil(size(refGenome, "GB"))
	Int indexSize = ceil(size(allInputIndexes, "GB"))
	#lets see if we can do this on a task level to save space
	#Int amSize = ceil(size(inputBamsOrCrams, "GB"))
	Int thisAmSize = ceil(size(inputBamOrCram, "GB"))

	# If input is a cram, it will get samtools'ed into a bam,
	# so we need to at least double its size for the disk
	# calculation. Eventually we might be be able to go back
	# to the old mess of the cram-support branch (PR3) at least
	# in terms of determining if something is a cram ahead of time
	# in order to maximize savings.

	Int finalDiskSize = refSize + indexSize + (2*thisAmSize) + additionalDisk

	output {
		Int outReadLength = read_int("thisReadLength")
		Float outCoverage = read_float("thisCoverage")
		String outFilenames = read_string("thisFilename")
		Int duration = read_int("duration")
	}
	runtime {
		docker: if toUse == "true" then "quay.io/biocontainers/goleft:0.2.0--0" else "quay.io/aofarrel/goleft-covstats:circleci-push"
		preemptible: preemptible
		disks: "local-disk " + finalDiskSize + " HDD"
		memory: memSize + "G"
	}
}

task report {
	input {
		Array[Int] readLengths
		Array[Float] coverages
		Array[String] filenames
		Int lenReads = length(readLengths)
		Int lenCov = length(coverages)
		# user runtime attributes
		Int memSize = 2
		Int preemptible = 2
	}

	command <<<
	python << CODE

	f = open("reports.txt", "a")

	pyReadLengths = ~{sep="," readLengths} # array of ints OR int
	pyCoverages = ~{sep="," coverages} # array of floats OR float
	pyFilenames = ~{sep="," filenames} # array of strings OR string
	i = 0

	# if there was just one input, the above will not be arrays
	if (type(pyReadLengths) == int):
		f.write("Filename\tRead length\tCoverage\n")
		f.write("{}\t{}\t{}\n".format(pyFilenames, pyReadLengths, pyCoverages))
		f.close()
	else:
		# print "table" with each inputs' read length and coverage
		f.write("Filename\tRead length\tCoverage\n")
		while i < len(pyReadLengths):
			f.write("{}\t{}\t{}\n".format(pyFilenames[i], pyReadLengths[i], pyCoverages[i]))
			i += 1
		# print average read length
		avgRL = sum(pyReadLengths) / ~{lenReads}
		f.write("Average read length: {}\n".format(avgRL))
		avgCv = sum(pyCoverages) / ~{lenCov}
		f.write("Average coverage: {}\n".format(avgCv))
		f.close()

	CODE
	>>>

	output {
		File finalOut = "reports.txt"
	}

	runtime {
		docker: "python:3.8-slim"
		preemptible: preemptible
		memory: memSize + "G"
	}
}

workflow covstats {
	input {
		Array[File] inputBamsOrCrams
		Array[File]? inputIndexes
		File? refGenome
		String? useLegacyContainer
		# runtime attributes for covstats
		Int covstatsMem = 2
		Int additionalDisk = 0
		Int covstatsPreemptible = 0
		# runtme attributes for report
		Int reportMem = 2
		Int reportPreemptible = 2
	}

	# Fallback if no indecies are defined. Other methods exist but this is
	# one of the cleaner ways to go about it.
	Array[String] wholeLottaNada = []

	# Figure out which Docker to use
	# The choose container is printed in the task itself
	String toUse = select_first([useLegacyContainer, "false"])

	# Catching input typos from user doesn't seem possible due to how variables
	# are scoped unfortunately, but I did make an attempt which I stored here
	# https://gist.github.com/aofarrel/ef71e1a27d824cbcc8acb11b6abe6e19
	# in case some brave soul wants to take a crack at it

	# Call covstats
	scatter(oneBamOrCram in inputBamsOrCrams) {
		Array[String] allOrNoIndexes = select_first([inputIndexes, wholeLottaNada])

		call getReadLengthAndCoverage as scatteredGetStats {
			input:
				inputBamOrCram = oneBamOrCram,
				refGenome = refGenome,
				allInputIndexes = allOrNoIndexes,
				toUse = toUse,
				memSize = covstatsMem,
				additionalDisk = additionalDisk,
				preemptible = covstatsPreemptible
		}
	}

	# not scattered
	call report {
		input:
			readLengths = scatteredGetStats.outReadLength,
			coverages = scatteredGetStats.outCoverage,
			filenames = scatteredGetStats.outFilenames,
			memSize = reportMem,
			preemptible = reportPreemptible
	}

	meta {
		author: "Ash O'Farrell"
		email: "aofarrel@ucsc.edu"
    }
}
