#!/usr/bin/env bash

# americano installation script
# Installs the americano script to /usr/local/bin/

set -e

# Parse command line arguments
FORCE_OVERWRITE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes)
            FORCE_OVERWRITE=true
            shift
            ;;
        *)
            echo "Usage: $0 [-y|--yes]"
            echo "  -y, --yes    Force overwrite existing installation"
            exit 1
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script is designed for macOS only."
    print_error "The americano tool uses macOS's 'caffeinate' command."
    exit 1
fi

# Check if caffeinate is available
if ! command -v caffeinate &> /dev/null; then
    print_error "caffeinate command not found. This should be available on macOS."
    exit 1
fi

# Installation directory
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="americano"
SCRIPT_PATH="$INSTALL_DIR/$SCRIPT_NAME"

print_status "Installing americano to $SCRIPT_PATH"

# Check if script already exists
if [[ -f "$SCRIPT_PATH" ]]; then
    print_warning "americano is already installed at $SCRIPT_PATH"
    echo
    
    # Check if we're in an interactive terminal or force overwrite is enabled
    if [[ -t 0 ]] && [[ "$FORCE_OVERWRITE" == "false" ]]; then
        read -p "Do you want to overwrite the existing installation? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Installation cancelled."
            exit 0
        fi
    elif [[ "$FORCE_OVERWRITE" == "false" ]]; then
        print_warning "Running in non-interactive mode. Choose one of these options:"
        print_warning ""
        print_warning "Option 1: Force overwrite with -y flag:"
        print_warning "  curl -fsSL https://raw.githubusercontent.com/okxiaochen/americano/main/install.sh | bash -s -- -y"
        print_warning ""
        print_warning "Option 2: Manually remove existing installation and reinstall:"
        print_warning "  sudo rm /usr/local/bin/americano"
        print_warning "  curl -fsSL https://raw.githubusercontent.com/okxiaochen/americano/main/install.sh | bash"
        print_warning ""
        print_warning "Option 3: Download and run interactively:"
        print_warning "  curl -fsSL https://raw.githubusercontent.com/okxiaochen/americano/main/install.sh -o install.sh"
        print_warning "  chmod +x install.sh"
        print_warning "  ./install.sh"
        exit 1
    fi
    print_status "Overwriting existing installation..."
fi

# Download the script
print_status "Downloading americano script..."

# Try to download from GitHub if we're running the install script directly
SCRIPT_URL="https://raw.githubusercontent.com/okxiaochen/americano/main/americano.sh"

if curl -fsSL "$SCRIPT_URL" -o /tmp/americano.sh 2>/dev/null; then
    print_success "Downloaded script from GitHub"
else
    print_error "Failed to download script from GitHub."
    print_error "Please make sure the repository URL is correct or install manually."
    exit 1
fi

# Make the script executable
chmod +x /tmp/americano.sh

# Install to /usr/local/bin (requires sudo)
print_status "Installing to $INSTALL_DIR (requires sudo privileges)..."

if sudo cp /tmp/americano.sh "$SCRIPT_PATH"; then
    print_success "americano installed successfully!"
else
    print_error "Failed to install americano. Please check your sudo privileges."
    exit 1
fi

# Clean up
rm -f /tmp/americano.sh

# Test the installation
if command -v americano &> /dev/null; then
    print_success "Installation verified! You can now use 'americano' command."
    echo
    print_status "Usage examples:"
    echo "  americano time 30    # Prevent sleep for 30 minutes"
    echo "  americano pid 12345  # Prevent sleep while process 12345 is running"
    echo
    print_status "Run 'americano' without arguments to see full usage information."
else
    print_warning "Installation completed but 'americano' command not found in PATH."
    print_warning "You may need to restart your terminal or add $INSTALL_DIR to your PATH."
fi 