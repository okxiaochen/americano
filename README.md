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

**Interactive installation (recommended for first-time installation):**

Download and run the installation script:

```bash
curl -fsSL https://raw.githubusercontent.com/okxiaochen/americano/main/install.sh -o install.sh
chmod +x install.sh
./install.sh
```

**Non-interactive installation (for automation or when overwriting existing installation):**

```bash
curl -fsSL https://raw.githubusercontent.com/okxiaochen/americano/main/install.sh | bash -s -- -y
```

**Note:** Using `curl ... | bash` directly may not work properly for interactive prompts. For the best experience, download the script first and run it locally.

The script will:
- Check if `americano` is already installed
- Ask for confirmation before overwriting existing installations (in interactive mode)
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
americano t 30        # Abbreviated form
```

This will prevent sleep for 30 minutes, showing countdown messages every minute.

### Process-based Prevention

Prevent sleep while a specific process is running. You can specify either a PID (process ID) or a process name:

**Using a PID:**
```bash
americano pid 12345
americano p 12345     # Abbreviated form
americano 12345       # pid mode is default, can omit 'pid' or 'p'
```

**Using a process name (recommended):**
```bash
americano pid npm
americano p npm       # Abbreviated form
americano npm         # pid mode is default, can omit 'pid' or 'p'
americano node
americano python
```

When you use a process name, `americano` will:
1. Search for processes matching the name using `pgrep -f`
2. If multiple processes are found, display a numbered list for you to choose from
3. If only one process is found, automatically select it
4. Monitor the selected process and prevent sleep until it exits

**Process Selection Example:**

If you run `americano pid npm` and multiple npm processes are running, you'll see:

```
⚠️ Found 2 processes matching 'npm':

#   UID  PID    PPID   CPU  STIME    TTY      TIME     COMMAND
1)  501  28873  64696  0    0:00.05  ttys037  0:00.21  npm run backfill-update-asnote-content
2)  501  65194  31342  0    0:00.04  ttys012  0:00.12  npm run dev

Select process (1-2) or enter new search term:
```

You can then:
- Enter `1` or `2` to select a process from the list
- Enter a new search term to search again (e.g., `backfill` to narrow down the results)

**Finding Process IDs (PIDs) - Alternative Method:**

If you prefer to find the PID manually, here are some ways:

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

### Examples

```bash
# Prevent sleep for 2 hours during a large download
americano time 120
americano t 120       # Abbreviated form

# Prevent sleep while a backup process is running (using PID)
americano pid 9876
americano 9876        # pid mode is default

# Prevent sleep while npm processes are running (using process name)
americano pid npm
americano p npm       # Abbreviated form
americano npm         # pid mode is default

# Prevent sleep while a specific npm script is running
# (will show selection menu if multiple npm processes exist)
americano pid "npm run dev"
americano "npm run dev"  # pid mode is default

# Prevent sleep for 30 minutes while processing files
americano time 30
americano t 30        # Abbreviated form

# Prevent sleep AND display sleep while monitoring a process
americano -d pid node
americano -d p node   # Abbreviated form
americano -d node     # pid mode is default

# Send a Bark push notification to your iPhone when done
americano -b YOUR_BARK_KEY time 30
americano -b YOUR_BARK_KEY pid npm

# Using BARK_KEY env var (set export BARK_KEY=... in your shell profile)
americano -b time 30
americano -b pid npm

# Combine display sleep prevention + Bark notification
americano -d -b time 120
```

## Push Notifications (Bark)

`americano` can send a push notification to your iPhone when a timer completes or a monitored process exits, using [Bark](https://bark.day.app).

### Setup

1. Install the **Bark** app on your iOS device
2. Copy your device key from the app
3. Pass the `-b` / `--bark` flag when you want to receive a notification

Notifications are **opt-in** — they are only sent when you explicitly use the `-b` flag.

**Notification examples (what you'll see on your phone):**

| Scenario | Title | Body |
|---|---|---|
| Timer completed | americano ☕ | `30-minute timer completed.` |
| Process exited | americano ☕ | `Process 'npm' has exited. Total: 2h 30m 15s.` |
| Custom message (`-m`) | americano ☕ | `Deploy done!` |

### Usage

**Pass the key directly:**
```bash
americano -b YOUR_BARK_KEY time 30
americano -b YOUR_BARK_KEY pid npm
```

**Or set `BARK_KEY` env var to save typing (recommended):**
```bash
# Add to your ~/.zshrc or ~/.bashrc
export BARK_KEY="YOUR_BARK_KEY"

# Then just pass -b without a key — it reads from the env var
americano -b time 30
americano -b pid npm
```

Flags can be combined in any order:
```bash
americano -d -b YOUR_BARK_KEY time 30   # Prevent display sleep + Bark notification
americano -b -d pid node               # Same, using BARK_KEY env var
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
