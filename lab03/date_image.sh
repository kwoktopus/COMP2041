#!/bin/bash

for file in "$@"; do
	date=`ls -l | egrep "^.* $file$" | egrep -o "[A-Za-z]{3} [0-9]{2} [0-9]{2}:[0-9]{2}"`
	
	echo $file $date

	convert -gravity south -pointsize 36 -draw "text 0,10 'Andrew rocks'" $file $file 
done