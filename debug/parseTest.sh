# clean up
rm out1.txt
rm out2.txt

# extract read length from one file
COVOUT=$(tail -n +2 this.txt)
read -a COVARRAY <<< "$COVOUT"
echo "-=-=-=-=-=-=-=-=-=-" >> out1.txt
echo ${COVARRAY[11]} >> out1.txt


# extract read length from two files, which are one
# integer followed by a newline
readLengthFiles=("readlength1.txt" "readlength2.txt")
for file in ${readLengthFiles[@]}
do
	while read line; do
		echo "${file}"
		echo "  * Read length: ${line}"
		#IFS=$'\n' read -d '' -r -a allReadLengths < ${file}
	done < ${file}
done

echo ${allReadLengths[@]} >> out2.txt