# this time the read length files do NOT have extra newlines
import sys

readLengthFiles = []
readLengths = []

# grab file names from command line
i = 1 
while i < (len(sys.argv)):
	readLengthFiles.append(sys.argv[i])
	i += 1

# grab read lengths for each file
for file in readLengthFiles:
	f = open(file, "r")
	readLengths.append(int(f.read().strip('\n')))

# print "table" with each inputs' read length
i = 0
while i < (len(readLengthFiles)):
	print(readLengthFiles[i], "-->", readLengths[i])
	i += 1

# print average read length
avg = sum(readLengths) / len(readLengths)
print("Average read length:", avg)