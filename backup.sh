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
        exclude_list["$line"]=1S
    done < "$tfile"
fi


function recursive_backup() {
    local current_source_dir="$1"
    local current_backup_dir="$2"

    if [[ ! -d "$current_backup_dir" ]]; then
        if $check_flag; then
            echo "mkdir -p $current_backup_dir"
        else
            mkdir -p "$current_backup_dir"
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
            if [[ ! -e "$backup_file" ]]; then
                echo "cp -a $file $backup_file"
                if ! $check_flag; then
                    cp -a "$file" "$backup_file"
                fi

            elif [[ "$file" -nt "$backup_file" || $(cmp -s "$file" "$backup_file" || echo "different") == "different" ]]; then
                if ! $check_flag; then
                    echo "cp -a $file $backup_file"
                    cp -a $file $backup_file
                fi
            fi


        elif [[ -d "$file" ]]; then
            local has_matching_files=false
            if [[ -n "$regex" ]]; then
                for subfile in "$file"/*; do
                    local subfilename=$(basename "$subfile")
                    if [[ -f "$subfile" && "$subfilename" =~ $regex ]]; then
                        has_matching_files=true
                        break
                    fi
                done
            else
                has_matching_files=true
            fi 

            if $has_matching_files; then
                recursive_backup "$file" "$backup_file"
            fi
        fi
    done

    for backup_file in "$current_backup_dir"/*; do
        local filename=$(basename "$backup_file")
        local source_file="$current_source_dir/$filename"

        if [[ ! -e "$source_file" && -e "$backup_file" ]]; then
            echo "rm -r $backup_file"
            if ! $check_flag; then
                rm -r "$backup_file"
            fi
        fi
    done
}


recursive_backup "$source_dir" "$backup_dir"

shopt -u dotglob