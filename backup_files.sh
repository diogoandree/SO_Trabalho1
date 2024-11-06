#!/bin/bash

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 [-c] source_dir backup_dir"
    exit 1
fi

check_flag=false
if [[ "$1" == "-c" ]]; then
    check_flag=true
    shift
fi

source_dir="$1"
backup_dir="$2"

if [[ ! -d "$source_dir" ]]; then
    echo "Error: Source directory '$source_dir' does not exist."
    exit 1
fi

if [[ ! -d "$backup_dir" ]]; then
    if $check_flag; then
        echo "mkdir -p $backup_dir"
    else
        mkdir -p "$backup_dir"
        echo "mkdir -p $backup_dir"
    fi
fi

shopt -s dotglob

for file in "$source_dir"/*; do
    if [[ -f "$file" ]]; then
    filename=$(basename "$file")
    backup_file="$backup_dir/$filename"

        if [[ ! -e "$backup_file" || "$file" -nt "$backup_file" ]]; then
            echo "cp -a $file $backup_file"
            if ! $check_flag; then
                cp -a "$file" "$backup_file"
            fi
        fi
    fi
done

for file in "$backup_dir"/*; do
    filename=$(basename "$file")
    source_file="$source_dir/$filename"

    if [[ ! -e "$source_file" ]]; then
        echo "rm $file"
        if ! $check_flag; then
            rm "$file"
        fi
    fi
done

shopt -u dotglob