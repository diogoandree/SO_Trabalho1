#!/bin/bash

function usage() {
    echo "Usage: $0 source_dir backup_dir"
    exit 1
}


if [[ $# -lt 2 ]]; then
    usage
fi


source_dir="$1"
backup_dir="$2"


if [[ ! -d "$source_dir" ]]; then
    echo "Error: Source directory '$source_dir' does not exist."
    exit 1
fi


shopt -s dotglob


function recursive_check() {
    local current_source_dir="$1"
    local current_backup_dir="$2"


    for file in "$current_source_dir"/*; do
        local filename=$(basename "$file")
        local backup_file="$current_backup_dir/$filename"

  
        if [[ -f "$file" && -f "$backup_file" ]]; then
            local source_hash=$(md5sum "$file" | awk '{print $1}')
            local backup_hash=$(md5sum "$backup_file" | awk '{print $1}')
            if [[ "$source_hash" != "$backup_hash" ]]; then
                echo "$file and $backup_file differ."
            fi

        elif [[ -d "$file" && -d "$backup_file" ]]; then
            recursive_check "$file" "$backup_file"

        elif [[ -e "$file" && ! -e "$backup_file" ]]; then
            echo "File or directory $file is missing in backup."
            
        elif [[ ! -e "$file" && -e "$backup_file" ]]; then
            echo "File or directory $backup_file is missing in source."
        fi
    done
}

recursive_check "$source_dir" "$backup_dir"

shopt -u dotglob