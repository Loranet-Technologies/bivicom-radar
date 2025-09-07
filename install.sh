#!/bin/bash

# =============================================================================
# Loranet Complete Infrastructure Setup - Curl Installation Script
# =============================================================================
# This script downloads and runs the complete infrastructure setup
# 
# Author: Aqmar
# Repository: https://github.com/Loranet-Technologies/bivicom-radar
# =============================================================================

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Repository information
REPO_URL="https://github.com/Loranet-Technologies/bivicom-radar"
SCRIPT_URL="https://raw.githubusercontent.com/Loranet-Technologies/bivicom-radar/main/complete_infrastructure_setup.sh"
INSTALL_DIR="/tmp/loranet-setup"

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

print_section() {
    echo
    echo "=========================================="
    echo -e "${YELLOW}$1${NC}"
    echo "=========================================="
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root. Please run as a regular user with sudo privileges."
        exit 1
    fi
}

# Function to check if curl is available
check_curl() {
    if ! command -v curl >/dev/null 2>&1; then
        print_error "curl is required but not installed. Please install curl first."
        print_status "On Ubuntu/Debian: sudo apt install curl"
        print_status "On CentOS/RHEL: sudo yum install curl"
        exit 1
    fi
}

# Function to download and setup
download_and_setup() {
    print_section "DOWNLOADING LORANET INFRASTRUCTURE SETUP"
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    print_status "Downloading complete infrastructure setup script..."
    curl -sSL "$SCRIPT_URL" -o complete_infrastructure_setup.sh
    
    if [ ! -f "complete_infrastructure_setup.sh" ]; then
        print_error "Failed to download the setup script"
        exit 1
    fi
    
    # Make script executable
    chmod +x complete_infrastructure_setup.sh
    
    print_success "Setup script downloaded successfully"
    print_status "Script location: $INSTALL_DIR/complete_infrastructure_setup.sh"
    
    # Display information
    echo
    print_status "=== LORANET INFRASTRUCTURE SETUP ==="
    echo -e "${GREEN}Repository:${NC} $REPO_URL"
    echo -e "${GREEN}Script Size:${NC} $(du -h complete_infrastructure_setup.sh | cut -f1)"
    echo -e "${GREEN}Author:${NC} Aqmar"
    echo
    print_status "This script will install:"
    echo "  • Node-RED with custom flows"
    echo "  • Tailscale VPN"
    echo "  • Docker & Docker Compose"
    echo "  • Portainer (Container Management)"
    echo "  • Restreamer (Video Streaming)"
    echo "  • UCI Configuration (OpenWrt)"
    echo
    print_warning "The installation will take several minutes and may require a reboot."
    echo
    
    # Check for auto-run flag
    if [[ "$1" == "--auto" || "$1" == "-y" || "$1" == "--yes" ]]; then
        print_status "Auto-run mode enabled. Proceeding with installation..."
    else
        # Ask for confirmation
        read -p "Do you want to proceed with the installation? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Installation cancelled by user."
            print_status "You can run the script manually later:"
            print_status "  cd $INSTALL_DIR && ./complete_infrastructure_setup.sh"
            print_status "Or use auto-run: curl -sSL $SCRIPT_URL | bash -s -- --auto"
            exit 0
        fi
    fi
    
    # Run the setup script
    print_section "STARTING INFRASTRUCTURE SETUP"
    ./complete_infrastructure_setup.sh
}

# Function to show help
show_help() {
    echo "Loranet Complete Infrastructure Setup - Curl Installation"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -d, --download Download only (don't run installation)"
    echo "  -v, --version  Show version information"
    echo "  -y, --yes, --auto  Auto-run without confirmation"
    echo
    echo "Examples:"
    echo "  $0                    # Download and run installation"
    echo "  $0 --download         # Download only"
    echo "  $0 --auto             # Auto-run without confirmation"
    echo "  curl -sSL https://raw.githubusercontent.com/Loranet-Technologies/bivicom-radar/main/install.sh | bash"
    echo "  curl -sSL https://raw.githubusercontent.com/Loranet-Technologies/bivicom-radar/main/install.sh | bash -s -- --auto"
    echo
    echo "Repository: $REPO_URL"
    echo "Author: Aqmar"
}

# Function to show version
show_version() {
    echo "Loranet Complete Infrastructure Setup"
    echo "Version: 1.0.0"
    echo "Author: Aqmar"
    echo "Repository: $REPO_URL"
    echo "Last Updated: $(date +%Y-%m-%d)"
}

# Main execution
main() {
    # Parse command line arguments
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            show_version
            exit 0
            ;;
        -d|--download)
            print_section "DOWNLOADING LORANET INFRASTRUCTURE SETUP"
            check_curl
            mkdir -p "$INSTALL_DIR"
            cd "$INSTALL_DIR"
            curl -sSL "$SCRIPT_URL" -o complete_infrastructure_setup.sh
            chmod +x complete_infrastructure_setup.sh
            print_success "Setup script downloaded to: $INSTALL_DIR/complete_infrastructure_setup.sh"
            print_status "Run it with: cd $INSTALL_DIR && ./complete_infrastructure_setup.sh"
            exit 0
            ;;
        -y|--yes|--auto)
            print_section "DOWNLOADING LORANET INFRASTRUCTURE SETUP (AUTO-RUN)"
            check_curl
            mkdir -p "$INSTALL_DIR"
            cd "$INSTALL_DIR"
            curl -sSL "$SCRIPT_URL" -o complete_infrastructure_setup.sh
            chmod +x complete_infrastructure_setup.sh
            print_success "Setup script downloaded successfully"
            print_status "Starting auto-run installation..."
            ./complete_infrastructure_setup.sh --auto
            exit 0
            ;;
        "")
            # No arguments, proceed with full installation
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
    
    # Pre-flight checks
    check_root
    check_curl
    
    # Download and setup
    download_and_setup
}

# Run main function
main "$@"
# Cache refresh Mon Sep  8 01:07:00 CST 2025
