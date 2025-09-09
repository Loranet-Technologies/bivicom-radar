#!/bin/bash

# =============================================================================
# Complete Infrastructure Setup Script with UCI Configuration
# =============================================================================
# This script combines Node-RED, Tailscale, Docker, Portainer, Restreamer,
# curl, and UCI configuration setup for OpenWrt systems
# Includes LAN configuration fixes and improved error handling
# 
# Author: Aqmar
# Date: $(date +%Y-%m-%d)
# Version: 2.0
# =============================================================================

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
NODE_VERSION="18"
NVM_VERSION="v0.39.1"
NODERED_USER="$USER"
NODERED_HOME="/home/$USER"
TIMEZONE="Asia/Kuala_Lumpur"
RESTREAMER_USERNAME="admin"
RESTREAMER_PASSWORD="L@ranet2025"
RESTREAMER_DATA_DIR="/data/restreamer/db"
PORTAINER_DATA_DIR="/data/portainer"
RESTREAMER_CONFIG_DIR="/data/restreamer"

# UCI Configuration variables (will be set interactively)
TARGET_HOSTNAME=""
TARGET_LAN_IP=""
TARGET_LAN_NETMASK="255.255.255.0"
TARGET_LAN_MAC="00:52:24:4d:d8:cc"
TARGET_WIFI_SSID=""
TARGET_WIFI_PASSWORD="1qaz2wsx"
TARGET_WIFI_CHANNEL="10"
TARGET_TIMEZONE="GMT-8"
TARGET_ZONENAME="(GMT+08:00) Beijing, Chongqing, Hong Kong, Urumqi"
TARGET_MODEL="TG451-STD"
TARGET_APN="Max4g"

echo "************************************************"
echo "           Script created by: Aqmar"   
echo "************************************************"

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

# Function to check if sudo is available
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        print_error "This script requires sudo privileges. Please ensure your user has sudo access."
        exit 1
    fi
}

# Function to check if running on OpenWrt
check_openwrt() {
    # Check for UCI command first (most reliable indicator)
    if ! command -v uci >/dev/null 2>&1; then
        print_warning "UCI command not found. UCI configuration will be skipped."
        return 1
    fi
    
    # Check for UCI config directory
    if [ ! -d "/etc/config" ]; then
        print_warning "UCI config directory not found. UCI configuration will be skipped."
        return 1
    fi
    
    # Check for OpenWrt-specific files (multiple possible locations)
    if [ ! -f "/etc/openwrt_release" ] && [ ! -f "/etc/openwrt_version" ] && [ ! -f "/etc/fw_version" ]; then
        # Additional check: look for OpenWrt in kernel version
        if ! uname -r | grep -q "openwrt"; then
            print_warning "This system is not OpenWrt. UCI configuration will be skipped."
            return 1
        fi
    fi
    
    print_success "OpenWrt system detected with UCI support"
    return 0
}

# Function to check if services are already installed
check_existing_services() {
    print_status "Checking for existing installations..."
    
    local services_installed=()
    local services_missing=()
    
    # Check Docker
    if command -v docker >/dev/null 2>&1 && sudo systemctl is-active --quiet docker; then
        services_installed+=("Docker")
        print_success "✓ Docker is already installed and running"
    else
        services_missing+=("Docker")
        print_warning "✗ Docker is not installed or not running"
    fi
    
    # Check Node-RED
    if command -v node-red >/dev/null 2>&1 && sudo systemctl is-active --quiet nodered; then
        services_installed+=("Node-RED")
        print_success "✓ Node-RED is already installed and running"
    else
        services_missing+=("Node-RED")
        print_warning "✗ Node-RED is not installed or not running"
    fi
    
    # Check Tailscale
    if command -v tailscale >/dev/null 2>&1 && sudo systemctl is-active --quiet tailscaled; then
        services_installed+=("Tailscale")
        print_success "✓ Tailscale is already installed and running"
    else
        services_missing+=("Tailscale")
        print_warning "✗ Tailscale is not installed or not running"
    fi
    
    # Check Docker containers (with permission handling)
    local containers_running=0
    if command -v docker >/dev/null 2>&1; then
        # Check if user has Docker permissions by testing a simple command
        if sudo docker version >/dev/null 2>&1; then
            # User has Docker permissions, check containers
            if sudo docker ps --format "{{.Names}}" 2>/dev/null | grep -q portainer; then
                services_installed+=("Portainer")
                print_success "✓ Portainer container is already running"
                containers_running=$((containers_running + 1))
            else
                services_missing+=("Portainer")
                print_warning "✗ Portainer container is not running"
            fi
            
            if sudo docker ps --format "{{.Names}}" 2>/dev/null | grep -q restreamer; then
                services_installed+=("Restreamer")
                print_success "✓ Restreamer container is already running"
                containers_running=$((containers_running + 1))
            else
                services_missing+=("Restreamer")
                print_warning "✗ Restreamer container is not running"
            fi
        else
            # Docker permission issue - assume containers need to be started
            services_missing+=("Portainer")
            services_missing+=("Restreamer")
            print_warning "✗ Docker permission issue - containers will be started during installation"
        fi
    fi
    
    # Summary
    echo
    print_status "=== INSTALLATION STATUS SUMMARY ==="
    if [ ${#services_installed[@]} -gt 0 ]; then
        print_success "Already installed: ${services_installed[*]}"
    fi
    
    if [ ${#services_missing[@]} -gt 0 ]; then
        print_warning "Need installation: ${services_missing[*]}"
    fi
    
    # Return status
    if [ ${#services_missing[@]} -eq 0 ]; then
        print_success "All services are already installed and running!"
        return 0  # All services installed
    else
        print_status "Some services need to be installed or started"
        return 1  # Some services missing
    fi
}

# Function to get user input with default
get_user_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " -r input
        eval "$var_name=\"\${input:-$default}\""
    else
        read -p "$prompt: " -r input
        eval "$var_name=\"$input\""
    fi
}

# Function to validate IP address
validate_ip() {
    local ip="$1"
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        local IFS='.'
        local -a ip_parts=($ip)
        for part in "${ip_parts[@]}"; do
            if ((part > 255)); then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# Function to get UCI configuration from user
get_uci_configuration() {
    print_section "UCI CONFIGURATION SETUP"
    print_status "This will configure your OpenWrt system with custom settings."
    echo
    
    # Get hostname
    get_user_input "Enter hostname" "router" "TARGET_HOSTNAME"
    
    # Set default values for other settings (not prompted)
    TARGET_LAN_IP="192.168.14.1"
    TARGET_WIFI_SSID="$TARGET_HOSTNAME"
    TARGET_WIFI_PASSWORD="1qaz2wsx"
    TARGET_WIFI_CHANNEL="10"
    TARGET_APN="Max4g"
    
    # Display summary
    echo
    print_section "CONFIGURATION SUMMARY"
    print_status "Hostname: $TARGET_HOSTNAME"
    print_status "WiFi SSID: $TARGET_WIFI_SSID"
    print_status "Note: Network settings will not be applied via UCI"
    echo
    
    # Confirmation
    read -p "Do you want to apply this configuration? (y/N): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        print_warning "UCI configuration cancelled."
        return 1
    fi
}

# Function to backup UCI configuration
backup_uci_config() {
    print_status "Backing up current UCI configuration..."
    
    local backup_dir="/home/$USER/uci-backup-$(date +%Y%m%d_%H%M%S)"
    
    # Try to create backup directory in user home, fallback to /tmp if needed
    if ! mkdir -p "$backup_dir" 2>/dev/null; then
        print_warning "Cannot create backup in home directory, using /tmp instead"
        backup_dir="/tmp/uci-backup-$(date +%Y%m%d_%H%M%S)"
        sudo mkdir -p "$backup_dir"
    fi
    
    # Backup all UCI configs
    for config in /etc/config/*; do
        if [ -f "$config" ]; then
            sudo cp "$config" "$backup_dir/"
        fi
    done
    
    print_success "UCI configuration backed up to: $backup_dir"
}

# Function to configure UCI system settings
configure_uci_system() {
    print_status "Configuring UCI system settings..."
    
    sudo uci set system.system.hostname="$TARGET_HOSTNAME"
    sudo uci set system.system.timezone="$TARGET_TIMEZONE"
    sudo uci set system.system.zonename="$TARGET_ZONENAME"
    sudo uci set system.system.model="$TARGET_MODEL"
    sudo uci set system.system.enable_212='1'
    sudo uci set system.system.dual_sim='0'
    sudo uci set system.system.sms_password='admin'
    
    # Configure NTP servers
    sudo uci delete system.ntp.server 2>/dev/null || true
    sudo uci add_list system.ntp.server='0.openwrt.pool.ntp.org'
    sudo uci add_list system.ntp.server='1.openwrt.pool.ntp.org'
    sudo uci add_list system.ntp.server='2.openwrt.pool.ntp.org'
    sudo uci add_list system.ntp.server='3.openwrt.pool.ntp.org'
    
    # Configure access settings
    sudo uci set system.access.enable_telnet='1'
    sudo uci set system.access.enable_ssh='0'
    
    sudo uci commit system
    print_success "UCI system configuration completed"
}

# Function to configure UCI password
configure_uci_password() {
    print_status "Configuring UCI admin password..."
    
    # Set admin password using UCI
    sudo uci set system.system.password='1qaz2wsx'
    
    # Alternative method using passwd command for admin user
    echo "admin:1qaz2wsx" | sudo chpasswd 2>/dev/null || {
        print_warning "Could not set admin password using chpasswd, trying alternative method..."
        # Use UCI to set password hash
        PASSWORD_HASH=$(echo -n "1qaz2wsx" | openssl passwd -1 -stdin 2>/dev/null || echo "")
        if [ -n "$PASSWORD_HASH" ]; then
            sudo uci set system.system.password="$PASSWORD_HASH"
            print_success "Admin password hash set via UCI"
        else
            print_warning "Could not generate password hash, admin password may need to be set manually"
        fi
    }
    
    # Commit UCI changes
    sudo uci commit system
    
    print_success "UCI admin password configuration completed"
    print_status "Username: admin"
    print_status "Password: 1qaz2wsx"
}


# Function to restart UCI services
restart_uci_services() {
    print_status "Restarting UCI services..."
    
    # Try multiple methods to reload network service with complete error suppression
    local network_reloaded=false
    
    # Method 1: Direct init.d script
    if sudo /etc/init.d/network reload >/dev/null 2>&1; then
        print_success "Network service reloaded successfully"
        network_reloaded=true
    else
        # Method 2: Service command
        if sudo service network reload >/dev/null 2>&1; then
            print_success "Network service reloaded via service command"
            network_reloaded=true
        else
            # Method 3: Systemctl
            if sudo systemctl reload network >/dev/null 2>&1; then
                print_success "Network service reloaded via systemctl"
                network_reloaded=true
            else
                # Method 4: Try restart instead of reload
                if sudo /etc/init.d/network restart >/dev/null 2>&1; then
                    print_success "Network service restarted (reload failed)"
                    network_reloaded=true
                else
                    # Method 5: Try wifi reload as last resort
                    if sudo wifi reload >/dev/null 2>&1; then
                        print_success "Wireless service reloaded (network reload failed)"
                        network_reloaded=true
                    else
                        print_warning "Network service reload failed, but UCI changes are committed"
                        print_status "Network configuration will take effect on next reboot"
                    fi
                fi
            fi
        fi
    fi
    
    if [ "$network_reloaded" = true ]; then
        print_success "UCI services restart completed"
        # Brief delay to allow network changes to take effect
        sleep 2
    else
        print_warning "UCI services restart completed with warnings"
        print_status "Some network changes may require a reboot to take effect"
        # Longer delay if network reload failed
        sleep 5
    fi
}




# Function to detect system architecture
detect_architecture() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64)
            RESTREAMER_IMAGE="datarhei/restreamer:latest"
            print_status "Detected x86_64 architecture"
            ;;
        aarch64|arm64)
            # Check if multi-arch image is available, fallback to specific ARM image
            if docker manifest inspect datarhei/restreamer:latest >/dev/null 2>&1; then
                RESTREAMER_IMAGE="datarhei/restreamer:latest"
                print_status "Using multi-arch image for ARM64"
            else
                RESTREAMER_IMAGE="datarhei/restreamer:arm64"
                print_status "Using ARM64-specific image"
            fi
            ;;
        armv7l|armhf)
            # ARMv7 typically needs 32-bit ARM image
            RESTREAMER_IMAGE="datarhei/restreamer:armhf"
            print_status "Detected ARMv7 architecture - using ARMhf image"
            ;;
        armv6l)
            # Raspberry Pi Zero and similar
            RESTREAMER_IMAGE="datarhei/restreamer:armhf"
            print_warning "ARMv6 detected - using ARMhf image (may have performance limitations)"
            ;;
        *)
            print_warning "Unknown architecture: $ARCH. Attempting to use multi-arch image."
            RESTREAMER_IMAGE="datarhei/restreamer:latest"
            ;;
    esac
    
    print_status "Detected architecture: $ARCH"
    print_status "Selected Restreamer image: $RESTREAMER_IMAGE"
    
    # Validate image availability
    print_status "Validating Restreamer image availability..."
    if ! docker manifest inspect "$RESTREAMER_IMAGE" >/dev/null 2>&1; then
        print_warning "Selected image may not be available. Will attempt to pull during installation."
    else
        print_success "Restreamer image is available in registry"
    fi
}

# Function to run pre-deployment system preparation
pre_deployment_preparation() {
    print_status "Running hardened apt/dpkg repair and dependencies install..."
    
    # Fix DNS resolution early to prevent issues during package installation
    fix_dns_resolution
    
    # Fix package conflicts and install extra system deps before deployment
    local fix_and_prepare_cmd=(
        "export DEBIAN_FRONTEND=noninteractive"
        "sudo dpkg --configure -a || true"
        "sudo apt-get install -f -y || true"
        "sudo apt-get clean"
        "sudo apt-get update -y"
        # Fix dnsmasq if broken
        "(dpkg -l | grep -q dnsmasq && sudo apt-get install --reinstall -y dnsmasq || true)"
        # Ensure build deps for Node-RED sqlite node
        "sudo apt-get install -y libsqlite3-dev sqlite3 build-essential"
    )
    
    # Execute the preparation commands
    for cmd in "${fix_and_prepare_cmd[@]}"; do
        print_status "Executing: $cmd"
        if eval "$cmd"; then
            print_success "✓ Command completed successfully"
        else
            print_warning "⚠ Command had issues, continuing anyway"
        fi
    done
    
    print_success "Pre-deployment system preparation completed"
}

# Function to update system
update_system() {
    print_status "Updating system packages..."
    
    # Set non-interactive mode to prevent debconf dialogs
    export DEBIAN_FRONTEND=noninteractive
    
    # Fix any broken packages first - this is critical before installing anything
    print_status "Fixing broken packages..."
    sudo dpkg --configure -a 2>/dev/null || true
    sudo apt-get -f install -y 2>/dev/null || true
    
    # Repair dnsmasq if stuck half-installed
    print_status "Checking and repairing dnsmasq installation..."
    if dpkg -l | grep -q "^iU.*dnsmasq"; then
        print_warning "dnsmasq is in half-installed state, repairing..."
        sudo apt-get --fix-broken install -y dnsmasq 2>/dev/null || true
    fi
    
    # Configure dnsmasq non-interactively to prevent prompts
    echo "dnsmasq dnsmasq/confdir string /etc/dnsmasq.d" | sudo debconf-set-selections
    echo "dnsmasq dnsmasq/run_daemon boolean true" | sudo debconf-set-selections
    echo "dnsmasq dnsmasq/run_daemon seen true" | sudo debconf-set-selections
    
    # Install essential tools first (including curl)
    print_status "Installing essential tools..."
    DEBIAN_FRONTEND=noninteractive sudo apt install -y curl wget gnupg lsb-release software-properties-common
    
    # Update package lists
    print_status "Updating package lists..."
    DEBIAN_FRONTEND=noninteractive sudo apt update -y
    
    print_success "System packages updated"
}

# Function to install dependencies
install_dependencies() {
    print_status "Installing required dependencies..."
    
    # Note: System update and package fixing already done in update_system()
    # dnsmasq configuration already set in update_system()
    
    # Check if Docker is already installed and running
    if command -v docker >/dev/null 2>&1 && sudo systemctl is-active --quiet docker; then
        print_success "Docker is already installed and running, skipping Docker installation"
        DOCKER_ALREADY_INSTALLED=true
    elif command -v docker >/dev/null 2>&1; then
        print_warning "Docker is installed but not running, will start Docker service"
        DOCKER_ALREADY_INSTALLED=true
    else
        print_status "Docker not found, will install Docker"
        DOCKER_ALREADY_INSTALLED=false
    fi
    
    # Prepare package lists
    # Note: libsqlite3-dev and sqlite3 are required for Node-RED SQLite node compilation
    local basic_packages=(
        apt-transport-https
        ca-certificates
        curl
        gnupg
        lsb-release
        software-properties-common
        wget
        nano
        htop
        build-essential
        python3
        libsqlite3-dev
        sqlite3
    )
    
    local docker_packages=(
        docker-ce
        docker-ce-cli
        containerd.io
        docker-buildx-plugin
        docker-compose-plugin
    )
    
    # Install Docker only if not already installed
    if [ "$DOCKER_ALREADY_INSTALLED" = false ]; then
        echo "Installing Docker..."
        
        # Add Docker's official GPG key
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
        
        # Add Docker repository
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Update package index after adding Docker repository
        print_status "Updating package index for Docker repository..."
        DEBIAN_FRONTEND=noninteractive sudo apt update
        
        # Combine all packages into single installation
        print_status "Installing all dependencies and Docker packages in one go..."
        DEBIAN_FRONTEND=noninteractive sudo apt install -y \
            "${basic_packages[@]}" \
            "${docker_packages[@]}"
        echo "All packages installed successfully"
    else
        echo "Docker installation skipped - already present"
        # Install only basic dependencies
        print_status "Installing basic dependencies..."
        DEBIAN_FRONTEND=noninteractive sudo apt install -y \
            "${basic_packages[@]}"
        echo "Basic dependencies installed successfully"
    fi
    
    # Add current user to docker group (always do this)
    sudo usermod -aG docker $USER
    
    # Enable and start Docker service (only if not already running)
    if ! sudo systemctl is-active --quiet docker; then
        print_status "Starting Docker service..."
        sudo systemctl enable docker
        sudo systemctl start docker
        
        # Wait for Docker to fully start
        sleep 5
        
        # Check Docker status
        if sudo systemctl is-active --quiet docker; then
            print_success "Docker service is running"
        else
            print_error "Docker service failed to start"
            exit 1
        fi
    else
        print_success "Docker service is already running"
    fi
    
    print_success "All dependencies and Docker setup completed"
}

# =============================================================================
# NODE-RED INSTALLATION FUNCTIONS
# =============================================================================

# Function to install NVM
install_nvm() {
    print_status "Installing NVM (Node Version Manager)..."
    
    # Check if NVM is already installed
    if [ -s "$HOME/.nvm/nvm.sh" ]; then
        print_warning "NVM is already installed"
        return 0
    fi
    
    # Download and install NVM
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh" | bash
    
    # Wait for NVM installation to complete
    sleep 3
    
    # Source NVM for the current shell session
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    
    # Verify NVM installation
    if command -v nvm >/dev/null 2>&1; then
        print_success "NVM installed successfully"
    else
        print_error "NVM installation failed"
        exit 1
    fi
}

# Function to install Node.js
install_nodejs() {
    print_status "Installing Node.js version $NODE_VERSION..."
    
    # Ensure NVM is loaded
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    # Install and use Node.js
    nvm install $NODE_VERSION
    nvm use $NODE_VERSION
    nvm alias default $NODE_VERSION
    
    # Verify installation
    NODE_PATH=$(nvm which $NODE_VERSION)
    if [ -n "$NODE_PATH" ]; then
        print_success "Node.js $NODE_VERSION installed at: $NODE_PATH"
        NODE_DIR=$(dirname "$NODE_PATH")
        print_status "Node.js directory: $NODE_DIR"
    else
        print_error "Failed to get Node.js path"
        exit 1
    fi
}

# Function to install Node-RED
install_nodered() {
    print_status "Installing Node-RED..."
    
    # Check if Node-RED is already installed and running
    if command -v node-red >/dev/null 2>&1 && sudo systemctl is-active --quiet nodered; then
        print_success "Node-RED is already installed and running, skipping installation"
        return 0
    elif command -v node-red >/dev/null 2>&1; then
        print_warning "Node-RED is installed but not running, will start service later"
        return 0
    fi
    
    # Ensure NVM is loaded
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm use $NODE_VERSION
    
    # Install Node-RED globally
    print_status "Installing Node-RED globally..."
    npm install -g --unsafe-perm node-red
    
    # Verify installation
    if command -v node-red >/dev/null 2>&1; then
        print_success "Node-RED installed successfully"
    else
        print_error "Node-RED installation failed"
        exit 1
    fi
}

# Function to install Node-RED nodes
install_nodered_nodes() {
    print_status "Installing Node-RED nodes..."
    
    # Create .node-red directory if it doesn't exist
    mkdir -p "$NODERED_HOME/.node-red"
    cd "$NODERED_HOME/.node-red"
    
    # Get the script directory to check for local package.json
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Check if we have a local package.json with dependencies
    if [ -f "$SCRIPT_DIR/nodered_flows/package.json" ]; then
        print_status "Installing nodes from local package.json..."
        cp "$SCRIPT_DIR/nodered_flows/package.json" "$NODERED_HOME/.node-red/package.json"
        
        # Install dependencies from package.json (only Node-RED nodes, not Node-RED itself)
        print_status "Installing Node-RED nodes from package.json..."
        if npm install --production; then
            print_success "Node-RED nodes installed from package.json"
        else
            print_warning "Failed to install from package.json, installing individual packages..."
            install_individual_nodes
        fi
    else
        print_warning "No package.json found, installing individual packages..."
        install_individual_nodes
    fi
    
    print_success "Node-RED nodes installation completed"
}

# Function to install individual Node-RED nodes
install_individual_nodes() {
    print_status "Installing individual Node-RED nodes..."
    
    # Install required nodes individually with error handling
    local nodes=(
        "node-red-contrib-ffmpeg@~0.1.1"
        "node-red-contrib-queue-gate@~1.5.5"
        "node-red-node-sqlite@~1.1.0"
        "node-red-node-serialport@2.0.3"
    )
    
    for node in "${nodes[@]}"; do
        # Extract package name without version for checking
        local package_name=$(echo "$node" | cut -d'@' -f1)
        
        # Check if package is already installed
        if npm list "$package_name" >/dev/null 2>&1; then
            print_warning "$package_name is already installed, skipping..."
            continue
        fi
        
        print_status "Installing $node..."
        if npm install "$node"; then
            print_success "Successfully installed $node"
        else
            print_warning "Failed to install $node, continuing with other packages..."
        fi
    done
}

# Function to create Node-RED systemd service
create_nodered_systemd_service() {
    print_status "Setting up Node-RED systemd service..."
    
    # Get the actual Node.js path
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm use $NODE_VERSION
    NODE_PATH=$(nvm which $NODE_VERSION)
    NODE_DIR=$(dirname "$NODE_PATH")
    
    # Create systemd service file
    cat <<EOL | sudo tee /etc/systemd/system/nodered.service
[Unit]
Description=Node-RED
Documentation=http://nodered.org
After=network.target

[Service]
ExecStart=/bin/bash -c 'source $NODERED_HOME/.nvm/nvm.sh && nvm use $NODE_VERSION && node-red'
User=$NODERED_USER
Group=$NODERED_USER
WorkingDirectory=$NODERED_HOME
Restart=on-failure
Environment=NODE_RED_OPTIONS=-v
Environment=PATH=$NODE_DIR:$PATH
Environment=HOME=$NODERED_HOME
Environment=USER=$NODERED_USER
StandardOutput=journal
StandardError=journal
SyslogIdentifier=node-red

[Install]
WantedBy=multi-user.target
EOL
    
    # Set proper permissions
    sudo chown -R $NODERED_USER:$NODERED_USER "$NODERED_HOME/.nvm"
    sudo chown -R $NODERED_USER:$NODERED_USER "$NODERED_HOME/.node-red"
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    print_success "Node-RED systemd service created"
}

# Function to start and enable Node-RED
start_nodered() {
    print_status "Enabling and starting Node-RED service..."
    
    # Enable Node-RED to start on boot
    sudo systemctl enable nodered
    
    # Start Node-RED service
    sudo systemctl start nodered
    
    # Wait a moment for service to start
    sleep 5
    
    # Check status
    if sudo systemctl is-active --quiet nodered; then
        print_success "Node-RED service is running"
    else
        print_error "Node-RED service failed to start"
        print_status "Checking service status..."
        sudo systemctl status nodered --no-pager
        exit 1
    fi
}

# Function to copy flows to script directory
copy_flows_to_script() {
    print_status "Copying Node-RED flows to script directory..."
    
    # Get the script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Create nodered_flows directory in script location
    mkdir -p "$SCRIPT_DIR/nodered_flows"
    
    # Check if we're running from a local directory (has nodered_flows folder)
    if [ -f "$SCRIPT_DIR/nodered_flows/flows.json" ]; then
        print_status "Found local flows in script directory"
        print_success "Using local flows from repository"
    else
        # Download flows from repository
        print_status "Downloading flows from repository..."
        sleep 2  # Brief delay before download
        
        # Try multiple repository URLs for better reliability
        local flows_downloaded=false
        local repo_urls=(
            "https://raw.githubusercontent.com/Loranet-Technologies/bivicom-radar/main/nodered_flows/flows.json"
            "https://github.com/Loranet-Technologies/bivicom-radar/raw/main/nodered_flows/flows.json"
        )
        
        for url in "${repo_urls[@]}"; do
            print_status "Trying to download from: $url"
            if curl -sSL --connect-timeout 10 --max-time 30 "$url" -o "$SCRIPT_DIR/nodered_flows/flows.json" 2>/dev/null; then
                # Validate downloaded file
                if [ -s "$SCRIPT_DIR/nodered_flows/flows.json" ] && validate_nodered_flows "$SCRIPT_DIR/nodered_flows/flows.json" 2>/dev/null; then
                    print_success "Flows downloaded and validated from repository"
                    flows_downloaded=true
                    break
                else
                    print_warning "Downloaded flows file is invalid, trying next URL..."
                    rm -f "$SCRIPT_DIR/nodered_flows/flows.json"
                fi
            else
                print_warning "Failed to download from: $url"
            fi
        done
        
        if [ "$flows_downloaded" = false ]; then
            print_warning "Failed to download flows from repository, trying local server flows..."
            # Fallback: Copy flows from current server if they exist
            local fallback_paths=(
                "/home/admin/.node-red/flows.json"
                "/home/$USER/.node-red/flows.json"
                "/root/.node-red/flows.json"
            )
            
            for fallback_path in "${fallback_paths[@]}"; do
                if [ -f "$fallback_path" ] && validate_nodered_flows "$fallback_path" 2>/dev/null; then
                    cp "$fallback_path" "$SCRIPT_DIR/nodered_flows/flows.json"
                    print_success "Flows copied from local server: $fallback_path"
                    flows_downloaded=true
                    break
                fi
            done
            
            if [ "$flows_downloaded" = false ]; then
                print_warning "No valid existing flows found on this server"
            fi
        fi
        
        # Download package.json from repository
        sleep 1  # Brief delay between downloads
        local package_downloaded=false
        
        for url in "${repo_urls[@]}"; do
            local package_url="${url/flows.json/package.json}"
            print_status "Trying to download package.json from: $package_url"
            if curl -sSL --connect-timeout 10 --max-time 30 "$package_url" -o "$SCRIPT_DIR/nodered_flows/package.json" 2>/dev/null; then
                # Validate downloaded package.json
                if [ -s "$SCRIPT_DIR/nodered_flows/package.json" ] && python3 -c "import json; json.load(open('$SCRIPT_DIR/nodered_flows/package.json'))" 2>/dev/null; then
                    print_success "Package.json downloaded and validated from repository"
                    package_downloaded=true
                    break
                else
                    print_warning "Downloaded package.json is invalid, trying next URL..."
                    rm -f "$SCRIPT_DIR/nodered_flows/package.json"
                fi
            else
                print_warning "Failed to download package.json from: $package_url"
            fi
        done
        
        if [ "$package_downloaded" = false ]; then
            print_warning "Failed to download package.json from repository, trying local server..."
            # Fallback: Copy package.json from current server if it exists
            for fallback_path in "${fallback_paths[@]}"; do
                local package_fallback="${fallback_path/flows.json/package.json}"
                if [ -f "$package_fallback" ] && python3 -c "import json; json.load(open('$package_fallback'))" 2>/dev/null; then
                    cp "$package_fallback" "$SCRIPT_DIR/nodered_flows/package.json"
                    print_success "Package.json copied from local server: $package_fallback"
                    package_downloaded=true
                    break
                fi
            done
            
            if [ "$package_downloaded" = false ]; then
                print_warning "No valid package.json found, will use default dependencies"
            fi
        fi
    fi
}

# Function to backup existing Node-RED flows
backup_nodered_flows() {
    print_status "Backing up existing Node-RED flows..."
    
    if [ -f "$NODERED_HOME/.node-red/flows.json" ]; then
        # Create backup with timestamp
        BACKUP_FILE="$NODERED_HOME/.node-red/flows_$(date +%Y%m%d_%H%M%S).json"
        cp "$NODERED_HOME/.node-red/flows.json" "$BACKUP_FILE"
        print_success "Flows backed up to: $BACKUP_FILE"
        
        # Also create a standard backup
        cp "$NODERED_HOME/.node-red/flows.json" "$NODERED_HOME/.node-red/.flows.json.backup"
        print_success "Standard backup created: .flows.json.backup"
    else
        print_warning "No existing flows.json found to backup"
    fi
}

# Function to validate Node-RED flows
validate_nodered_flows() {
    local flows_file="$1"
    
    if [ ! -f "$flows_file" ]; then
        print_error "Flows file not found: $flows_file"
        return 1
    fi
    
    # Check if file is too small (likely empty or corrupted)
    local file_size=$(stat -f%z "$flows_file" 2>/dev/null || stat -c%s "$flows_file" 2>/dev/null || echo "0")
    if [ "$file_size" -lt 1000 ]; then
        print_warning "Flows file is very small ($file_size bytes), may be empty or corrupted"
        print_status "File path: $flows_file"
        print_status "File exists: $([ -f "$flows_file" ] && echo "yes" || echo "no")"
        return 1
    fi
    
    # Try to parse JSON
    if ! python3 -c "import json; json.load(open('$flows_file'))" 2>/dev/null; then
        print_error "Flows file contains invalid JSON"
        return 1
    fi
    
    # Check for flow tabs
    local tab_count=$(python3 -c "
import json
try:
    with open('$flows_file', 'r') as f:
        flows = json.load(f)
    tabs = [flow for flow in flows if flow.get('type') == 'tab']
    print(len(tabs))
except:
    print(0)
" 2>/dev/null || echo "0")
    
    if [ "$tab_count" -eq 0 ]; then
        print_warning "No flow tabs found in flows file"
        return 1
    fi
    
    print_success "Flows validation passed: $tab_count tabs found"
    return 0
}

# Function to restore flows from backup
restore_nodered_flows() {
    print_status "Attempting to restore Node-RED flows from backup..."
    
    # Stop Node-RED
    sudo systemctl stop nodered 2>/dev/null || true
    
    # Look for backup files
    local backup_files=(
        "$NODERED_HOME/.node-red/.flows.json.backup"
        "$NODERED_HOME/.node-red/flows_$(date +%Y%m%d)*.json"
        "$NODERED_HOME/.node-red/flows_*.json"
    )
    
    local restored=false
    for backup_pattern in "${backup_files[@]}"; do
        for backup_file in $backup_pattern; do
            if [ -f "$backup_file" ]; then
                # Check file size first to avoid validating tiny files
                local backup_size=$(stat -f%z "$backup_file" 2>/dev/null || stat -c%s "$backup_file" 2>/dev/null || echo "0")
                if [ "$backup_size" -gt 1000 ] && validate_nodered_flows "$backup_file"; then
                    print_status "Restoring flows from: $(basename "$backup_file")"
                    cp "$backup_file" "$NODERED_HOME/.node-red/flows.json"
                    sudo chown $NODERED_USER:$NODERED_USER "$NODERED_HOME/.node-red/flows.json"
                    restored=true
                    break 2
                else
                    print_warning "Skipping small/corrupted backup file: $(basename "$backup_file") ($backup_size bytes)"
                fi
            fi
        done
    done
    
    if [ "$restored" = true ]; then
        print_success "Flows restored from backup"
        # Restart Node-RED
        sudo systemctl start nodered
        sleep 5
        
        if sudo systemctl is-active --quiet nodered; then
            print_success "Node-RED restarted successfully"
            return 0
        else
            print_error "Failed to restart Node-RED"
            return 1
        fi
    else
        print_warning "No valid backup found, creating default flows"
        # Create a minimal default flow
        cat > "$NODERED_HOME/.node-red/flows.json" << 'EOF'
[
    {
        "id": "default-flow",
        "type": "tab",
        "label": "Default Flow",
        "disabled": false,
        "info": "Default flow created by installation script"
    },
    {
        "id": "inject-node",
        "type": "inject",
        "z": "default-flow",
        "name": "Hello World",
        "props": [{"p": "payload"}],
        "repeat": "",
        "crontab": "",
        "once": false,
        "onceDelay": 0.1,
        "topic": "",
        "payload": "Hello World",
        "payloadType": "str",
        "x": 200,
        "y": 100,
        "wires": [["debug-node"]]
    },
    {
        "id": "debug-node",
        "type": "debug",
        "z": "default-flow",
        "name": "Debug Output",
        "active": true,
        "tosidebar": true,
        "console": false,
        "tostatus": false,
        "complete": "false",
        "statusVal": "",
        "statusType": "auto",
        "x": 400,
        "y": 100,
        "wires": []
    }
]
EOF
        sudo chown $NODERED_USER:$NODERED_USER "$NODERED_HOME/.node-red/flows.json"
        print_success "Default flows created"
        return 0
    fi
}

# Function to download and import Node-RED flows from repository (DEFAULT BEHAVIOR)
import_flows() {
    print_status "Downloading and importing Node-RED flows from repository..."
    
    # Configuration
    local REPO_URL="https://github.com/Loranet-Technologies/bivicom-radar"
    local BASE_URL="https://raw.githubusercontent.com/Loranet-Technologies/bivicom-radar/main/nodered_flows"
    local DOWNLOAD_DIR="/home/$USER/nodered_flows"
    local BACKUP_DIR="/home/$USER/nodered_flows_backup"
    
    print_status "Repository: $REPO_URL"
    print_status "Download directory: $DOWNLOAD_DIR"
    
    # Create backup of existing flows
    print_status "Creating backup of existing flows..."
    if [ -d "$NODERED_HOME/.node-red" ]; then
        mkdir -p "$BACKUP_DIR"
        local timestamp=$(date +%Y%m%d_%H%M%S)
        
        # Backup flows.json if it exists
        if [ -f "$NODERED_HOME/.node-red/flows.json" ]; then
            cp "$NODERED_HOME/.node-red/flows.json" "$BACKUP_DIR/flows_$timestamp.json"
            print_success "Backed up flows.json to $BACKUP_DIR/flows_$timestamp.json"
        fi
        
        # Backup flows_cred.json if it exists
        if [ -f "$NODERED_HOME/.node-red/flows_cred.json" ]; then
            cp "$NODERED_HOME/.node-red/flows_cred.json" "$BACKUP_DIR/flows_cred_$timestamp.json"
            print_success "Backed up flows_cred.json to $BACKUP_DIR/flows_cred_$timestamp.json"
        fi
        
        # Backup package.json if it exists
        if [ -f "$NODERED_HOME/.node-red/package.json" ]; then
            cp "$NODERED_HOME/.node-red/package.json" "$BACKUP_DIR/package_$timestamp.json"
            print_success "Backed up package.json to $BACKUP_DIR/package_$timestamp.json"
        fi
    else
        print_warning "Node-RED home directory not found: $NODERED_HOME/.node-red"
    fi
    
    # Create download directory and download files
    print_status "Downloading flows from repository..."
    mkdir -p "$DOWNLOAD_DIR"
    cd "$DOWNLOAD_DIR"
    
    # Download main flows.json
    print_status "Downloading flows.json..."
    if curl -fsSL "$BASE_URL/flows.json" -o flows.json; then
        print_success "✓ flows.json downloaded ($(du -h flows.json | cut -f1))"
    else
        print_error "✗ Failed to download flows.json"
        return 1
    fi
    
    # Download package.json
    print_status "Downloading package.json..."
    if curl -fsSL "$BASE_URL/package.json" -o package.json; then
        print_success "✓ package.json downloaded ($(du -h package.json | cut -f1))"
    else
        print_error "✗ Failed to download package.json"
        return 1
    fi
    
    # Download backup flows
    print_status "Downloading backup flows..."
    mkdir -p nodered_flows_backup
    
    if curl -fsSL "$BASE_URL/nodered_flows_backup/flows.json" -o nodered_flows_backup/flows.json; then
        print_success "✓ Backup flows.json downloaded"
    else
        print_warning "⚠ Failed to download backup flows.json"
    fi
    
    if curl -fsSL "$BASE_URL/nodered_flows_backup/package.json" -o nodered_flows_backup/package.json; then
        print_success "✓ Backup package.json downloaded"
    else
        print_warning "⚠ Failed to download backup package.json"
    fi
    
    # Validate downloaded files
    print_status "Validating downloaded files..."
    
    # Validate flows.json
    if [ -f "$DOWNLOAD_DIR/flows.json" ]; then
        if python3 -m json.tool "$DOWNLOAD_DIR/flows.json" > /dev/null 2>&1; then
            local flow_count=$(python3 -c "import json; data=json.load(open('$DOWNLOAD_DIR/flows.json')); print(len([item for item in data if item.get('type') == 'tab']))")
            print_success "✓ flows.json is valid JSON with $flow_count tabs"
        else
            print_error "✗ flows.json is not valid JSON"
            return 1
        fi
    else
        print_error "✗ flows.json not found"
        return 1
    fi
    
    # Validate package.json
    if [ -f "$DOWNLOAD_DIR/package.json" ]; then
        if python3 -m json.tool "$DOWNLOAD_DIR/package.json" > /dev/null 2>&1; then
            print_success "✓ package.json is valid JSON"
        else
            print_error "✗ package.json is not valid JSON"
            return 1
        fi
    else
        print_error "✗ package.json not found"
        return 1
    fi
    
    # Import flows to Node-RED
    print_status "Copying flows.json to Node-RED directory..."
    mkdir -p "$NODERED_HOME/.node-red"
    if cp "$DOWNLOAD_DIR/flows.json" "$NODERED_HOME/.node-red/flows.json"; then
        print_success "✓ flows.json copied to $NODERED_HOME/.node-red"
    else
        print_error "✗ Failed to copy flows.json"
        return 1
    fi
    
    # Set proper permissions
    sudo chown -R "$USER:$USER" "$NODERED_HOME/.node-red"
    sudo chmod 644 "$NODERED_HOME/.node-red/flows.json"
    
    # Enable and start Node-RED
    print_status "Enabling and starting Node-RED service..."
    sudo systemctl enable nodered
    sudo systemctl start nodered
    
    # Wait for service to start
    sleep 5
    
    if sudo systemctl is-active --quiet nodered; then
        print_success "✓ Node-RED is running with new flows"
    else
        print_error "✗ Node-RED failed to start after restart"
        return 1
    fi
    
    # Final verification
    if [ -f "$NODERED_HOME/.node-red/flows.json" ]; then
        local flow_size=$(du -h "$NODERED_HOME/.node-red/flows.json" | cut -f1)
        local flow_count=$(python3 -c "import json; data=json.load(open('$NODERED_HOME/.node-red/flows.json')); print(len([item for item in data if item.get('type') == 'tab']))")
        print_success "✓ Node-RED flows loaded: $flow_count tabs ($flow_size)"
    else
        print_error "✗ Node-RED flows not found"
        return 1
    fi
    
    print_success "Node-RED flows downloaded and imported successfully!"
    print_status "Flows Location: $NODERED_HOME/.node-red/flows.json"
    print_status "Download Location: $DOWNLOAD_DIR"
    print_status "Backup Location: $BACKUP_DIR"
}

# Function to install Tailscale
install_tailscale() {
    print_status "Installing Tailscale..."
    
    # Check if Tailscale is already installed and running
    if command -v tailscale >/dev/null 2>&1 && sudo systemctl is-active --quiet tailscaled; then
        print_success "Tailscale is already installed and running, skipping installation"
        return 0
    elif command -v tailscale >/dev/null 2>&1; then
        print_warning "Tailscale is installed but not running, will start service"
        sudo systemctl enable tailscaled
        sudo systemctl start tailscaled
        sleep 3
        if sudo systemctl is-active --quiet tailscaled; then
            print_success "Tailscale service started successfully"
        else
            print_warning "Tailscale service failed to start"
        fi
        return 0
    fi
    
    # Install Tailscale using official method
    curl -fsSL https://tailscale.com/install.sh | sh
    
    # Wait for installation to complete
    sleep 5
    
    # Enable and start Tailscale
    sudo systemctl enable tailscaled
    sudo systemctl start tailscaled
    
    # Wait for service to start
    sleep 3
    
    # Verify Tailscale installation
    if sudo systemctl is-active --quiet tailscaled; then
        print_success "Tailscale installed and running"
        print_status "Run 'sudo tailscale up' to connect to your Tailscale network"
    else
        print_warning "Tailscale service not running, but installation completed"
        print_status "You may need to run 'sudo tailscale up' manually"
    fi
}

# =============================================================================
# DOCKER INSTALLATION FUNCTIONS
# =============================================================================


# Function to fix DNS resolution issues
fix_dns_resolution() {
    print_status "Checking and fixing DNS resolution..."
    
    # Test if we can resolve registry-1.docker.io
    if ! timeout 10 bash -c "</dev/tcp/registry-1.docker.io/443" 2>/dev/null; then
        print_warning "DNS resolution issue detected - fixing..."
        
        # Stop systemd-resolved to prevent conflicts
        sudo systemctl stop systemd-resolved 2>/dev/null || true
        
        # Configure static DNS servers
        print_status "Configuring static DNS servers..."
        echo 'nameserver 8.8.8.8' | sudo tee /etc/resolv.conf >/dev/null
        echo 'nameserver 1.1.1.1' | sudo tee -a /etc/resolv.conf >/dev/null
        echo 'nameserver 8.8.4.4' | sudo tee -a /etc/resolv.conf >/dev/null
        
        # Test connectivity
        if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
            print_success "DNS resolution fixed - external connectivity confirmed"
        else
            print_warning "DNS fix applied but external connectivity still limited"
        fi
    else
        print_success "DNS resolution working correctly"
    fi
}

# Function to create directories
create_docker_directories() {
    print_status "Creating required directories..."
    
    # Create portainer directory with proper permissions
    print_status "Creating Portainer directory: $PORTAINER_DATA_DIR"
    sudo mkdir -p $PORTAINER_DATA_DIR
    sudo chown $USER:$USER $PORTAINER_DATA_DIR
    sudo chmod 755 $PORTAINER_DATA_DIR
    
    # Create restreamer config directory
    print_status "Creating Restreamer config directory: $RESTREAMER_CONFIG_DIR"
    sudo mkdir -p $RESTREAMER_CONFIG_DIR
    sudo chown $USER:$USER $RESTREAMER_CONFIG_DIR
    sudo chmod 755 $RESTREAMER_CONFIG_DIR
    
    # Create restreamer data directory (legacy support)
    print_status "Creating Restreamer data directory: $RESTREAMER_DATA_DIR"
    sudo mkdir -p $RESTREAMER_DATA_DIR
    sudo chown $USER:$USER $RESTREAMER_DATA_DIR
    sudo chmod 755 $RESTREAMER_DATA_DIR
    
    # Verify directory creation
    for dir in "$PORTAINER_DATA_DIR" "$RESTREAMER_CONFIG_DIR" "$RESTREAMER_DATA_DIR"; do
        if [ ! -d "$dir" ]; then
            print_error "Failed to create directory: $dir"
            return 1
        fi
        if [ ! -w "$dir" ]; then
            print_error "Directory not writable: $dir"
            return 1
        fi
        print_success "✓ Directory ready: $dir"
    done
    
    print_success "All Docker directories created and configured"
}

# Function to create Portainer Docker Compose file
create_portainer_compose() {
    print_status "Creating Portainer Docker Compose configuration..."
    
    cat > $PORTAINER_DATA_DIR/docker-compose.yml << EOF
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    environment:
      - TZ=$TIMEZONE
    ports:
      - "9000:9000"   # Web UI
      - "9443:9443"   # HTTPS
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro

volumes:
  portainer_data:
EOF
    
    print_success "Portainer Docker Compose file created"
}

# Function to create Restreamer Docker Compose file
create_restreamer_compose() {
    print_status "Creating Restreamer Docker Compose configuration..."
    
    cat > $RESTREAMER_CONFIG_DIR/docker-compose.yml << EOF
version: '3.8'

services:
  restreamer:
    image: $RESTREAMER_IMAGE
    container_name: restreamer
    restart: unless-stopped
    environment:
      - RS_USERNAME=$RESTREAMER_USERNAME
      - RS_PASSWORD=$RESTREAMER_PASSWORD
      - TZ=$TIMEZONE
      - RS_LOG_LEVEL=info
      - RS_LOG_TOPICS=
    ports:
      - "8080:8080"   # HTTP API/UI
      - "8181:8181"   # HTTPS API/UI
      - "1935:1935"   # RTMP
      - "1936:1936"   # RTMPS
      - "6000:6000/udp"   # SRT
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
      - restreamer_data:/core/data
      - restreamer_config:/core/config
      - restreamer_cache:/tmp/hls
    networks:
      - restreamer_network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/api/v3/skills", "||", "exit", "1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M

volumes:
  restreamer_data:
    driver: local
  restreamer_config:
    driver: local
  restreamer_cache:
    driver: local

networks:
  restreamer_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
EOF
    
    print_success "Restreamer Docker Compose file created with enhanced configuration"
}

# Function to start Docker services
start_docker_services() {
    print_status "Starting Docker services..."
    
    # Fix DNS resolution issues before starting containers
    fix_dns_resolution
    
    # Check if containers are already running (with permission handling)
    local portainer_running=false
    local restreamer_running=false
    
    if sudo docker version >/dev/null 2>&1; then
        if sudo docker ps --format "{{.Names}}" 2>/dev/null | grep -q portainer; then
            portainer_running=true
            print_success "Portainer container is already running"
        fi
        
        if sudo docker ps --format "{{.Names}}" 2>/dev/null | grep -q restreamer; then
            restreamer_running=true
            print_success "Restreamer container is already running"
        fi
    else
        print_warning "Docker permission issue - will attempt to start containers"
    fi
    
    # Only start containers that are not already running
    if [ "$portainer_running" = false ] || [ "$restreamer_running" = false ]; then
        print_status "Starting Docker containers..."
        
        # Start Portainer (if not running)
        if ! sudo docker ps --format "{{.Names}}" | grep -q portainer; then
            print_status "Starting Portainer container..."
            cd $PORTAINER_DATA_DIR
            
            # Clean up any existing failed container
            sudo docker rm -f portainer 2>/dev/null || true
            
            if sudo docker compose up -d; then
                print_success "✓ Portainer started successfully"
                
                # Wait for Portainer to be fully ready
                print_status "Waiting for Portainer to be fully ready..."
                local portainer_ready=false
                local wait_attempts=0
                local max_wait_attempts=24  # 2 minutes total
                
                while [ $wait_attempts -lt $max_wait_attempts ] && [ "$portainer_ready" = false ]; do
                    # Check if container is running and healthy
                    if sudo docker ps --format "{{.Names}}" | grep -q portainer; then
                        # Check if Portainer API is responding
                        if curl -f -s http://localhost:9000/api/status >/dev/null 2>&1; then
                            print_success "✓ Portainer is fully ready and API is responding"
                            portainer_ready=true
                        else
                            # Check container health if available
                            container_status=$(sudo docker inspect --format='{{.State.Status}}' portainer 2>/dev/null || echo "unknown")
                            if [ "$container_status" = "running" ]; then
                                # Just check if ports are accessible
                                if netstat -tuln 2>/dev/null | grep -q ':9000 ' || ss -tuln 2>/dev/null | grep -q ':9000 '; then
                                    print_success "✓ Portainer is ready (port 9000 accessible)"
                                    portainer_ready=true
                                fi
                            fi
                        fi
                    fi
                    
                    if [ "$portainer_ready" = false ]; then
                        sleep 5
                        wait_attempts=$((wait_attempts + 1))
                        if [ $((wait_attempts % 6)) -eq 0 ]; then  # Every 30 seconds
                            print_status "Still waiting for Portainer to be ready... ($((wait_attempts * 5))s elapsed)"
                        fi
                    fi
                done
                
                if [ "$portainer_ready" = false ]; then
                    print_warning "Portainer may not be fully ready yet, but proceeding with installation"
                    print_status "You can check Portainer status with: sudo docker logs portainer"
                fi
                
                # Additional delay to ensure Portainer is stable before starting next service
                print_status "Ensuring Portainer is stable before proceeding..."
                sleep 10
                
            else
                print_error "✗ Failed to start Portainer"
                print_status "Checking Portainer logs..."
                sudo docker logs portainer --tail 20 2>/dev/null || echo "No logs available"
                print_status "Checking Docker Compose logs..."
                sudo docker compose logs --tail 10 2>/dev/null || echo "No compose logs available"
                
                # Don't proceed with Restreamer if Portainer failed
                print_error "Portainer startup failed. Skipping Restreamer to avoid conflicts."
                return 1
            fi
        else
            print_status "Portainer is already running - ensuring it's ready..."
            sleep 5  # Brief delay even if already running
        fi
        
        # Start Restreamer (if not running) - Only after Portainer is ready
        print_section "STARTING RESTREAMER SERVICE"
        print_status "Portainer startup completed. Now starting Restreamer..."
        
        if ! sudo docker ps --format "{{.Names}}" | grep -q restreamer; then
            print_status "Starting Restreamer container..."
            cd $RESTREAMER_CONFIG_DIR
            
            # Pre-flight checks for Restreamer
            print_status "Running pre-flight checks for Restreamer..."
            
            # Check if compose file exists
            if [ ! -f "docker-compose.yml" ]; then
                print_error "docker-compose.yml not found in $RESTREAMER_CONFIG_DIR"
                return 1
            fi
            
            # Validate compose file
            if ! sudo docker compose config >/dev/null 2>&1; then
                print_error "Invalid docker-compose.yml configuration"
                sudo docker compose config
                return 1
            fi
            print_success "✓ Docker Compose configuration is valid"
            
            # Check and create volumes if needed
            print_status "Ensuring Docker volumes exist..."
            for volume in restreamer_data restreamer_config restreamer_cache; do
                if ! sudo docker volume ls | grep -q "$volume"; then
                    print_status "Creating volume: $volume"
                    sudo docker volume create "$volume" || print_warning "Failed to create volume $volume"
                fi
            done
            
            # Check if network exists
            if ! sudo docker network ls | grep -q restreamer_network; then
                print_status "Creating restreamer network..."
                sudo docker network create restreamer_network --driver bridge --subnet 172.20.0.0/16 2>/dev/null || true
            fi
            
            # Try to pull image first
            print_status "Pulling Restreamer image: $RESTREAMER_IMAGE"
            if sudo docker pull $RESTREAMER_IMAGE; then
                print_success "✓ Restreamer image pulled successfully"
            else
                print_warning "Failed to pull image, will attempt to start anyway"
            fi
            
            # Clean up any existing failed containers
            sudo docker rm -f restreamer 2>/dev/null || true
            
            # Attempt to start Restreamer with retry logic
            local max_attempts=3
            local attempt=1
            local started=false
            
            while [ $attempt -le $max_attempts ] && [ "$started" = false ]; do
                print_status "Attempt $attempt/$max_attempts: Starting Restreamer container..."
                
                # Start with detailed output on final attempt
                if [ $attempt -eq $max_attempts ]; then
                    sudo docker compose up -d --verbose
                else
                    sudo docker compose up -d 2>/dev/null
                fi
                
                # Wait for container to initialize
                sleep 5
                
                # Check if container started successfully
                if sudo docker ps --format "{{.Names}}" | grep -q restreamer; then
                    print_success "✓ Restreamer started successfully on attempt $attempt"
                    started=true
                    
                    # Wait for health check
                    print_status "Waiting for Restreamer health check..."
                    local health_attempts=0
                    while [ $health_attempts -lt 12 ]; do
                        health_status=$(sudo docker inspect --format='{{.State.Health.Status}}' restreamer 2>/dev/null || echo "no-healthcheck")
                        if [ "$health_status" = "healthy" ]; then
                            print_success "✓ Restreamer is healthy and ready"
                            break
                        elif [ "$health_status" = "unhealthy" ]; then
                            print_warning "Restreamer health check failed"
                            break
                        else
                            sleep 5
                            health_attempts=$((health_attempts + 1))
                        fi
                    done
                else
                    print_error "✗ Failed to start Restreamer on attempt $attempt"
                    
                    # Show logs for debugging
                    print_status "Restreamer container logs (last 10 lines):"
                    sudo docker logs restreamer --tail 10 2>/dev/null || echo "No logs available"
                    
                    # Show compose logs
                    print_status "Docker Compose logs:"
                    sudo docker compose logs --tail 10 2>/dev/null || echo "No compose logs available"
                    
                    if [ $attempt -lt $max_attempts ]; then
                        print_status "Cleaning up and retrying in 10 seconds..."
                        sudo docker compose down 2>/dev/null || true
                        sudo docker system prune -f >/dev/null 2>&1 || true
                        sleep 10
                    fi
                fi
                
                attempt=$((attempt + 1))
            done
            
            if [ "$started" = false ]; then
                print_error "✗ Failed to start Restreamer after $max_attempts attempts"
                print_status "Troubleshooting information:"
                print_status "- Image: $RESTREAMER_IMAGE"
                print_status "- Config dir: $RESTREAMER_CONFIG_DIR"
                print_status "- Architecture: $ARCH"
                print_status "Check docker compose logs with: cd $RESTREAMER_CONFIG_DIR && sudo docker compose logs"
                return 1
            fi
        fi
    else
        print_success "All Docker containers are already running"
    fi
    
    # Comprehensive final check to ensure both services are ready
    print_status "Performing final readiness check for all Docker services..."
    
    local services_ready=true
    local final_check_attempts=0
    local max_final_attempts=12  # 1 minute total
    
    while [ $final_check_attempts -lt $max_final_attempts ]; do
        local portainer_ok=false
        local restreamer_ok=false
        
        # Check Portainer
        if sudo docker ps --format "{{.Names}}" | grep -q portainer; then
            if curl -f -s http://localhost:9000/api/status >/dev/null 2>&1 || netstat -tuln 2>/dev/null | grep -q ':9000 '; then
                portainer_ok=true
            fi
        fi
        
        # Check Restreamer  
        if sudo docker ps --format "{{.Names}}" | grep -q restreamer; then
            health_status=$(sudo docker inspect --format='{{.State.Health.Status}}' restreamer 2>/dev/null || echo "no-healthcheck")
            if [ "$health_status" = "healthy" ]; then
                restreamer_ok=true
            elif curl -s http://localhost:8080 >/dev/null 2>&1; then
                restreamer_ok=true
            fi
        fi
        
        if [ "$portainer_ok" = true ] && [ "$restreamer_ok" = true ]; then
            print_success "✓ All Docker services are running and ready"
            break
        else
            if [ "$portainer_ok" = false ]; then
                print_status "Waiting for Portainer to be ready..."
            fi
            if [ "$restreamer_ok" = false ]; then
                print_status "Waiting for Restreamer to be ready..."
            fi
            sleep 5
            final_check_attempts=$((final_check_attempts + 1))
        fi
    done
    
    # Final validation
    if [ $final_check_attempts -eq $max_final_attempts ]; then
        print_error "Docker services did not become ready within the timeout period"
        print_status "Current container status:"
        sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Cannot retrieve container status"
        services_ready=false
        return 1
    fi
    
    # Show final status
    print_status "Final Docker services status:"
    sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(portainer|restreamer|NAMES)" 2>/dev/null || echo "Cannot retrieve container details"
}

# Function to create management scripts
create_management_scripts() {
    print_status "Creating management scripts..."
    
    # Create user management scripts directory
    local USER_SCRIPTS_DIR="/home/$USER/management-scripts"
    mkdir -p "$USER_SCRIPTS_DIR"
    
    # Create service management script
    cat > "$USER_SCRIPTS_DIR/manage-services.sh" << 'EOF'
#!/bin/bash

# Docker Services Management Script

case "$1" in
    start)
        echo "Starting all services..."
        cd /data/portainer && sudo docker compose up -d
        cd /data/restreamer && sudo docker compose up -d
        echo "All services started"
        ;;
    stop)
        echo "Stopping all services..."
        cd /data/portainer && sudo docker compose down
        cd /data/restreamer && sudo docker compose down
        echo "All services stopped"
        ;;
    restart)
        echo "Restarting all services..."
        cd /data/portainer && sudo docker compose restart
        cd /data/restreamer && sudo docker compose restart
        echo "All services restarted"
        ;;
    status)
        echo "Service status:"
        sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        ;;
    logs)
        echo "Portainer logs:"
        sudo docker logs portainer --tail 20
        echo
        echo "Restreamer logs:"
        sudo docker logs restreamer --tail 20
        ;;
    update)
        echo "Updating all services..."
        cd /data/portainer && sudo docker compose pull && sudo docker compose up -d
        cd /data/restreamer && sudo docker compose pull && sudo docker compose up -d
        echo "All services updated"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|update}"
        echo "  start   - Start all services"
        echo "  stop    - Stop all services"
        echo "  restart - Restart all services"
        echo "  status  - Show service status"
        echo "  logs    - Show service logs"
        echo "  update  - Update and restart services"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$USER_SCRIPTS_DIR/manage-services.sh"
    
    # Create backup script
    cat > "$USER_SCRIPTS_DIR/backup-services.sh" << 'EOF'
#!/bin/bash

# Docker Services Backup Script

BACKUP_DIR="/home/$USER/backups"
DATE=$(date +%Y%m%d_%H%M%S)

echo "Creating backup directory..."
mkdir -p $BACKUP_DIR

echo "Backing up Portainer data..."
sudo docker run --rm -v portainer_portainer_data:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/portainer-$DATE.tar.gz -C /data .

echo "Backing up Restreamer data..."
tar czf $BACKUP_DIR/restreamer-$DATE.tar.gz /data/restreamer/db

echo "Backup completed: $BACKUP_DIR"
ls -la $BACKUP_DIR/*$DATE*
EOF
    
    chmod +x "$USER_SCRIPTS_DIR/backup-services.sh"
    
    print_success "Management scripts created"
}

# =============================================================================
# UCI CONFIGURATION FUNCTIONS
# =============================================================================


# Function to configure UCI network interfaces
configure_uci_network() {
    print_status "Configuring UCI network interfaces..."
    
    # Note: Network configuration removed as requested
    # Only commit any existing network changes
    sudo uci commit network
    print_success "UCI network configuration completed (network settings removed)"
}

# Function to fix LAN configuration issues
fix_lan_configuration() {
    print_status "Checking and fixing LAN configuration..."
    
    # Check current LAN configuration
    local lan_proto=$(sudo uci -q get network.lan.proto 2>/dev/null || echo "unknown")
    local lan_ifname=$(sudo uci -q get network.lan.ifname 2>/dev/null || echo "unknown")
    
    print_status "Current LAN protocol: $lan_proto"
    print_status "Current LAN interfaces: $lan_ifname"
    
    # Fix LAN protocol if it's set to DHCP (should be static)
    if [ "$lan_proto" = "dhcp" ]; then
        print_warning "LAN protocol is set to DHCP, fixing to static..."
        sudo uci set network.lan.proto='static'
        print_success "LAN protocol fixed to static"
    fi
    
    # Fix LAN interfaces if wlan0 is missing
    if [[ "$lan_ifname" != *"wlan0"* ]]; then
        print_warning "LAN interface missing wlan0, adding it..."
        sudo uci set network.lan.ifname='eth0 wlan0'
        print_success "LAN interfaces updated to include wlan0"
    fi
    
    # Commit changes
    sudo uci commit network
    print_success "LAN configuration fixes applied"
}

# Function to configure UCI wireless
configure_uci_wireless() {
    print_status "Configuring UCI wireless settings..."
    
    # WiFi interface
    sudo uci set wireless.wlan0=wifi-iface
    sudo uci set wireless.wlan0.enabled='1'
    sudo uci set wireless.wlan0.channel="$TARGET_WIFI_CHANNEL"
    sudo uci set wireless.wlan0.hwmode='g'
    sudo uci set wireless.wlan0.type='bcmdhd'
    sudo uci set wireless.wlan0.encryption='wpa2psk'
    sudo uci set wireless.wlan0.ssid="$TARGET_WIFI_SSID"
    sudo uci set wireless.wlan0.key="$TARGET_WIFI_PASSWORD"
    
    sudo uci commit wireless
    print_success "UCI wireless configuration completed"
}


# =============================================================================
# CONFIGURATION FUNCTIONS
# =============================================================================

# Function to configure serial ports
configure_serial_ports() {
    print_status "Configuring serial port permissions..."
    
    # Create udev rules for serial ports
    cat <<EOL | sudo tee /etc/udev/rules.d/99-serial.rules
KERNEL=="ttyS0", MODE="0666"
KERNEL=="ttyS3", MODE="0666"
EOL
    
    # Reload udev rules
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    
    print_success "Serial port permissions configured"
}

# Function to check and fix Node-RED flow issues
check_nodered_flows() {
    print_status "Checking Node-RED flows for issues..."
    
    if [ ! -f "$NODERED_HOME/.node-red/flows.json" ]; then
        print_error "Node-RED flows file not found"
        return 1
    fi
    
    # Check if flows are empty or corrupted
    if ! validate_nodered_flows "$NODERED_HOME/.node-red/flows.json"; then
        print_warning "Node-RED flows validation failed, attempting to fix..."
        
        # Try to restore from backup
        if restore_nodered_flows; then
            print_success "Node-RED flows restored from backup"
            return 0
        else
            print_error "Failed to restore Node-RED flows"
            return 1
        fi
    fi
    
    # Check if Node-RED is running
    if ! sudo systemctl is-active --quiet nodered; then
        print_warning "Node-RED service is not running, attempting to start..."
        sudo systemctl start nodered
        sleep 5
        
        if sudo systemctl is-active --quiet nodered; then
            print_success "Node-RED service started successfully"
        else
            print_error "Failed to start Node-RED service"
            return 1
        fi
    fi
    
    print_success "Node-RED flows check completed successfully"
    return 0
}

# Function to test flow download and installation
test_flow_download() {
    print_section "TESTING NODE-RED FLOW DOWNLOAD"
    
    # Get the script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    TEST_DIR="/tmp/nodered_flow_test"
    
    print_status "Creating test directory: $TEST_DIR"
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
    
    # Test flow download
    print_status "Testing flow download from repository..."
    local flows_downloaded=false
    local repo_urls=(
        "https://raw.githubusercontent.com/Loranet-Technologies/bivicom-radar/main/nodered_flows/flows.json"
        "https://github.com/Loranet-Technologies/bivicom-radar/raw/main/nodered_flows/flows.json"
    )
    
    for url in "${repo_urls[@]}"; do
        print_status "Testing download from: $url"
        if curl -sSL --connect-timeout 10 --max-time 30 "$url" -o "test_flows.json" 2>/dev/null; then
            if [ -s "test_flows.json" ] && validate_nodered_flows "test_flows.json" 2>/dev/null; then
                print_success "Flow download test successful from: $url"
                flows_downloaded=true
                break
            else
                print_warning "Downloaded file is invalid from: $url"
                rm -f "test_flows.json"
            fi
        else
            print_warning "Download failed from: $url"
        fi
    done
    
    # Test package.json download
    print_status "Testing package.json download..."
    local package_downloaded=false
    
    for url in "${repo_urls[@]}"; do
        local package_url="${url/flows.json/package.json}"
        print_status "Testing package.json download from: $package_url"
        if curl -sSL --connect-timeout 10 --max-time 30 "$package_url" -o "test_package.json" 2>/dev/null; then
            if [ -s "test_package.json" ] && python3 -c "import json; json.load(open('test_package.json'))" 2>/dev/null; then
                print_success "Package.json download test successful from: $package_url"
                package_downloaded=true
                break
            else
                print_warning "Downloaded package.json is invalid from: $package_url"
                rm -f "test_package.json"
            fi
        else
            print_warning "Package.json download failed from: $package_url"
        fi
    done
    
    # Clean up test directory
    cd /
    rm -rf "$TEST_DIR"
    
    # Summary
    echo
    print_status "=== FLOW DOWNLOAD TEST SUMMARY ==="
    if [ "$flows_downloaded" = true ]; then
        print_success "✓ Flow download: SUCCESS"
    else
        print_error "✗ Flow download: FAILED"
    fi
    
    if [ "$package_downloaded" = true ]; then
        print_success "✓ Package.json download: SUCCESS"
    else
        print_error "✗ Package.json download: FAILED"
    fi
    
    if [ "$flows_downloaded" = true ] && [ "$package_downloaded" = true ]; then
        print_success "All download tests passed! Cloud installation should work."
        return 0
    else
        print_warning "Some download tests failed. Check network connectivity and repository access."
        return 1
    fi
}


# Function to create installation status file
create_installation_status_file() {
    print_status "Creating installation status file..."
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local server_ip=$(hostname -I | awk '{print $1}')
    local hostname=$(hostname)
    local status_file="/home/$USER/installation_status_$(date +%Y%m%d_%H%M%S).md"
    
    # Create status file on server
    cat > "$status_file" << EOF
# Loranet Infrastructure Installation Status

**Installation Date:** $timestamp  
**Server Hostname:** $hostname  
**Server IP:** $server_ip  
**Installation Mode:** ${AUTO_RUN:-Interactive}

## 🚀 Services Installed

### Node-RED
- **Status:** $(sudo systemctl is-active nodered 2>/dev/null || echo "Unknown")
- **URL:** http://$server_ip:1880
- **Service:** sudo systemctl status nodered
- **Logs:** sudo journalctl -u nodered -f

### Docker Services
- **Docker Status:** $(sudo systemctl is-active docker 2>/dev/null || echo "Unknown")
- **Containers:** $(sudo docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || echo "Docker not available")

#### Portainer
- **Status:** $(sudo docker ps --filter "name=portainer" --format "{{.Status}}" 2>/dev/null || echo "Not running")
- **HTTP URL:** http://$server_ip:9000
- **HTTPS URL:** https://$server_ip:9443
- **Data Directory:** /data/portainer

#### Restreamer
- **Status:** $(sudo docker ps --filter "name=restreamer" --format "{{.Status}}" 2>/dev/null || echo "Not running")
- **URL:** http://$server_ip:8080
- **Username:** $RESTREAMER_USERNAME
- **Password:** $RESTREAMER_PASSWORD
- **Data Directory:** /data/restreamer

### Tailscale VPN
- **Status:** $(sudo tailscale status 2>/dev/null | head -1 || echo "Not connected")
- **Check Status:** sudo tailscale status
- **Connect:** sudo tailscale up

## 🔧 UCI Configuration (OpenWrt)

### System Settings
- **Hostname:** ${TARGET_HOSTNAME:-Not configured}
- **Timezone:** $(sudo uci get system.system.timezone 2>/dev/null || echo "Default")
- **NTP Server:** $(sudo uci get system.ntp.server 2>/dev/null || echo "Default")

### Wireless Settings
- **SSID:** ${TARGET_WIFI_SSID:-Not configured}
- **Channel:** ${TARGET_WIFI_CHANNEL:-Not configured}
- **Status:** $(sudo uci get wireless.@wifi-iface[0].disabled 2>/dev/null || echo "Unknown")

### User Accounts
- **Admin Password:** Set to 1qaz2wsx
- **Root Access:** Available

## 📁 Backup Locations

### UCI Backups
- **Location:** /home/$USER/uci-backup-* (or /tmp/uci-backup-* as fallback)
- **Contents:** Complete UCI configuration backup

### Node-RED Backups
- **Location:** ~/.node-red/flows_*.json
- **Standard Backup:** ~/.node-red/.flows.json.backup

### Docker Backups
- **Script:** /home/$USER/management-scripts/backup-services.sh
- **Usage:** /home/$USER/management-scripts/backup-services.sh

## 🛠️ Management Commands

### Service Management
\`\`\`bash
# Node-RED
sudo systemctl status nodered
sudo systemctl restart nodered
sudo journalctl -u nodered -f

# Docker
sudo docker ps
sudo docker logs [container_name]
sudo docker restart [container_name]

# Tailscale
sudo tailscale status
sudo tailscale up
sudo tailscale down
\`\`\`

### UCI Management
\`\`\`bash
# View configuration
sudo uci show

# Network
sudo uci show network
sudo /etc/init.d/network reload >/dev/null 2>&1

# Wireless
sudo uci show wireless
sudo wifi reload
\`\`\`

## 🔍 Troubleshooting

### Check Service Status
\`\`\`bash
# All services
sudo systemctl status nodered docker

# Docker containers
sudo docker ps -a

# Network connectivity
ping -c 3 8.8.8.8
\`\`\`

### Log Locations
- **Node-RED:** /var/log/syslog (sudo journalctl -u nodered)
- **Docker:** docker logs [container_name]
- **System:** /var/log/syslog

## 📞 Support Information

- **Repository:** https://github.com/Loranet-Technologies/bivicom-radar
- **Author:** Aqmar (Loranet Technologies)
- **License:** MIT

---
*Generated on $timestamp by Loranet Infrastructure Setup Script v2.1*
EOF

    print_success "Installation status file created: $status_file"
    
    # Copy to local PC if we're running from a local directory
    local script_dir=$(dirname "$(readlink -f "$0")" 2>/dev/null || dirname "$0")
    if [ -w "$script_dir" ] && [ "$script_dir" != "/" ]; then
        local local_copy="$script_dir/installation_status_$(date +%Y%m%d_%H%M%S).md"
        cp "$status_file" "$local_copy" 2>/dev/null && {
            print_success "Status file copied to local directory: $local_copy"
        } || {
            print_warning "Could not copy status file to local directory"
        }
    fi
    
    # Also create a symlink for easy access
    ln -sf "$status_file" "/home/$USER/installation_status_latest.md" 2>/dev/null || true
    print_status "Latest status available at: /home/$USER/installation_status_latest.md"
}

# Function to verify all installations
verify_installation() {
    print_status "Verifying installation..."
    
    # Wait for services to start
    sleep 10
    
    # Check Docker service
    if sudo systemctl is-active --quiet docker; then
        print_success "Docker service is running"
    else
        print_error "Docker service is not running"
        return 1
    fi
    
    # Check Node-RED
    if sudo systemctl is-active --quiet nodered; then
        print_success "Node-RED service is running"
        
        # Check Node-RED flows
        if check_nodered_flows; then
            print_success "Node-RED flows are valid and working"
        else
            print_warning "Node-RED flows have issues but service is running"
        fi
    else
        print_error "Node-RED service is not running"
        return 1
    fi
    
    # Check Tailscale
    if sudo systemctl is-active --quiet tailscaled; then
        print_success "Tailscale service is running"
    else
        print_error "Tailscale service is not running"
        return 1
    fi
    
    # Check Docker containers with comprehensive readiness validation
    print_status "Verifying Docker containers are running and ready..."
    if sudo docker version >/dev/null 2>&1; then
        
        # Check Portainer with readiness validation
        print_status "Validating Portainer container..."
        if sudo docker ps 2>/dev/null | grep -q portainer; then
            # Check if Portainer is actually ready
            local portainer_ready=false
            local check_attempts=0
            while [ $check_attempts -lt 12 ] && [ "$portainer_ready" = false ]; do
                if curl -f -s http://localhost:9000/api/status >/dev/null 2>&1; then
                    print_success "✓ Portainer container is running and API is ready"
                    portainer_ready=true
                elif netstat -tuln 2>/dev/null | grep -q ':9000 ' || ss -tuln 2>/dev/null | grep -q ':9000 '; then
                    print_success "✓ Portainer container is running and port is accessible"
                    portainer_ready=true
                else
                    sleep 5
                    check_attempts=$((check_attempts + 1))
                fi
            done
            
            if [ "$portainer_ready" = false ]; then
                print_error "Portainer container is running but not ready/accessible"
                return 1
            fi
        else
            print_error "Portainer container is not running"
            return 1
        fi
        
        # Check Restreamer with comprehensive validation
        print_status "Validating Restreamer container..."
        if sudo docker ps 2>/dev/null | grep -q restreamer; then
            # Check Restreamer health and readiness
            local restreamer_ready=false
            local check_attempts=0
            local max_check_attempts=24  # 2 minutes total
            
            print_status "Waiting for Restreamer to be fully ready..."
            while [ $check_attempts -lt $max_check_attempts ] && [ "$restreamer_ready" = false ]; do
                # Check container health status
                health_status=$(sudo docker inspect --format='{{.State.Health.Status}}' restreamer 2>/dev/null || echo "no-healthcheck")
                container_status=$(sudo docker inspect --format='{{.State.Status}}' restreamer 2>/dev/null || echo "unknown")
                
                if [ "$health_status" = "healthy" ]; then
                    print_success "✓ Restreamer container is running and healthy"
                    restreamer_ready=true
                elif [ "$container_status" = "running" ]; then
                    # If no health check, try to verify port accessibility and API
                    if netstat -tuln 2>/dev/null | grep -q ':8080 ' || ss -tuln 2>/dev/null | grep -q ':8080 '; then
                        # Try to connect to Restreamer API
                        if curl -f -s http://localhost:8080/api/v3/skills >/dev/null 2>&1; then
                            print_success "✓ Restreamer container is running and API is ready"
                            restreamer_ready=true
                        elif curl -s http://localhost:8080 >/dev/null 2>&1; then
                            print_success "✓ Restreamer container is running and web interface is accessible"
                            restreamer_ready=true
                        else
                            # Port is open but API not ready yet
                            sleep 5
                            check_attempts=$((check_attempts + 1))
                            if [ $((check_attempts % 6)) -eq 0 ]; then  # Every 30 seconds
                                print_status "Still waiting for Restreamer API to be ready... ($((check_attempts * 5))s elapsed)"
                            fi
                        fi
                    else
                        # Port not ready yet
                        sleep 5
                        check_attempts=$((check_attempts + 1))
                    fi
                elif [ "$health_status" = "unhealthy" ]; then
                    print_error "Restreamer container is unhealthy"
                    print_status "Checking Restreamer logs for issues:"
                    sudo docker logs restreamer --tail 15
                    return 1
                else
                    # Container not running or other issues
                    sleep 5
                    check_attempts=$((check_attempts + 1))
                fi
            done
            
            if [ "$restreamer_ready" = false ]; then
                print_error "Restreamer container is running but not ready after 2 minutes"
                print_status "Container status: $container_status"
                print_status "Health status: $health_status"
                print_status "Restreamer logs (last 10 lines):"
                sudo docker logs restreamer --tail 10
                print_error "Installation cannot complete until Restreamer is ready"
                return 1
            fi
        else
            print_error "Restreamer container is not running"
            print_status "This is a critical error - installation cannot complete"
            return 1
        fi
        
        # Final containers status summary
        print_status "Final container status check:"
        sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(portainer|restreamer|NAMES)"
        
    else
        print_error "Cannot check Docker containers due to permission issues"
        print_status "Please ensure Docker is running and user has proper permissions"
        return 1
    fi
    
    # Get server IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    print_success "Installation verification completed"
    
    # Create installation status file
    create_installation_status_file
    
    echo
    print_status "=== SERVICE ACCESS INFORMATION ==="
    echo -e "${GREEN}Node-RED:${NC} http://$SERVER_IP:1880"
    echo -e "${GREEN}Portainer (Container Management):${NC}"
    echo -e "  HTTP:  http://$SERVER_IP:9000"
    echo -e "  HTTPS: https://$SERVER_IP:9443"
    echo -e "${GREEN}Restreamer (Streaming Service):${NC}"
    echo -e "  HTTP:  http://$SERVER_IP:8080"
    echo -e "  Username: $RESTREAMER_USERNAME"
    echo -e "  Password: $RESTREAMER_PASSWORD"
    echo -e "${GREEN}Tailscale:${NC} Check status with 'sudo tailscale status'"
    echo
    print_status "=== MANAGEMENT COMMANDS ==="
    echo -e "${BLUE}Node-RED status:${NC} sudo systemctl status nodered"
    echo -e "${BLUE}Node-RED logs:${NC} sudo journalctl -u nodered -f"
    echo -e "${BLUE}Docker containers:${NC} sudo docker ps"
    echo -e "${BLUE}Docker logs:${NC} sudo docker logs [container_name]"
    echo -e "${BLUE}Tailscale status:${NC} sudo tailscale status"
    echo -e "${BLUE}Management script:${NC} /home/$USER/management-scripts/manage-services.sh"
}

# Function to prompt for reboot
prompt_reboot() {
    echo
    print_warning "Installation completed successfully!"
    print_status "A system reboot is recommended to ensure all changes take effect."
    
    # Check if we're in auto mode
    if [[ "$AUTO_RUN_MODE" == "true" ]]; then
        print_status "Auto-run mode: Skipping reboot prompt."
        print_warning "Please reboot manually when convenient: sudo reboot"
        print_success "Installation completed successfully! Exiting with SUCCESS code."
        exit 0
    fi
    
    echo
    read -p "Do you want to reboot now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Rebooting system..."
        print_success "Installation completed successfully! Exiting with SUCCESS code."
        sudo reboot
    else
        print_status "Reboot skipped. Please reboot manually when convenient."
        print_warning "Run 'sudo reboot' when ready to complete the setup."
        print_success "Installation completed successfully! Exiting with SUCCESS code."
        exit 0
    fi
}

# Function to show help
show_help() {
    echo "Complete Infrastructure Setup Script with UCI Configuration"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -v, --version       Show version information"
    echo "  --auto, -y, --yes   Auto-run without confirmation"
    echo "  --force             Force reinstall even if services exist"
    echo "  --skip-uci          Skip UCI configuration"
    echo "  --skip-docker       Skip Docker services setup"
    echo "  --skip-nodered      Skip Node-RED setup"
    echo "  --skip-tailscale    Skip Tailscale setup"
    echo "  --skip-pre-deploy   Skip pre-deployment system preparation"
    echo "  --fix-nodered       Fix Node-RED flow issues"
    echo "  --check-flows       Check and validate Node-RED flows"
    echo "  --test-download     Test Node-RED flow download from cloud"
    echo
    echo "This script will install:"
    echo "  • Node-RED with flows downloaded from repository"
    echo "  • Tailscale VPN"
    echo "  • Docker & Docker Compose"
    echo "  • Portainer (Container Management)"
    echo "  • Restreamer (Video Streaming)"
    echo "  • UCI Configuration (OpenWrt)"
    echo
    echo "New Features:"
    echo "  • Automatic flow backup and restoration"
    echo "  • Flow validation and error detection"
    echo "  • Enhanced error handling and recovery"
    echo
    echo "Author: Aqmar"
    echo "Repository: https://github.com/Loranet-Technologies/bivicom-radar"
}

# Function to show version
show_version() {
    echo "Complete Infrastructure Setup Script v2.0"
    echo "Author: Aqmar"
    echo "Date: $(date +%Y-%m-%d)"
    echo "Repository: https://github.com/Loranet-Technologies/bivicom-radar"
}

# Global variable to track auto-run mode
AUTO_RUN_MODE=false

# Function to handle command line arguments
handle_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            --fix-nodered)
                print_section "FIXING NODE-RED FLOWS"
                check_nodered_flows
                exit 0
                ;;
            --check-flows)
                print_section "CHECKING NODE-RED FLOWS"
                if validate_nodered_flows "$NODERED_HOME/.node-red/flows.json"; then
                    print_success "Node-RED flows are valid"
                else
                    print_error "Node-RED flows have issues"
                    exit 1
                fi
                exit 0
                ;;
            --test-download)
                print_section "TESTING NODE-RED FLOW DOWNLOAD"
                test_flow_download
                exit 0
                ;;
            --auto|-y|--yes)
                print_status "Auto-run mode enabled. Proceeding with installation..."
                AUTO_RUN_MODE=true
                shift
                ;;
            --force)
                print_warning "Force mode enabled. Will reinstall even if services exist."
                FORCE_INSTALL=true
                shift
                ;;
            --skip-uci)
                print_warning "UCI configuration will be skipped"
                SKIP_UCI=true
                shift
                ;;
            --skip-docker)
                print_warning "Docker services setup will be skipped"
                SKIP_DOCKER=true
                shift
                ;;
            --skip-nodered)
                print_warning "Node-RED setup will be skipped"
                SKIP_NODERED=true
                shift
                ;;
            --skip-tailscale)
                print_warning "Tailscale setup will be skipped"
                SKIP_TAILSCALE=true
                shift
                ;;
            --skip-pre-deploy)
                print_warning "Pre-deployment system preparation will be skipped"
                SKIP_PRE_DEPLOY=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    # Handle command line arguments first
    handle_arguments "$@"
    
    echo "=========================================="
    echo "  Complete Infrastructure Setup Script"
    echo "  with UCI Configuration v2.0"
    echo "=========================================="
    echo
    
    # Pre-flight checks
    check_root
    check_sudo
    detect_architecture
    
    # Pre-deployment system preparation
    if [ "$SKIP_PRE_DEPLOY" != true ]; then
        print_section "PRE-DEPLOYMENT SYSTEM PREPARATION"
        pre_deployment_preparation
    else
        print_warning "Pre-deployment system preparation skipped"
    fi
    
    # Check existing services before installation (unless force mode)
    if [ "$FORCE_INSTALL" != true ]; then
        print_section "SERVICE STATUS CHECK"
        if check_existing_services; then
            print_success "All services are already installed and running!"
            print_status "Installation complete. Use --help for management commands."
            print_status "Use --force to reinstall even if services exist."
            print_success "Installation completed successfully! Exiting with SUCCESS code."
            exit 0
        fi
    else
        print_section "SERVICE STATUS CHECK (FORCE MODE)"
        print_warning "Force mode enabled - checking services but will proceed with installation"
        check_existing_services
    fi
    
    # Check if OpenWrt and get UCI configuration
    IS_OPENWRT=false
    if check_openwrt; then
        IS_OPENWRT=true
        # Check if we're in auto-run mode
        if [[ "$AUTO_RUN_MODE" == "true" ]]; then
            print_status "Auto-run mode: Using default UCI configuration"
            TARGET_HOSTNAME="router"
            TARGET_LAN_IP="192.168.14.1"
            TARGET_WIFI_SSID="router"
            TARGET_WIFI_PASSWORD="1qaz2wsx"
            TARGET_WIFI_CHANNEL="10"
            TARGET_APN="Max4g"
            print_success "UCI configuration will be applied with default hostname: $TARGET_HOSTNAME"
        else
            if get_uci_configuration; then
                print_success "UCI configuration will be applied"
            else
                print_warning "UCI configuration skipped"
            fi
        fi
    else
        print_warning "Not an OpenWrt system. UCI configuration will be skipped."
    fi
    
    # Part 1: UCI Configuration (if OpenWrt) - Run first
    if [ "$IS_OPENWRT" = true ]; then
        print_section "PART 1: UCI CONFIGURATION"
        backup_uci_config
        configure_uci_system
        configure_uci_password
        configure_uci_network
        fix_lan_configuration
        configure_uci_wireless
        restart_uci_services
    fi
    
    # Part 2: Node-RED and Tailscale Setup
    print_section "PART 2: NODE-RED AND TAILSCALE SETUP"
    update_system
    install_dependencies
    copy_flows_to_script
    install_nvm
    install_nodejs
    install_nodered
    install_nodered_nodes
    create_nodered_systemd_service
    import_flows
    install_tailscale
    configure_serial_ports
    
    # Part 3: Docker Services Setup
    print_section "PART 3: DOCKER SERVICES SETUP"
    create_docker_directories
    create_portainer_compose
    create_restreamer_compose
    start_docker_services
    create_management_scripts
    
    # Final verification
    print_section "FINAL VERIFICATION"
    verify_installation
    
    echo
    echo "=========================================="
    print_success "Complete Infrastructure Setup Completed!"
    echo "=========================================="
    echo
    print_warning "IMPORTANT: All Docker commands use sudo for proper permissions."
    print_warning "Docker group membership has been applied for future non-sudo access if needed."
    echo
    print_status "Management scripts created:"
    echo "  - /home/$USER/management-scripts/manage-services.sh"
    echo "  - /home/$USER/management-scripts/backup-services.sh"
    echo
    print_status "Next steps:"
    if [ "$IS_OPENWRT" = true ]; then
        echo "  1. UCI configuration applied with hostname: $TARGET_HOSTNAME"
        echo "  2. WiFi SSID: $TARGET_WIFI_SSID"
        echo "  3. LAN IP: $TARGET_LAN_IP"
        echo "  4. Access Node-RED at: http://$(hostname -I | awk '{print $1}'):1880"
        echo "  5. Access Portainer at: http://$(hostname -I | awk '{print $1}'):9000"
        echo "  6. Access Restreamer at: http://$(hostname -I | awk '{print $1}'):8080"
        echo "  7. Configure Tailscale with: sudo tailscale up"
        echo "  8. Use management scripts for service control"
    else
        echo "  1. Access Node-RED at: http://$(hostname -I | awk '{print $1}'):1880"
        echo "  2. Access Portainer at: http://$(hostname -I | awk '{print $1}'):9000"
        echo "  3. Access Restreamer at: http://$(hostname -I | awk '{print $1}'):8080"
        echo "  4. Configure Tailscale with: sudo tailscale up"
        echo "  5. Use management scripts for service control"
    fi
    
    # Prompt for reboot
    prompt_reboot
}

# Run main function
main "$@"
