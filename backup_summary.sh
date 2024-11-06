#!/bin/bash

function usage() {
    echo "Usage: $0 [-c] [-b tfile] [-r regexpr] source_dir backup_dir"
    exit 1
}


check_flag=false
tfile=""
regex=""

while getopts 'cb:r:' flag; do
    case "${flag}" in
        c) check_flag=true ;;
        b) tfile="${OPTARG}" ;;
        r) regex="${OPTARG}" ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))


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


declare -A exclude_list
if [[ -n "$tfile" && -f "$tfile" ]]; then
    while IFS= read -r line; do
        exclude_list["$line"]=1
    done < "$tfile"
fi


warnings=0
errors=0
updated=0
copied=0
deleted=0
total_size_copied=0
total_size_deleted=0


function recursive_backup() {
    local current_source_dir="$1"
    local current_backup_dir="$2"
    
    
    local local_warnings=0
    local local_errors=0
    local local_updated=0
    local local_copied=0
    local local_deleted=0
    local local_size_copied=0
    local local_size_deleted=0

    
    if [[ ! -d "$current_backup_dir" ]]; then
        if $check_flag; then
            echo "mkdir -p $current_backup_dir"
        else
            mkdir -p "$current_backup_dir" || { echo "Error creating directory: $current_backup_dir"; local_errors=$((local_errors + 1)); }
            echo "mkdir -p $current_backup_dir"
        fi
    fi

    
    for file in "$current_source_dir"/*; do
        local filename=$(basename "$file")

        
        if [[ -n "${exclude_list[$filename]}" ]]; then
            continue
        fi

        local backup_file="$current_backup_dir/$filename"

        
        if [[ -f "$file" && ( -z "$regex" || "$filename" =~ $regex ) ]]; then
            if [[ ! -e "$backup_file" || "$file" -nt "$backup_file" ]]; then
                echo "cp -a $file $backup_file"
                if ! $check_flag; then
                    cp -a "$file" "$backup_file" || { echo "Error copying file: $file"; local_errors=$((local_errors + 1)); continue; }
                    local_copied=$((local_copied + 1))
                    local_size_copied=$((local_size_copied + $(stat -c%s "$file")))
                fi
            fi
            if [[ -e "$backup_file" && "$file" -nt "$backup_file" ]]; then
                local_updated=$((local_updated + 1))
            elif [[ "$backup_file" -nt "$file" ]]; then
                echo "WARNING: backup entry $backup_file is newer than $file"
                local_warnings=$((local_warnings + 1))
            fi

        
        elif [[ -d "$file" ]]; then
            recursive_backup "$file" "$backup_file"
        fi
    done

    
    for backup_file in "$current_backup_dir"/*; do
        local filename=$(basename "$backup_file")
        local source_file="$current_source_dir/$filename"

        if [[ ! -e "$source_file" && -e "$backup_file" ]]; then
            echo "rm -r $backup_file"
            if ! $check_flag; then
                rm -r "$backup_file" || { echo "Error removing $backup_file"; local_errors=$((local_errors + 1)); continue; }
                local_deleted=$((local_deleted + 1))
                local_size_deleted=$((local_size_deleted + $(stat -c%s "$backup_file" 2>/dev/null || echo 0)))
            fi
        fi
    done

    
    echo "While backing up $current_source_dir: $local_errors Errors; $local_warnings Warnings; $local_updated Updated; $local_copied Copied ($local_size_copied B); $local_deleted Deleted ($local_size_deleted B)"
    
    
    warnings=$((warnings + local_warnings))
    errors=$((errors + local_errors))
    updated=$((updated + local_updated))
    copied=$((copied + local_copied))
    deleted=$((deleted + local_deleted))
    total_size_copied=$((total_size_copied + local_size_copied))
    total_size_deleted=$((total_size_deleted + local_size_deleted))
}


recursive_backup "$source_dir" "$backup_dir"


shopt -u dotglob