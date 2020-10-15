version 1.0

task index {
	input {
		File inputBamOrCram
		String outputIndexString
	}

	command {
		samtools index ${inputBamOrCram} ${outputIndexString}
	}

	output {
		File outputIndex = outputIndexString
	}

	runtime {
        docker: "quay.io/biocontainers/goleft:0.2.0--0"
    }
}

task getReadLengthAndCoverage {
	input {
		File inputBamOrCram
		File? inputIndex # if samtools index was called
		Array[File] allInputIndexes # if samtools index was not called
		File? refGenome
	}

	command <<<

		set -eux -o pipefail

		if [ -f ~{inputBamOrCram} ]; then
				echo "Input bam or cram file exists"
		else 
				>&2 echo "Input bam or cram file (~{inputBamOrCram}) not found, panic"
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
				echo ${COVARRAY[1]} > thisCoverage
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
			# Not a cram file
			
			# If the user passes in the indices, they will be in the same folder
			# as the input bams/crams. If samtools index was called to generate
			# the indices, then they will be in a different folder.

			OTHERPOSSIBILITY=$(echo ~{inputBamOrCram} | sed 's/\.[^.]*$//')

			if [ -f ~{inputBamOrCram}.bai ]; then
				# foo.bam.bai
				echo "Bai file, likely passed in by user, exists with pattern *.bam.bai"
			elif [ ~{inputIndex} != ~{inputBamOrCram} ]; then
				# foo.bam.bai
				echo "Bai file, likely output of samtools index, exists"
				# goleft tries to look for the bai in the same folder as the bam, but 
				# they're not in the same folder if the input came from samtools index,
				# so we have to symlink it. goleft automatically checks for both 
				# foo.bam.bai and foo.bai, so it's okay if we use either 
				inputBamDir=$(dirname ~{inputBamOrCram})
				ln -s ~{inputIndex} ~{inputBamOrCram}.bai
			elif [ -f ${OTHERPOSSIBILITY}.bai ]; then
				# foo.bai
				echo "Bai file, likely passed in by user, exists with pattern *.bai"
			else
				>&2 echo -n "Input bai file (~{inputBamOrCram}.bai)"
				>&2 echo " nor ${OTHERPOSSIBILITY}.bai not found, panic"
				exit 1
			fi
			
			goleft covstats -f ~{refGenome} ~{inputBamOrCram} >> this.txt

			COVOUT=$(tail -n +2 this.txt)
			read -a COVARRAY <<< "$COVOUT"
			echo ${COVARRAY[1]} > thisCoverage
			echo ${COVARRAY[11]} > thisReadLength
			BASHFILENAME=$(basename ~{inputBamOrCram})
			echo "'${BASHFILENAME}'" > thisFilename
		fi

	>>>
	output {
		Int outReadLength = read_int("thisReadLength")
		Float outCoverage = read_float("thisCoverage")
		String outFilenames = read_string("thisFilename")
	}
	runtime {
        docker: "quay.io/biocontainers/goleft:0.2.0--0"
    }
}

task report {
	input {
		Array[Int] readLengths
		Array[Float] coverages
		Array[String] filenames
		Int lenReads = length(readLengths)
		Int lenCov = length(coverages)
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
}

workflow covstats {
	input {
		Array[File] inputBamsOrCrams
		Array[File]? inputIndexes
		File? refGenome
	}

	# weird workaround to see if inputIndexes are defined, but only for bam files
	Array[String] wholeLottaNada = []

	scatter(oneBamOrCram in inputBamsOrCrams) {
		Array[File] batchInputAms = [oneBamOrCram]

		# prepare for the worst workaround you have ever seen.
		Array[String] allIndexes = select_first([inputIndexes, wholeLottaNada])
		String base = "${basename(oneBamOrCram)}"
		String cramReplaced = sub(base, "\\.cram", "pneumonoultramicroscopicsilicovolcanoconiosis")
		
		# scattered
		if (length(allIndexes) != length(inputBamsOrCrams)) {
			String outputBaiString = "${basename(oneBamOrCram)}.bai"
			if (base == cramReplaced) {
				# Only true if we are running on a bam
				call index {
					input:
						inputBamOrCram = oneBamOrCram,
						outputIndexString = outputBaiString
				}
			}
		}

		#scattered
		call getReadLengthAndCoverage as scatteredGetStats { 
			input:
				inputBamOrCram = oneBamOrCram,
				refGenome = refGenome,
				# Let me explain this foolishness...
				# samtools index takes time so we want to skip it whenever
				# possible. If the user does not supply indexes for every
				# input (technically it's if the user's bam/cram inputs is
				# a different number of files then the user's bai/crai inputs)
				# then a scattered samtools index will run. That scattered
				# samtools index will return a single index file, which
				# is index.outputIndex. But if the user does define indeces,
				# then the index will be some file in the input array. Iterating
				# arrays in WDl is a nightmare, as well as unnecessary in this
				# situation, because the index just needs to be in the working
				# directory when covstats is run. So whether we pass in an
				# array of files or just a single file, we're good. The problem
				# is we can't use another if (or the same if as above) to just
				# say "if user defined indeces then pass in the array else pass
				# in the output of samtools index" because Cromwell does not
				# recognize those two ifs (WDL lacks an else statement) as being
				# mutually exclusive, so it's mad that results are being duplicated.
				# So we try to pass in both a file AND an array, both of which are
				# optional inputs. Recall that allIndexes is already the result
				# of a select_first(), so it is either the users' passed in index
				# files, or an empty array. An empty array is still a valid array
				# in WDL so that's fine and dandy. But, if you pass an empty string
				# or a file that doesn't exist into a File or File? input, that is
				# not valid. One possible workaround would be to create an extra task
				# that simply just uses bash touch to create a blank file, but when
				# running locally even quick tasks slow down execution. So it's more
				# efficient to use some other file as the dummy file that will be
				# passed in when the user does define indeces and samtools index is
				# skipped. So what's a file that always will be defined, without
				# fail? The exact same bam or cram file we are running covstats on.
				allInputIndexes = allIndexes,
				inputIndex = select_first([index.outputIndex, oneBamOrCram])
		}
	}

	# not scattered
	call report {
		input:
			readLengths = scatteredGetStats.outReadLength,
			coverages = scatteredGetStats.outCoverage,
			filenames = scatteredGetStats.outFilenames
	}

	meta {
        author: "Ash O'Farrell"
        email: "aofarrel@ucsc.edu"
    }
}