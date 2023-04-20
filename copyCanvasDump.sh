#!/bin/bash
## Legacy processing of a archive from Canvas, containing multiple student submissions.
#
# copyCanvasDump.sh <src> <dest> <unpack>
#
# src :   Folder containing the unpacked Canvas Archive, should be files following the canvas naming
#         style.
# dest:   Where to store the files, one catalog/student. All files belonging to that user will be in
#         that folder.
# unpack: If 1, any archive (tar.gz) will be unpacked and saved to the dest/student_folder.
#



src=$1
dst=$2
unpack=$3

echo "src $src"
echo "dst $dst"

for item in $src/*;
do
    IFS=_ read name number1 number2 filenameBase <<< "$item";
    name=$(basename $name);
    filename=$(echo $filenameBase | sed 's/-[0-9]//g' | sed 's/\s//g' )

    echo "Working on $item "
    echo "Student: $name"
    echo "File: $filename  ($filenameBase) "

    if [[ ! -e "$dst/$name" ]];then
        mkdir -p "$dst/$name"
    elif [[ ! -d "$dst/$name" ]]; then
        echo "$dst/name already exists but it not a directory";
    fi

    echo "Copying $item -> $dst/$name/$filename"
    cp "$item" "$dst/$name/$filename"
    echo "-------------"
    echo " "
    ord=$(pwd)
    if [[ -v unpack ]]; then
	echo "Unpacking $dst/$name/$filename --> $dst/$name "
        tar -zxvf $dst/$name/$filename -C $dst/$name/
	cd $dst/$name/
	pwd
	ls
	rm *.exe *.stackdump
	make clean;make
	cd $ord
    else
	echo "unpack was this"
    fi
    
#    read -p "press enter to continue"
    
       
done
