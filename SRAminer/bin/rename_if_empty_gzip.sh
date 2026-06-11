#!/usr/bin/env bash

#Small script which checks the size of a gzip file
#If empty it renames the file (removing the .gz) and replaces with a truly empty file

uncompessed_size=$(gzip --list "$1" | awk 'END {print $2}')

if [ "$uncompessed_size" -eq 0 ]; then
    echo "$1 is empty"
    old_file="$1"
    new_file=$(basename "$old_file" .gz)
    mv "$old_file" "$new_file" && echo '' > "$new_file"
else
    echo "uncompressed, $1  is $uncompessed_size bytes? in size"
fi
