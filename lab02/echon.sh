#!/bin/sh


# check arguments
if [ $# -ne 2 ]; then
	echo "Usage: ./echon.sh <number of lines> <string>"
	exit 1
fi

# check digit
if [[ "$1" =~ ^[0-9]+$ ]]; then
	for i in $(seq "$1"); do
		echo $2
	done
else
	echo "./echon.sh: argument 1 must be a non-negative integer"
fi



