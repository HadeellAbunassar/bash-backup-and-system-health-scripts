#!/bin/bash

commands=("tar" "date" "du" "basename" "dirname" "crontab")
for cmd in "${commands[@]}"; do
    command -v "$cmd" >/dev/null 2>&1 || { echo >&2 "Error: $cmd command not found. Please install it."; exit 1; }
done

if [ "$#" -lt 2 ]; then
    echo "Usage: src_dir1 src_dir2 etc.. dst_dir"
    exit 1
fi

source_directories=("${@:1:$#-1}")
dst_dir="${@: -1}"

if [ ! -d "$dst_dir" ]; then
    echo "Error: Destination directory does not exist."
    exit 1
fi

for source_dir in "${source_directories[@]}"; do
    if [ ! -d "$source_dir" ]; then
        echo "Error: Source directory '$source_dir' does not exist."
        exit 1
    fi
done

log() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $1" >> "$log_file"
}

function perform_backup {
    currentTime=$(date +"%Y-%m-%d")

    backup_dir="$dst_dir/backup_$currentTime"
    log_filename="backup_log_$currentTime.txt"
    log_file="$dst_dir/$log_filename"

    if [ ! -w "$dst_dir" ]; then
        echo "Error: You can't write to the destination directory. Check your permissions!"
        exit 1
    fi

    mkdir "$backup_dir"

    for source_dir in "${source_directories[@]}"; do
        base_name=$(basename "$source_dir")
        tar_backup_filename="${base_name}_${currentTime}.tar.gz"
        tar_backup_path="$backup_dir/$tar_backup_filename"

        snapshot_file="$dst_dir/snapshot_${base_name}.txt"

        tar --create --gzip --file="$tar_backup_path" --listed-incremental="$snapshot_file" -C "$(dirname "$source_dir")" "$base_name"

        if [ $? -ne 0 ]; then
            log "Error: Tar command failed for $source_dir"
            exit 1
        fi
    done

    backup_size=$(du -sh "$backup_dir" | cut -f1)

    if [ $? -ne 0 ]; then
        log "Error: Failed to retrieve backup size for $backup_dir."
        exit 1
    fi

    log "Backup size: $backup_size"

    if [ $? -eq 0 ]; then
        log "Backup successful. Backup directory: $backup_dir"
        echo "Backup completed successfully."
    else
        log "Backup failed. Error: $?"
        echo "Backup failed. Check the log for details."
        exit 1
    fi
}

function schedule_backup {
    case $1 in
        daily)
            (crontab -l; echo "0 0 * * * backup.sh ${source_directories[@]} $dst_dir") | crontab -
            if [ $? -ne 0 ]; then
                echo "Error: Failed to schedule backup in crontab."
                exit 1
            fi
            echo "Backup scheduled daily."
            ;;
        weekly)
            (crontab -l; echo "0 0 * * 1 backup.sh ${source_directories[@]} $dst_dir") | crontab -
            if [ $? -ne 0 ]; then
                echo "Error: Failed to schedule backup in crontab."
                exit 1
            fi
            echo "Backup scheduled weekly."
            ;;
        monthly)
            (crontab -l; echo "0 0 1 * * backup.sh ${source_directories[@]} $dst_dir") | crontab -
            if [ $? -ne 0 ]; then
                echo "Error: Failed to schedule backup in crontab."
                exit 1
            fi
            echo "Backup scheduled monthly."
            ;;
        *)
            echo "Invalid! Please use 'daily', 'weekly', or 'monthly'."
            ;;
    esac
}

function list_and_delete_scheduled_backups {
    scheduled_backups=$(crontab -l | grep -E 'backup.sh' | cat -n)
    echo -e "List of scheduled backups:\n$scheduled_backups"

    read -p "Do you want to delete a scheduled backup? (y/n): " delete_choice

    if [[ $delete_choice == [Yy] ]]; then
        delete_scheduled_backup
    fi
}

function delete_scheduled_backup {
    read -p "Enter the line number of the scheduled backup you want to delete: " line_number
    crontab -l | sed -e "${line_number}d" | crontab -
    echo "Scheduled backup deleted."
}

if [[ -z "$SHELL" ]]; then
    perform_backup
else
    read -p "Do you want to perform a one-time backup, schedule it continuously (daily, weekly, monthly), list and delete scheduled backups? (0- one-time  1- continuous  2- list and delete) " choice

    case $choice in
        0)
            perform_backup
            ;;
        1)
            read -p "You want the backup to be scheduled daily, weekly, or monthly: " freq
            schedule_backup $freq
            ;;
        2)
            list_and_delete_scheduled_backups
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
fi