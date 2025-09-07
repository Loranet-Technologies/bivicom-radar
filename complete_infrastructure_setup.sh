#!/bin/bash

# =============================================================================
# Complete Infrastructure Setup Script with UCI Configuration
# =============================================================================
# This script combines Node-RED, Tailscale, Docker, Portainer, Restreamer,
# and UCI configuration setup for OpenWrt systems
# 
# Author: Aqmar
# Date: $(date +%Y-%m-%d)
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
RESTREAMER_DATA_DIR="/mnt/restreamer/db"
PORTAINER_DATA_DIR="/opt/portainer"
RESTREAMER_CONFIG_DIR="/opt/restreamer"

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
    
    # Get LAN IP
    while true; do
        get_user_input "Enter LAN IP address" "192.168.14.1" "TARGET_LAN_IP"
        if validate_ip "$TARGET_LAN_IP"; then
            break
        else
            print_error "Invalid IP address format. Please try again."
        fi
    done
    
    # Get WiFi password
    get_user_input "Enter WiFi password" "1qaz2wsx" "TARGET_WIFI_PASSWORD"
    
    # Get WiFi channel
    get_user_input "Enter WiFi channel" "10" "TARGET_WIFI_CHANNEL"
    
    # Get APN
    get_user_input "Enter APN for LTE" "Max4g" "TARGET_APN"
    
    # Set WiFi SSID to hostname
    TARGET_WIFI_SSID="$TARGET_HOSTNAME"
    
    # Display summary
    echo
    print_section "CONFIGURATION SUMMARY"
    print_status "Hostname: $TARGET_HOSTNAME"
    print_status "LAN IP: $TARGET_LAN_IP"
    print_status "WiFi SSID: $TARGET_WIFI_SSID"
    print_status "WiFi Password: $TARGET_WIFI_PASSWORD"
    print_status "WiFi Channel: $TARGET_WIFI_CHANNEL"
    print_status "APN: $TARGET_APN"
    echo
    
    # Confirmation
    read -p "Do you want to apply this configuration? (y/N): " -n 1 -r
    echo
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
    
    local backup_dir="/etc/uci-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup all UCI configs
    for config in /etc/config/*; do
        if [ -f "$config" ]; then
            cp "$config" "$backup_dir/"
        fi
    done
    
    print_success "UCI configuration backed up to: $backup_dir"
}

# Function to configure UCI system settings
configure_uci_system() {
    print_status "Configuring UCI system settings..."
    
    uci set system.system.hostname="$TARGET_HOSTNAME"
    uci set system.system.timezone="$TARGET_TIMEZONE"
    uci set system.system.zonename="$TARGET_ZONENAME"
    uci set system.system.model="$TARGET_MODEL"
    uci set system.system.enable_212='1'
    uci set system.system.dual_sim='0'
    uci set system.system.sms_password='admin'
    
    # Configure NTP servers
    uci delete system.ntp.server 2>/dev/null || true
    uci add_list system.ntp.server='0.openwrt.pool.ntp.org'
    uci add_list system.ntp.server='1.openwrt.pool.ntp.org'
    uci add_list system.ntp.server='2.openwrt.pool.ntp.org'
    uci add_list system.ntp.server='3.openwrt.pool.ntp.org'
    
    # Configure access settings
    uci set system.access.enable_telnet='1'
    uci set system.access.enable_ssh='0'
    
    uci commit system
    print_success "UCI system configuration completed"
}

# Function to configure UCI password
configure_uci_password() {
    print_status "Configuring UCI user password..."
    
    uci set system.system.password='1qaz2wsx'
    echo "root:1qaz2wsx" | chpasswd 2>/dev/null || {
        print_warning "Could not set password using chpasswd, trying alternative method..."
        PASSWORD_HASH=$(echo -n "1qaz2wsx" | openssl passwd -1 -stdin 2>/dev/null || echo "")
        if [ -n "$PASSWORD_HASH" ]; then
            uci set system.system.password="$PASSWORD_HASH"
            print_success "Password hash set via UCI"
        else
            print_warning "Could not generate password hash, password may need to be set manually"
        fi
    }
    uci commit system
    
    if [ -w "/etc/shadow" ]; then
        PASSWORD_HASH=$(echo -n "1qaz2wsx" | openssl passwd -1 -stdin 2>/dev/null || echo "")
        if [ -n "$PASSWORD_HASH" ]; then
            sed -i "s|^root:.*|root:$PASSWORD_HASH:0:0:99999:7:::|" /etc/shadow 2>/dev/null || true
            print_success "Password set in /etc/shadow"
        fi
    fi
    
    print_success "UCI user password configuration completed"
    print_status "Username: admin/root"
    print_status "Password: 1qaz2wsx"
}

# Function to configure UCI network settings
configure_uci_network() {
    print_status "Configuring UCI network settings..."
    
    # Configure LAN interface
    uci set network.lan.proto='static'
    uci set network.lan.ipaddr="$TARGET_LAN_IP"
    uci set network.lan.netmask="$TARGET_LAN_NETMASK"
    uci set network.lan.macaddr="$TARGET_LAN_MAC"
    uci set network.lan.ifname='eth0 eth1'
    uci set network.lan.type='bridge'
    uci set network.lan.dns='8.8.8.8'
    
    # Configure WAN interface
    uci set network.wan.proto='3g'
    uci set network.wan.device='/dev/ttyUSB0'
    uci set network.wan.service='umts'
    uci set network.wan.apn="$TARGET_APN"
    uci set network.wan.pincode=''
    uci set network.wan.username=''
    uci set network.wan.password=''
    uci set network.wan.ifname='usb0'
    
    uci commit network
    print_success "UCI network configuration completed"
}

# Function to configure UCI wireless settings
configure_uci_wireless() {
    print_status "Configuring UCI wireless settings..."
    
    # Configure wireless interface
    uci set wireless.wlan0.enabled='1'
    uci set wireless.wlan0.channel="$TARGET_WIFI_CHANNEL"
    uci set wireless.wlan0.hwmode='g'
    uci set wireless.wlan0.type='bcmdhd'
    uci set wireless.wlan0.encryption='wpa2psk'
    uci set wireless.wlan0.ssid="$TARGET_WIFI_SSID"
    uci set wireless.wlan0.key="$TARGET_WIFI_PASSWORD"
    
    uci commit wireless
    print_success "UCI wireless configuration completed"
}

# Function to restart UCI services
restart_uci_services() {
    print_status "Restarting UCI services..."
    
    /etc/init.d/network reload
    /etc/init.d/firewall reload
    /etc/init.d/dnsmasq reload
    
    print_success "UCI services restarted"
}


# Function to validate IP address
validate_ip() {
    local ip="$1"
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if [ "$i" -gt 255 ] || [ "$i" -lt 0 ]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}


# Function to detect system architecture
detect_architecture() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            RESTREAMER_IMAGE="datarhei/restreamer:latest"
            ;;
        aarch64|arm64)
            RESTREAMER_IMAGE="datarhei/restreamer-aarch64:latest"
            ;;
        armv7l)
            RESTREAMER_IMAGE="datarhei/restreamer:latest"
            ;;
        *)
            print_warning "Unknown architecture: $ARCH. Using default restreamer image."
            RESTREAMER_IMAGE="datarhei/restreamer:latest"
            ;;
    esac
    print_status "Detected architecture: $ARCH"
    print_status "Using Restreamer image: $RESTREAMER_IMAGE"
}

# Function to update system
update_system() {
    print_status "Updating system packages..."
    sudo apt update -y
    sudo apt upgrade -y
    print_success "System packages updated"
}

# Function to install dependencies
install_dependencies() {
    print_status "Installing required dependencies..."
    sudo apt install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common \
        wget \
        nano \
        htop \
        build-essential \
        python3
    print_success "Dependencies installed"
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
    
    # Ensure NVM is loaded
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm use $NODE_VERSION
    
    # Install Node-RED globally
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
    
    # Install required nodes from package.json
    npm install node-red-contrib-ffmpeg@~0.1.1
    npm install node-red-contrib-queue-gate@~1.5.5
    npm install node-red-node-sqlite@~1.1.0
    npm install node-red-node-serialport@2.0.3
    
    print_success "Node-RED nodes installed"
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
    
    # Copy flows from current server if they exist
    if [ -f "/home/admin/.node-red/flows.json" ]; then
        cp "/home/admin/.node-red/flows.json" "$SCRIPT_DIR/nodered_flows/flows.json"
        print_success "Flows copied to script directory"
    else
        print_warning "No existing flows found on this server"
    fi
    
    # Copy package.json if it exists
    if [ -f "/home/admin/.node-red/package.json" ]; then
        cp "/home/admin/.node-red/package.json" "$SCRIPT_DIR/nodered_flows/package.json"
        print_success "Package.json copied to script directory"
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
    local file_size=$(stat -c%s "$flows_file" 2>/dev/null || echo "0")
    if [ "$file_size" -lt 1000 ]; then
        print_warning "Flows file is very small ($file_size bytes), may be empty or corrupted"
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
            if [ -f "$backup_file" ] && validate_nodered_flows "$backup_file"; then
                print_status "Restoring flows from: $(basename "$backup_file")"
                cp "$backup_file" "$NODERED_HOME/.node-red/flows.json"
                sudo chown $NODERED_USER:$NODERED_USER "$NODERED_HOME/.node-red/flows.json"
                restored=true
                break 2
            fi
        done
    done
    
    if [ "$restored" = true ]; then
        print_success "Flows restored from backup"
    else
        print_warning "No valid backup found, will use default flows"
    fi
    
    # Restart Node-RED
    sudo systemctl start nodered
    sleep 5
    
    if sudo systemctl is-active --quiet nodered; then
        print_success "Node-RED restarted successfully"
    else
        print_error "Failed to restart Node-RED"
        return 1
    fi
}

# Function to import flows
import_flows() {
    print_status "Setting up Node-RED flows with enhanced validation..."
    
    # First, backup any existing flows
    backup_nodered_flows
    
    # Stop Node-RED temporarily
    sudo systemctl stop nodered 2>/dev/null || true
    
    # Get the script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    local flows_imported=false
    
    # Check if we have local flows to use
    if [ -f "$SCRIPT_DIR/nodered_flows/flows.json" ]; then
        print_status "Found local flows, validating..."
        
        # Validate local flows
        if validate_nodered_flows "$SCRIPT_DIR/nodered_flows/flows.json"; then
            cp "$SCRIPT_DIR/nodered_flows/flows.json" "$NODERED_HOME/.node-red/flows.json"
            print_success "Local flows imported successfully"
            flows_imported=true
        else
            print_warning "Local flows validation failed, trying backup restoration..."
        fi
    fi
    
    # If local flows failed or don't exist, try to restore from backup
    if [ "$flows_imported" = false ]; then
        print_warning "Local flows not available, checking for existing backups..."
        restore_nodered_flows
        flows_imported=true
    fi
    
    # If still no flows, create default
    if [ "$flows_imported" = false ]; then
        print_warning "No valid flows found, creating default flows"
        cat > "$NODERED_HOME/.node-red/flows.json" << 'EOF'
[
    {
        "id": "tab1",
        "type": "tab",
        "label": "Default Flow",
        "disabled": false,
        "info": "Default Node-RED flow - please import your custom flows"
    }
]
EOF
    fi
    
    # Copy package.json if available
    if [ -f "$SCRIPT_DIR/nodered_flows/package.json" ]; then
        cp "$SCRIPT_DIR/nodered_flows/package.json" "$NODERED_HOME/.node-red/package.json"
        print_success "Package.json copied from local backup"
    fi
    
    # Set proper ownership
    sudo chown $NODERED_USER:$NODERED_USER "$NODERED_HOME/.node-red/flows.json"
    sudo chown $NODERED_USER:$NODERED_USER "$NODERED_HOME/.node-red/package.json" 2>/dev/null || true
    
    # Final validation
    if validate_nodered_flows "$NODERED_HOME/.node-red/flows.json"; then
        print_success "Node-RED flows setup completed successfully"
    else
        print_warning "Flows validation failed, but Node-RED will start with default flow"
    fi
    
    # Restart Node-RED
    sudo systemctl start nodered
    
    # Wait for restart
    sleep 5
    
    if sudo systemctl is-active --quiet nodered; then
        print_success "Flows imported and Node-RED restarted successfully"
    else
        print_error "Failed to restart Node-RED after importing flows"
        exit 1
    fi
}

# Function to install Tailscale
install_tailscale() {
    print_status "Installing Tailscale..."
    
    # Download and run Tailscale installation script
    curl -sSL https://raw.githubusercontent.com/iyon09/Bivocom-Node-RED-Tailscale-/main/DanLab_BV2.sh | bash
    
    # Enable and start Tailscale
    sudo systemctl enable tailscaled
    sudo systemctl start tailscaled
    
    # Verify Tailscale installation
    if sudo systemctl is-active --quiet tailscaled; then
        print_success "Tailscale installed and running"
    else
        print_error "Tailscale installation or startup failed"
        exit 1
    fi
}

# =============================================================================
# DOCKER INSTALLATION FUNCTIONS
# =============================================================================

# Function to install Docker
install_docker() {
    print_status "Installing Docker..."
    
    # Remove old Docker installations
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package index
    sudo apt update
    
    # Install Docker Engine
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add current user to docker group
    sudo usermod -aG docker $USER
    
    # Enable and start Docker service
    sudo systemctl enable docker
    sudo systemctl start docker
    
    print_success "Docker installed successfully"
}

# Function to create directories
create_docker_directories() {
    print_status "Creating required directories..."
    
    # Create portainer directory
    sudo mkdir -p $PORTAINER_DATA_DIR
    sudo chown $USER:$USER $PORTAINER_DATA_DIR
    
    # Create restreamer directory
    sudo mkdir -p $RESTREAMER_CONFIG_DIR
    sudo chown $USER:$USER $RESTREAMER_CONFIG_DIR
    
    # Create restreamer data directory
    sudo mkdir -p $RESTREAMER_DATA_DIR
    sudo chown $USER:$USER $RESTREAMER_DATA_DIR
    
    print_success "Directories created"
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
services:
  restreamer:
    image: $RESTREAMER_IMAGE
    container_name: restreamer
    restart: always
    environment:
      - RS_USERNAME=$RESTREAMER_USERNAME
      - RS_PASSWORD=$RESTREAMER_PASSWORD
      - TZ=$TIMEZONE
    ports:
      - "8080:8080"
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
      - $RESTREAMER_DATA_DIR:/restreamer/db
    tmpfs:
      - /tmp/hls
    networks:
      - restreamer-network

networks:
  restreamer-network:
    driver: bridge
EOF
    
    print_success "Restreamer Docker Compose file created"
}

# Function to start Docker services
start_docker_services() {
    print_status "Starting Docker services..."
    
    # Apply Docker group membership for current session
    print_status "Applying Docker group membership..."
    newgrp docker << EOFNEWGRP
    # Start Portainer
    cd $PORTAINER_DATA_DIR
    docker compose up -d
    
    # Start Restreamer
    cd $RESTREAMER_CONFIG_DIR
    docker compose up -d
    
    print_success "Docker services started"
EOFNEWGRP
}

# Function to create management scripts
create_management_scripts() {
    print_status "Creating management scripts..."
    
    # Create service management script
    cat > $PORTAINER_DATA_DIR/manage-services.sh << 'EOF'
#!/bin/bash

# Docker Services Management Script

case "$1" in
    start)
        echo "Starting all services..."
        cd /opt/portainer && docker compose up -d
        cd /opt/restreamer && docker compose up -d
        echo "All services started"
        ;;
    stop)
        echo "Stopping all services..."
        cd /opt/portainer && docker compose down
        cd /opt/restreamer && docker compose down
        echo "All services stopped"
        ;;
    restart)
        echo "Restarting all services..."
        cd /opt/portainer && docker compose restart
        cd /opt/restreamer && docker compose restart
        echo "All services restarted"
        ;;
    status)
        echo "Service status:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        ;;
    logs)
        echo "Portainer logs:"
        docker logs portainer --tail 20
        echo
        echo "Restreamer logs:"
        docker logs restreamer --tail 20
        ;;
    update)
        echo "Updating all services..."
        cd /opt/portainer && docker compose pull && docker compose up -d
        cd /opt/restreamer && docker compose pull && docker compose up -d
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
    
    chmod +x $PORTAINER_DATA_DIR/manage-services.sh
    
    # Create backup script
    cat > $PORTAINER_DATA_DIR/backup-services.sh << 'EOF'
#!/bin/bash

# Docker Services Backup Script

BACKUP_DIR="/opt/backups"
DATE=$(date +%Y%m%d_%H%M%S)

echo "Creating backup directory..."
mkdir -p $BACKUP_DIR

echo "Backing up Portainer data..."
docker run --rm -v portainer_portainer_data:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/portainer-$DATE.tar.gz -C /data .

echo "Backing up Restreamer data..."
tar czf $BACKUP_DIR/restreamer-$DATE.tar.gz /mnt/restreamer/db

echo "Backup completed: $BACKUP_DIR"
ls -la $BACKUP_DIR/*$DATE*
EOF
    
    chmod +x $PORTAINER_DATA_DIR/backup-services.sh
    
    print_success "Management scripts created"
}

# =============================================================================
# UCI CONFIGURATION FUNCTIONS
# =============================================================================

# Function to backup UCI configuration
backup_uci_config() {
    print_status "Creating backup of current UCI configuration..."
    
    BACKUP_DIR="/tmp/uci_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup all UCI config files
    cp -r /etc/config/* "$BACKUP_DIR/" 2>/dev/null || true
    
    # Backup current UCI state
    uci show > "$BACKUP_DIR/uci_show_backup.txt" 2>/dev/null || true
    
    print_success "UCI configuration backed up to: $BACKUP_DIR"
    echo "Backup location: $BACKUP_DIR"
}

# Function to configure UCI system settings
configure_uci_system() {
    print_status "Configuring UCI system settings..."
    
    # System configuration
    uci set system.system.hostname="$TARGET_HOSTNAME"
    uci set system.system.timezone="GMT-8"
    uci set system.system.zonename="(GMT+08:00) Beijing, Chongqing, Hong Kong, Urumqi"
    uci set system.system.dual_sim='0'
    uci set system.system.sms_password='admin'
    uci set system.system.model='TG451-STD'
    uci set system.system.enable_212='1'
    
    # NTP configuration
    uci set system.ntp.server='0.openwrt.pool.ntp.org' '1.openwrt.pool.ntp.org' '2.openwrt.pool.ntp.org' '3.openwrt.pool.ntp.org'
    uci set system.ntp.enabled='1'
    uci set system.ntp.enable_server='0'
    
    # Access configuration
    uci set system.access.enable_telnet='1'
    uci set system.access.enable_ssh='0'
    
    uci commit system
    print_success "UCI system configuration completed"
}

# Function to configure UCI user password
configure_uci_password() {
    print_status "Configuring UCI user password..."
    
    # Set root password using UCI
    uci set system.system.password='1qaz2wsx'
    
    # Alternative method using passwd command
    echo "root:1qaz2wsx" | chpasswd 2>/dev/null || {
        print_warning "Could not set password using chpasswd, trying alternative method..."
        # Use UCI to set password hash
        PASSWORD_HASH=$(echo -n "1qaz2wsx" | openssl passwd -1 -stdin 2>/dev/null || echo "")
        if [ -n "$PASSWORD_HASH" ]; then
            uci set system.system.password="$PASSWORD_HASH"
            print_success "Password hash set via UCI"
        else
            print_warning "Could not generate password hash, password may need to be set manually"
        fi
    }
    
    # Commit UCI changes
    uci commit system
    
    # Also set password in /etc/shadow if possible
    if [ -w "/etc/shadow" ]; then
        PASSWORD_HASH=$(echo -n "1qaz2wsx" | openssl passwd -1 -stdin 2>/dev/null || echo "")
        if [ -n "$PASSWORD_HASH" ]; then
            sed -i "s|^root:.*|root:$PASSWORD_HASH:0:0:99999:7:::|" /etc/shadow 2>/dev/null || true
            print_success "Password set in /etc/shadow"
        fi
    fi
    
    print_success "UCI user password configuration completed"
    print_status "Username: admin/root"
    print_status "Password: 1qaz2wsx"
}

# Function to configure UCI network interfaces
configure_uci_network() {
    print_status "Configuring UCI network interfaces..."
    
    # Loopback interface
    uci set network.loopback=interface
    uci set network.loopback.ifname='lo'
    uci set network.loopback.proto='static'
    uci set network.loopback.ipaddr='127.0.0.1'
    uci set network.loopback.netmask='255.0.0.0'
    
    # LAN interface (bridge)
    uci set network.lan=interface
    uci set network.lan.type='bridge'
    uci set network.lan.proto='static'
    uci set network.lan.netmask="$TARGET_LAN_NETMASK"
    uci set network.lan.macaddr="$TARGET_LAN_MAC"
    uci set network.lan.ifname='eth0 eth1'
    uci set network.lan.ipaddr="$TARGET_LAN_IP"
    uci set network.lan.dns='8.8.8.8'
    
    # WAN interface (LTE)
    uci set network.wan=interface
    uci set network.wan.ifname='usb0'
    uci set network.wan.disabled='0'
    uci set network.wan.proto='lte'
    uci set network.wan.service='AUTO'
    uci set network.wan.auth_type='none'
    uci set network.wan.wan_multi='1'
    uci set network.wan.apn="$TARGET_APN"
    
    uci commit network
    print_success "UCI network configuration completed"
}

# Function to configure UCI wireless
configure_uci_wireless() {
    print_status "Configuring UCI wireless settings..."
    
    # WiFi interface
    uci set wireless.wlan0=wifi-iface
    uci set wireless.wlan0.enabled='1'
    uci set wireless.wlan0.channel="$TARGET_WIFI_CHANNEL"
    uci set wireless.wlan0.hwmode='g'
    uci set wireless.wlan0.type='bcmdhd'
    uci set wireless.wlan0.encryption='wpa2psk'
    uci set wireless.wlan0.ssid="$TARGET_WIFI_SSID"
    uci set wireless.wlan0.key="$TARGET_WIFI_PASSWORD"
    
    uci commit wireless
    print_success "UCI wireless configuration completed"
}

# Function to restart UCI services
restart_uci_services() {
    print_status "Restarting UCI services..."
    
    # Restart network
    /etc/init.d/network restart
    
    # Restart wireless
    /etc/init.d/network restart
    
    print_success "UCI services restarted"
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

# Function to verify all installations
verify_installation() {
    print_status "Verifying installation..."
    
    # Wait for services to start
    sleep 10
    
    # Check Docker service
    if systemctl is-active --quiet docker; then
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
    
    # Apply Docker group membership for verification
    newgrp docker << EOFNEWGRP
    # Check containers
    if docker ps | grep -q portainer; then
        print_success "Portainer container is running"
    else
        print_error "Portainer container is not running"
        return 1
    fi
    
    if docker ps | grep -q restreamer; then
        print_success "Restreamer container is running"
    else
        print_error "Restreamer container is not running"
        return 1
    fi
EOFNEWGRP
    
    # Get server IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    print_success "Installation verification completed"
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
    echo -e "${BLUE}Docker containers:${NC} docker ps"
    echo -e "${BLUE}Docker logs:${NC} docker logs [container_name]"
    echo -e "${BLUE}Tailscale status:${NC} sudo tailscale status"
    echo -e "${BLUE}Management script:${NC} /opt/portainer/manage-services.sh"
}

# Function to prompt for reboot
prompt_reboot() {
    echo
    print_warning "Installation completed successfully!"
    print_status "A system reboot is recommended to ensure all changes take effect."
    echo
    read -p "Do you want to reboot now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Rebooting system..."
        sudo reboot
    else
        print_status "Reboot skipped. Please reboot manually when convenient."
        print_warning "Run 'sudo reboot' when ready to complete the setup."
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
    echo "  --skip-uci          Skip UCI configuration"
    echo "  --skip-docker       Skip Docker services setup"
    echo "  --skip-nodered      Skip Node-RED setup"
    echo "  --skip-tailscale    Skip Tailscale setup"
    echo "  --fix-nodered       Fix Node-RED flow issues"
    echo "  --check-flows       Check and validate Node-RED flows"
    echo
    echo "This script will install:"
    echo "  • Node-RED with custom flows and validation"
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
            --auto|-y|--yes)
                print_status "Auto-run mode enabled. Proceeding with installation..."
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
    
    # Check if OpenWrt and get UCI configuration
    IS_OPENWRT=false
    if check_openwrt; then
        IS_OPENWRT=true
        if get_uci_configuration; then
            print_success "UCI configuration will be applied"
        else
            print_warning "UCI configuration skipped"
        fi
    else
        print_warning "Not an OpenWrt system. UCI configuration will be skipped."
    fi
    
    # Part 1: Node-RED and Tailscale Setup
    print_section "PART 1: NODE-RED AND TAILSCALE SETUP"
    copy_flows_to_script
    update_system
    install_dependencies
    install_nvm
    install_nodejs
    install_nodered
    install_nodered_nodes
    create_nodered_systemd_service
    start_nodered
    import_flows
    install_tailscale
    configure_serial_ports
    
    # Part 2: Docker Services Setup
    print_section "PART 2: DOCKER SERVICES SETUP"
    install_docker
    create_docker_directories
    create_portainer_compose
    create_restreamer_compose
    start_docker_services
    create_management_scripts
    
    # Part 3: UCI Configuration (if OpenWrt)
    if [ "$IS_OPENWRT" = true ]; then
        print_section "PART 3: UCI CONFIGURATION"
        backup_uci_config
        configure_uci_system
        configure_uci_password
        configure_uci_network
        configure_uci_wireless
        restart_uci_services
    fi
    
    # Final verification
    print_section "FINAL VERIFICATION"
    verify_installation
    
    echo
    echo "=========================================="
    print_success "Complete Infrastructure Setup Completed!"
    echo "=========================================="
    echo
    print_warning "IMPORTANT: Docker group membership has been applied automatically during setup."
    print_warning "If you encounter permission issues in future sessions, run: newgrp docker"
    echo
    print_status "Management scripts created:"
    echo "  - /opt/portainer/manage-services.sh"
    echo "  - /opt/portainer/backup-services.sh"
    echo
    print_status "Next steps:"
    echo "  1. Access Node-RED at: http://$(hostname -I | awk '{print $1}'):1880"
    echo "  2. Access Portainer at: http://$(hostname -I | awk '{print $1}'):9000"
    echo "  3. Access Restreamer at: http://$(hostname -I | awk '{print $1}'):8080"
    echo "  4. Configure Tailscale with: sudo tailscale up"
    if [ "$IS_OPENWRT" = true ]; then
        echo "  5. UCI configuration applied with hostname: $TARGET_HOSTNAME"
        echo "  6. WiFi SSID: $TARGET_WIFI_SSID"
        echo "  7. LAN IP: $TARGET_LAN_IP"
    fi
    echo "  8. Use management scripts for service control"
    
    # Prompt for reboot
    prompt_reboot
}

# Run main function
main "$@"
