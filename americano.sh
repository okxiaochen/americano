#!/usr/bin/env bash

# americano — prevent macOS from sleeping based on time or process monitoring
# Usage: americano [-d] [time|t|pid|p] <value>
#        americano [-d] <PID|name>              # pid mode (default)
#   -d             — also prevent display from sleeping (optional)
#   time, t <minutes> — prevent sleep for the specified number of minutes
#   pid, p <PID|name> — prevent sleep while the specified process is running
#   <PID|name>        — defaults to pid mode (can omit 'pid' or 'p')
#                        Can be a PID (number) or process name (searches with pgrep -f)
#                        If multiple processes match, you'll be prompted to select one

# GitHub repository URL
GITHUB_REPO="https://github.com/okxiaochen/americano"
GITHUB_RAW="https://raw.githubusercontent.com/okxiaochen/americano/main"

# Function to display help information
show_help() {
    local exit_code=${1:-1}  # Default to exit code 1 (error), unless specified as 0 (success)
    echo "Usage: $0 [-d] [time|t|pid|p] <value>"
    echo "       $0 [-d] <PID|name>              # pid mode (default, can omit 'pid')"
    echo "       $0 --update                    # Update americano to latest version"
    echo ""
    echo "Options:"
    echo "  -d, --display   — also prevent display from sleeping (optional)"
    echo "  -u, --update    — update americano to latest version from GitHub"
    echo "  -h, --help      — show this help message"
    echo ""
    echo "Modes:"
    echo "  time, t <minutes> — prevent sleep for the specified number of minutes"
    echo "  pid, p <PID|name> — prevent sleep while the specified process is running"
    echo "                      Can be a PID (number) or process name (searches with pgrep -f)"
    echo "                      If multiple processes match, you'll be prompted to select one"
    echo "  <PID|name>        — defaults to pid mode (can omit 'pid' or 'p')"
    echo ""
    echo "Examples:"
    echo "  $0 time 30              # Prevent sleep for 30 minutes"
    echo "  $0 t 30                 # Same as above (abbreviated)"
    echo "  $0 pid 12345            # Monitor process with PID 12345"
    echo "  $0 p npm               # Search for 'npm' processes (abbreviated)"
    echo "  $0 npm                  # Same as above (pid mode is default)"
    echo "  $0 12345                # Monitor process with PID 12345 (pid mode is default)"
    echo "  $0 -d pid node          # Monitor 'node' process, also prevent display sleep"
    echo "  $0 --update             # Update to latest version"
    echo ""
    echo "GitHub: $GITHUB_REPO"
    exit $exit_code
}

# Check for help flag first
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    show_help 0  # Exit with success code when explicitly requesting help
fi

# Check for update flag
if [ "$1" == "--update" ] || [ "$1" == "-u" ]; then
    echo "🔄 Updating americano..."
    
    # Get the script path (handle symlinks and different systems)
    if [ -L "$0" ]; then
        # If script is a symlink, resolve it
        SCRIPT_PATH=$(readlink "$0" 2>/dev/null || greadlink "$0" 2>/dev/null || echo "$0")
        # If relative path, make it absolute
        if [ "${SCRIPT_PATH#/}" = "$SCRIPT_PATH" ]; then
            SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$SCRIPT_PATH"
        fi
    else
        # Get absolute path
        SCRIPT_PATH=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
    fi
    
    if [ ! -f "$SCRIPT_PATH" ]; then
        echo "❌ Could not determine script location. Please update manually from:"
        echo "   $GITHUB_REPO"
        exit 1
    fi
    
    # Download latest version
    TEMP_FILE=$(mktemp)
    if curl -fsSL "$GITHUB_RAW/americano.sh" -o "$TEMP_FILE" 2>/dev/null; then
        # Check if download was successful and not empty
        if [ -s "$TEMP_FILE" ] && grep -q "americano" "$TEMP_FILE" 2>/dev/null; then
            # Backup current version
            cp "$SCRIPT_PATH" "$SCRIPT_PATH.bak" 2>/dev/null || true
            
            # Install new version
            if cp "$TEMP_FILE" "$SCRIPT_PATH" 2>/dev/null || sudo cp "$TEMP_FILE" "$SCRIPT_PATH" 2>/dev/null; then
                chmod +x "$SCRIPT_PATH" 2>/dev/null || sudo chmod +x "$SCRIPT_PATH" 2>/dev/null
                rm -f "$TEMP_FILE"
                echo "✅ americano updated successfully!"
                echo "   Backup saved to: $SCRIPT_PATH.bak"
                exit 0
            else
                echo "❌ Failed to update. Please run with sudo or update manually from:"
                echo "   $GITHUB_REPO"
                rm -f "$TEMP_FILE"
                exit 1
            fi
        else
            echo "❌ Downloaded file appears to be invalid."
            rm -f "$TEMP_FILE"
            exit 1
        fi
    else
        echo "❌ Failed to download update. Please check your internet connection or update manually from:"
        echo "   $GITHUB_REPO"
        rm -f "$TEMP_FILE"
        exit 1
    fi
fi

# Parse optional flag
PREVENT_DISPLAY_SLEEP=false
if [ "$1" == "-d" ] || [ "$1" == "--display" ]; then
    PREVENT_DISPLAY_SLEEP=true
    shift
fi

# Parse mode and argument
# Support: time/t <minutes> or pid/p <PID|name> or just <PID|name> (defaults to pid)
if [ "$#" -lt 1 ]; then
    show_help
fi

# Determine mode and argument
if [ "$#" -eq 1 ]; then
    # Only one argument - default to pid mode
    MODE="pid"
    ARG=$1
elif [ "$#" -eq 2 ]; then
    # Two arguments - check if first is a mode keyword
    case "$1" in
        time|t)
            MODE="time"
            ARG=$2
            ;;
        pid|p)
            MODE="pid"
            ARG=$2
            ;;
        *)
            echo "Error: Invalid mode '$1'. Use 'time'/'t' or 'pid'/'p', or omit for pid mode." >&2
            exit 1
            ;;
    esac
else
    echo "Error: Too many arguments." >&2
    exit 1
fi
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