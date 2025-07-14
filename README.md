# americano ☕

A command-line tool for macOS that prevents your computer from sleeping during long-running tasks like downloads, batch processing, or any other operations where you want to keep your system awake even when the display is off.

## What it does

`americano` uses macOS's built-in `caffeinate` command to prevent system sleep while allowing the display to sleep/lock. This is perfect for:

- Large file downloads
- Batch processing tasks
- Long-running scripts
- Background computations
- Any task where you want to walk away but keep the system running

## Installation

### Option 1: Automatic Installation (Recommended)

Run the installation script:

```bash
curl -fsSL https://raw.githubusercontent.com/okxiaochen/americano/main/install.sh | bash
```

The script will:
- Check if `americano` is already installed
- Ask for confirmation before overwriting existing installations
- Install the script to `/usr/local/bin/americano`
- Make it executable

### Option 2: Manual Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/okxiaochen/americano.git
   cd americano
   ```

2. Make the script executable:
   ```bash
   chmod +x americano.sh
   ```

3. Move it to your PATH:
   ```bash
   sudo cp americano.sh /usr/local/bin/americano
   ```

## Usage

### Time-based Prevention

Prevent sleep for a specific number of minutes:

```bash
americano time 30
```

This will prevent sleep for 30 minutes, showing countdown messages every minute.

### Process-based Prevention

Prevent sleep while a specific process is running:

```bash
americano pid 12345
```

This will monitor process ID 12345 and prevent sleep until that process exits.

#### Finding Process IDs (PIDs)

There are several ways to find the PID of a process you want to monitor:

**Using `ps` command:**
```bash
# List all processes
ps aux

# Find a specific process by name
ps aux | grep "process_name"

# Find processes containing "node"
ps aux | grep node
```

**Using `pgrep` command:**
```bash
# Find PID by process name
pgrep "process_name"

# Find PID by process name (exact match)
pgrep -x "process_name"

# Find all PIDs for processes containing "node"
pgrep -f node
```

**Using Activity Monitor (GUI):**
1. Open Activity Monitor (Applications > Utilities > Activity Monitor)
2. Find your process in the list
3. The PID is shown in the "PID" column

**Common examples:**
```bash
# Monitor a Node.js development server
pgrep -f "node.*server" | head -1 | xargs americano pid

# Monitor a Python script
pgrep -f "python.*script.py" | head -1 | xargs americano pid

# Monitor a build process
pgrep -f "npm.*build" | head -1 | xargs americano pid

# Monitor a backup process
pgrep -f "rsync" | head -1 | xargs americano pid

# Monitor a download process
pgrep -f "curl" | head -1 | xargs americano pid
```

### Examples

```bash
# Prevent sleep for 2 hours during a large download
americano time 120

# Prevent sleep while a backup process is running
americano pid 9876

# Prevent sleep for 30 minutes while processing files
americano time 30
```

## How it works

The script uses macOS's `caffeinate` command with these flags:
- `-i`: Prevent idle sleep
- `-m`: Prevent disk sleep  
- `-s`: Prevent sleep when connected to power

This allows your display to sleep/lock while keeping the system awake for your background tasks.

## Requirements

- macOS (uses `caffeinate` command)
- Bash shell

## License

MIT License - feel free to use and modify as needed.

## Contributing

Pull requests and issues are welcome!
