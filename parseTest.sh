rm out.txt
COVOUT=$(tail -n +2 this.txt)
read -a COVARRAY <<< "$COVOUT"
echo "-=-=-=-=-=-=-=-=-=-" >> out.txt
echo "1" >> out.txt
echo ${COVARRAY[1]} >> out.txt
echo "2" >> out.txt
echo ${COVARRAY[2]} >> out.txt
echo "3" >> out.txt
echo ${COVARRAY[3]} >> out.txt
echo "10" >> out.txt
echo ${COVARRAY[10]} >> out.txt
echo "11" >> out.txt
echo ${COVARRAY[11]} >> out.txt