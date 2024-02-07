#!/bin/bash

function check_memory_usage() {
 echo "Memory usage : "
  
  free_mem=$(cat /proc/meminfo | grep MemFree | awk '{print $2}')
  total_mem=$(cat /proc/meminfo | grep MemTotal | awk '{print $2}')

  mem_usage=$((100 * (total_mem - free_mem) / total_mem))

  echo "Free memory: $free_mem kB "
  echo "Used memory: $((total_mem - free_mem)) kB from $total_mem kB , (${mem_usage}%)"
  echo
  
}

function check_virtual_memory_usage() {
  echo "Virtual memory usage:"

  vm_total=$(grep VmallocTotal /proc/meminfo | awk '{print $2}')
  vm_used=$(grep VmallocUsed /proc/meminfo | awk '{print $2}')
  vm_free=$((vm_total - vm_used))
  vm_usage=$((100 * vm_used / vm_total))


  echo "Virtual memory available: $vm_free kB"
  echo "Virtual memory used: $vm_used kB of $vm_total ($vm_usage%)"
  echo
}

function check_swap_usage() {
  echo "Swap usage:"

  swap_total=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
  swap_free=$(grep SwapFree /proc/meminfo | awk '{print $2}')
  swap_used=$((swap_total - swap_free))
  swap_usage=$((100 * swap_used / swap_total))

 
  echo "Free swap: $swap_free kB"
  echo "Used swap: $swap_used from $swap_total kB ($swap_usage%)"
}


function get_process_wait_time() {
  load_avg=$(head -n 1 /proc/loadavg | awk '{print $1}')
  num_cpus=$(grep -c ^processor /proc/cpuinfo)
  wait_time=$(echo "scale=2; $load_avg / $num_cpus" | bc)

  echo "The expected process wait time is : $wait_time seconds"
  echo
}

function CheckNetworkConnectivity() {
  IP=$(ip route get 8.8.8.8)
  if [[ $? -ne 0 ]]; then
   echo "Network connectivity issue detected!"
   else
    echo "Network connectivity appears to be working good!"
  fi
  echo 
}


function top3proc() {
    echo "Top 3 memory-consuming processes:"
    ps aux --sort -rss | awk 'NR>1 && NR<=4 {print "Process:", $11, "Memory:", $6 " kB", "CPU:", $3 "%"}'

    echo

    echo "Top 3 CPU-intensive processes:"
    ps aux --sort -pcpu | awk 'NR>1 && NR<=4 {print "Process:", $11, "Memory:", $6 " kB", "CPU:", $3 "%"}'
    echo 
}


get_system_info() {
    echo "Hostname: $(hostname)"
    echo "Kernel Version: $(uname -r)"
    echo "Last Reboot Time: $(who -b | awk '{print $3,$4}')"
    echo 
}

CheckDiskSpace() {
    while read -r line; do
        filesystem=$(echo "$line" | awk '{print $1}')
        size=$(echo "$line" | awk '{print $2}')
        used=$(echo "$line" | awk '{print $3}')
        available=$(echo "$line" | awk '{print $4}')
        percentage=$(echo "$line" | awk '{print $5}' | cut -d'%' -f1)

      
        echo "Filesystem: $filesystem"
        echo "Size: $size"
        echo "Used: $used"
        echo "Available: $available"
        echo "Mounted on: $(echo "$line" | awk '{print $6}')"

        
        if [ "$percentage" -gt 90 ]; then
            echo "Critical Warning: Disk space usage for $filesystem is $percentage%, exceeding 90%."
        elif [ "$percentage" -gt 70 ]; then
            echo "Warning: Disk space usage for $filesystem is $percentage%, Take care of you diskspace!"
        else
            echo "Disk space usage for $filesystem is $percentage%, All things are good!"
        fi

        echo
    done < <(df -h | awk 'NR>1')
    echo 
}

show_system_update_info() {
    last_update_timestamp=$(stat -c %y /var/lib/apt/lists/* | sort -n | tail -1)

    echo "Last System Update: $last_update_timestamp"

    available_updates=$(apt-get -s upgrade | grep -oP '\d+ upgraded' | head -n 1)
    available_updates=${available_updates%% upgraded}  # Extract integer

    if [[ "$available_updates" -gt 0 ]]; then
        echo "Available Updates: $available_updates packages can be upgraded."
    else
        echo "No updates available."
    fi 
}

echo "                     System Info"
 echo "----------------------------------------------------"
get_system_info
echo "----------------------------------------------------"
echo "                     Network Connectivity"
 echo "----------------------------------------------------"
CheckNetworkConnectivity
echo "----------------------------------------------------"
echo "                     processes"
 echo "----------------------------------------------------"
get_process_wait_time
top3proc
echo "----------------------------------------------------"
echo "                     Memory"
 echo "----------------------------------------------------"
check_memory_usage
check_virtual_memory_usage
check_swap_usage
echo "----------------------------------------------------"
echo "                    Disk Space - File System"
 echo "----------------------------------------------------"
CheckDiskSpace
echo "----------------------------------------------------"
echo "                     System updates"
 echo "----------------------------------------------------"
show_system_update_info



