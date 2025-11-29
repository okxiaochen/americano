#!/usr/bin/env bash

# americano — prevent macOS from sleeping based on time or process monitoring
# Usage: americano [-d] <time|pid> <value>
#   -d             — also prevent display from sleeping (optional)
#   time <minutes> — prevent sleep for the specified number of minutes
#   pid  <PID|name> — prevent sleep while the specified process is running
#                      Can be a PID (number) or process name (searches with pgrep -f)
#                      If multiple processes match, you'll be prompted to select one

# Parse optional flag
PREVENT_DISPLAY_SLEEP=false
if [ "$1" == "-d" ]; then
    PREVENT_DISPLAY_SLEEP=true
    shift
fi

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 [-d] <time|pid> <value>"
    echo ""
    echo "Options:"
    echo "  -d             — also prevent display from sleeping (optional)"
    echo ""
    echo "Modes:"
    echo "  time <minutes> — prevent sleep for the specified number of minutes"
    echo "  pid  <PID|name> — prevent sleep while the specified process is running"
    echo "                    Can be a PID (number) or process name (searches with pgrep -f)"
    echo "                    If multiple processes match, you'll be prompted to select one"
    echo ""
    echo "Examples:"
    echo "  $0 time 30              # Prevent sleep for 30 minutes"
    echo "  $0 pid 12345            # Monitor process with PID 12345"
    echo "  $0 pid npm              # Search for 'npm' processes and select one"
    echo "  $0 -d pid node          # Monitor 'node' process, also prevent display sleep"
    exit 1
fi

MODE=$1
ARG=$2
CAFFEINATE_PID=""

# Start preventing system sleep
start_prevent_sleep() {
    # -i: prevent idle sleep
    # -m: prevent disk sleep
    # -s: prevent sleep when connected to power
    # -d: prevent display sleep (optional)
    if [ "$PREVENT_DISPLAY_SLEEP" == "true" ]; then
        caffeinate -imsd &
        CAFFEINATE_PID=$!
        echo "▶️ Preventing system and display sleep (caffeinate PID=$CAFFEINATE_PID)"
    else
        caffeinate -ims &
        CAFFEINATE_PID=$!
        echo "▶️ Preventing system sleep, allowing display sleep (caffeinate PID=$CAFFEINATE_PID)"
    fi
}

# Stop preventing system sleep
stop_prevent_sleep() {
    if [[ -n "$CAFFEINATE_PID" ]]; then
        if kill "$CAFFEINATE_PID" 2>/dev/null; then
            echo "⏹ Sleep prevention stopped (killed PID=$CAFFEINATE_PID)"
        else
            echo "⚠️ Failed to stop PID $CAFFEINATE_PID — it may have already exited"
        fi
        CAFFEINATE_PID=""
    fi
}

# Clean up on exit
trap "stop_prevent_sleep; exit" SIGINT SIGTERM SIGHUP

# Check if a given PID is running
check_process() {
    ps -p "$PID" > /dev/null 2>&1
}

# Retrieve the name of a given PID
get_process_name() {
    ps -p "$PID" -o comm= 2>/dev/null
}

# Search for processes by name and let user select if multiple found
# Outputs the selected PID to stdout, error messages to stderr
search_and_select_process() {
    local search_term=$1
    local pids
    local pid_count
    local selected_index
    local i
    local current_pid
    local user_input
    local result
    
    pids=$(pgrep -f "$search_term")
    if [ -z "$pids" ]; then
        echo "❌ No process found matching '$search_term'" >&2
        return 1
    fi
    
    # Count processes
    pid_count=$(echo "$pids" | wc -l | tr -d ' ')
    
    if [ "$pid_count" -eq 1 ]; then
        echo "$pids" | head -n 1
        return 0
    fi
    
    # Multiple processes found - show list and let user select
    echo "⚠️ Found $pid_count processes matching '$search_term':" >&2
    echo "" >&2
    
    # Collect all process info for alignment
    {
        # Header with "#" column
        echo "# UID PID PPID C STIME TTY TIME CMD"
        
        # Add numbered process lines, getting command as a single field
        i=1
        for pid in $pids; do
            uid=$(ps -p "$pid" -o uid= | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            pid_val=$(ps -p "$pid" -o pid= | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            ppid=$(ps -p "$pid" -o ppid= | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            cpu=$(ps -p "$pid" -o cpu= | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            stime=$(ps -p "$pid" -o stime= | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            tty=$(ps -p "$pid" -o tty= | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            time=$(ps -p "$pid" -o time= | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            cmd=$(ps -p "$pid" -o command= | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            echo "$i) $uid $pid_val $ppid $cpu $stime $tty $time $cmd"
            i=$((i + 1))
        done
    } | column -t >&2
    echo "" >&2
    
    # Loop until user provides valid input
    while true; do
        read -p "Select process (1-$pid_count) or enter new search term: " user_input
        
        # Check if input is a number
        if [[ "$user_input" =~ ^[0-9]+$ ]]; then
            selected_index=$user_input
            if [ "$selected_index" -ge 1 ] && [ "$selected_index" -le "$pid_count" ]; then
                echo "$pids" | sed -n "${selected_index}p"
                return 0
            else
                echo "❌ Invalid selection. Please enter a number between 1 and $pid_count" >&2
            fi
        else
            # User entered a string - search again
            echo "" >&2
            echo "🔍 Searching for '$user_input'..." >&2
            # Recursively search - result goes to stdout, messages to stderr
            result=$(search_and_select_process "$user_input")
            exit_code=$?
            if [ $exit_code -eq 0 ] && [ -n "$result" ]; then
                echo "$result"
                return 0
            else
                echo "" >&2
                echo "💡 You can try again or select from the previous list (1-$pid_count)" >&2
            fi
        fi
    done
}

if [ "$MODE" == "pid" ]; then
    # If ARG is not a number, try to find the process by name using pgrep
    if ! [[ "$ARG" =~ ^[0-9]+$ ]]; then
        PID=$(search_and_select_process "$ARG")
        if [ $? -ne 0 ] || [ -z "$PID" ]; then
            exit 1
        fi
    else
        PID=$ARG
    fi
    
    if ! check_process; then
        echo "❌ Process $PID is not running"
        exit 1
    fi

    PROC_NAME=$(get_process_name)
    start_prevent_sleep
    echo "🔍 Monitoring process $PID ($PROC_NAME) — preventing sleep"

    while check_process; do
        echo "$(date '+%Y-%m-%d %H:%M:%S') — Process $PID ($PROC_NAME) is still running"
        sleep 60
    done

    echo "$(date '+%Y-%m-%d %H:%M:%S') — Process $PID ($PROC_NAME) has exited"
    stop_prevent_sleep
    echo "💤 System sleep behavior restored"

elif [ "$MODE" == "time" ]; then
    MINUTES=$ARG
    SECONDS=$(( MINUTES * 60 ))
    END_TS=$(( $(date +%s) + SECONDS ))

    start_prevent_sleep
    echo "⏱️ Preventing sleep for $MINUTES minutes"

    while true; do
        NOW=$(date +%s)
        if [ "$NOW" -ge "$END_TS" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') — Timer completed"
            stop_prevent_sleep
            echo "💤 System sleep behavior restored"
            exit 0
        fi

        LEFT=$(( (END_TS - NOW) / 60 ))
        echo "$(date '+%Y-%m-%d %H:%M:%S') — $LEFT minutes remaining"
        sleep 60
    done

else
    echo "❗ Invalid mode. Specify 'time' or 'pid'"
    exit 1
fi