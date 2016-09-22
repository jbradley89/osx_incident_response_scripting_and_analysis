#!/bin/bash
# Yara on the fly

tmpFile=".yara.tmp"
yaraRule="yarafly.yar"

echo "--add indicators you want to scan for below this line--" > $tmpFile
pico $tmpFile

#build rule with temp file contents
echo -e "rule onTheFly : fly\n{\n\tstrings:" > $yaraRule

counter=0
while read line; do
	#if statement skips the first line of the temp file
	if [ $counter -gt 0 ]; then
		echo -e "\t\t\$$counter = \"$line\"" >> $yaraRule
	fi
	((counter++))
done <$tmpFile

echo -e "\tcondition:\n\t\tany of them\n}" >> $yaraRule

rm $tmpFile

echo "Rule created - $yaraRule"
echo
cat $yaraRule