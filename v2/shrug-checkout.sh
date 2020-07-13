#!/bin/dash

if [ ! -d ".shrug" ]; then
	echo "shrug-checkout: error: no .shrug directory containing shrug repository exists"
	exit 1
fi

oldBranch=$(cat .shrug/.branch)
newBranch=$1

if [ ! -d ".shrug/$newBranch" ]; then
	echo "shrug-checkout: error: unknown branch '$newBranch'"
	exit 1
fi

echo "$newBranch" > ".shrug/.branch"
echo "Switched to branch '$newBranch'"

# This part is hard coded for a specific situation XD

for file in *; do
	if [ -f ".shrug/$oldBranch/staged/$file" ]; then
		cp ".shrug/$oldBranch/staged/$file" ".shrug/$newBranch/staged/"
	else
		rm -rf ".shrug/$newBranch/staged/$file"
	fi

	if [ -f ".shrug/$oldBranch/latest/$file" ]; then
		if cmp -s "$file" ".shrug/$oldBranch/latest/$file"; then
			rm -rf $file
		fi
	fi
done


# copy files from new branch index over
for file in .shrug/$newBranch/index/*; do
	if [ ! -f "$file" ] || [ -f $(basename $file) ]; then
		continue
	fi

	cp $file .
done



