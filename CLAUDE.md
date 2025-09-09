# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains a complete infrastructure setup system for OpenWrt-based devices and Linux systems, focusing on radar data processing, IoT connectivity, and containerized services. The project is designed for Bivicom radar systems and similar edge computing deployments.

### Version Information
- **Script Version**: 2.0 (2273 lines)
- **Author**: Aqmar (Loranet Technologies)
- **Repository**: https://github.com/Loranet-Technologies/bivicom-radar
- **License**: MIT
- **Last Updated**: December 2024
- **Node.js Version**: 18 (managed via NVM v0.39.1)

### Compatibility Matrix
| Platform | Version | UCI Support | Status |
|----------|---------|-------------|---------|
| Ubuntu | 18.04+ | No | ✅ Fully Supported |
| Debian | 9+ | No | ✅ Fully Supported |
| OpenWrt | 19.07+ | Yes | ✅ Full UCI Integration |
| Architecture | x86_64, ARM64, ARMv7 | - | ✅ Multi-arch Support |

## Core Architecture

### Main Components
- **Infrastructure Setup Scripts**: Comprehensive deployment automation for complete system setup
- **Node-RED Integration**: IoT platform with radar-specific data processing flows
- **Docker Services**: Containerized applications (Portainer, Restreamer)
- **UCI Configuration**: OpenWrt system configuration automation
- **Network Services**: Tailscale VPN integration and network management

### Key Scripts
- `complete_infrastructure_setup.sh`: Main deployment script with full infrastructure setup
- `install.sh`: Curl-based installation wrapper for cloud deployment
- `test_flow_download.sh`: Node-RED flow validation and download testing
- `setup_github.sh`: Repository setup and GitHub integration

## Common Commands

### Infrastructure Deployment
```bash
# One-line cloud installation (recommended)
curl -sSL https://raw.githubusercontent.com/Loranet-Technologies/bivicom-radar/main/install.sh | bash -s -- --auto

# Interactive installation with prompts
curl -sSL https://raw.githubusercontent.com/Loranet-Technologies/bivicom-radar/main/install.sh | bash

# Local installation
chmod +x complete_infrastructure_setup.sh
./complete_infrastructure_setup.sh

# Auto-run mode (no prompts)
./complete_infrastructure_setup.sh --auto

# Component-specific installation
./complete_infrastructure_setup.sh --skip-docker --skip-tailscale
./complete_infrastructure_setup.sh --skip-uci --skip-nodered
./complete_infrastructure_setup.sh --skip-pre-deploy
```

### Complete Command Line Options
```bash
# Help and version
./complete_infrastructure_setup.sh --help          # Show help message
./complete_infrastructure_setup.sh --version       # Show version info

# Installation modes
./complete_infrastructure_setup.sh --auto          # Auto-run without confirmation
./complete_infrastructure_setup.sh --force         # Force reinstall even if services exist

# Component control
./complete_infrastructure_setup.sh --skip-uci           # Skip UCI configuration
./complete_infrastructure_setup.sh --skip-docker       # Skip Docker services setup
./complete_infrastructure_setup.sh --skip-nodered      # Skip Node-RED setup
./complete_infrastructure_setup.sh --skip-tailscale    # Skip Tailscale setup
./complete_infrastructure_setup.sh --skip-pre-deploy   # Skip pre-deployment preparation

# Maintenance and recovery
./complete_infrastructure_setup.sh --fix-nodered       # Fix Node-RED flow issues
./complete_infrastructure_setup.sh --check-flows       # Check and validate flows
./complete_infrastructure_setup.sh --test-download     # Test flow download connectivity

# Installation wrapper options
./install.sh --download      # Download only (don't run)
./install.sh --auto          # Auto-run without confirmation
```

### Node-RED Management
```bash
# Service management
sudo systemctl status nodered
sudo systemctl restart nodered
sudo journalctl -u nodered -f

# Flow management
./complete_infrastructure_setup.sh --check-flows
./complete_infrastructure_setup.sh --fix-nodered
./test_flow_download.sh
```

### Docker Services Management
```bash
# Container management
docker ps
docker logs [container_name]
docker restart [container_name]

# Management scripts (created during installation)
/home/$USER/management-scripts/manage-services.sh status
/home/$USER/management-scripts/manage-services.sh restart
/home/$USER/management-scripts/backup-services.sh
```

### UCI Configuration (OpenWrt)
```bash
# View configuration
sudo uci show
sudo uci show network
sudo uci show wireless

# Apply changes
sudo uci commit
sudo /etc/init.d/network reload
sudo wifi reload
```

## Service Architecture

### Node-RED Flows (Port 1880)

#### Flow Tabs and Functions
- **radar03** (`c6fdc014f79c73d7`): Main radar data processing pipeline
  - TCP client connections to radar endpoint (192.168.14.11:8998)
  - Binary data parsing and protocol handling
  - Real-time radar signal processing
  
- **modbusSolar** (`d3dfdfd513fb0aa2`): Solar/battery monitoring system
  - Modbus TCP/RTU communication protocols
  - Battery status monitoring and reporting
  - Solar panel performance metrics
  - Energy consumption tracking

- **pushToLedDisplay** (`e8bb17e4f6e25a56`): LED display control system
  - Display message formatting and control
  - Real-time data visualization
  - Status indicator management
  
- **Recording** (`a732ee65fe020f24`): Video recording functions (disabled)
  - FFMPEG integration for video capture
  - Storage management and archiving
  - Currently disabled in production

- **Data Handling** (`e24e7ea8469bab08`): Core data processing hub
  - SQLite database operations
  - File I/O and data persistence
  - Data transformation and filtering
  - Queue management and buffering

- **Decode Data** (`19b3c3c4c41722e8`): Data decoding and parsing
  - Custom protocol decoders
  - Binary data interpretation
  - Message validation and error handling
  - Format conversion utilities

#### Technical Integration Points
```javascript
// Key Node-RED node types in use:
- node-red-contrib-ffmpeg          // Video processing (v0.1.1)
- node-red-contrib-queue-gate      // Flow control (v1.5.5)  
- node-red-node-sqlite            // Database operations (v1.1.0)
- node-red-node-serialport        // Serial communications (v2.0.3)
```

#### Communication Protocols
- **TCP Connections**: Radar data ingestion on port 8998
- **Serial Interfaces**: Multi-port communication (ttyS0, ttyS3)
  - Configured with 0666 permissions via udev rules
  - Automated permission management during setup
- **MQTT Publishing**: Multi-broker data distribution
- **Modbus Integration**: Solar/battery system monitoring
- **SQLite Storage**: Local data persistence and querying

#### Data Flow Architecture
1. **Input Sources**: TCP radar data, serial sensors, Modbus devices
2. **Processing Pipeline**: Data validation → Decoding → Transformation
3. **Storage Layer**: SQLite database, file system persistence
4. **Output Destinations**: LED displays, MQTT brokers, logging systems
5. **Flow Control**: Queue-gate nodes for backpressure management

### Docker Services
- **Portainer** (Ports 9000/9443): Container management interface
- **Restreamer** (Port 8080): Video streaming service with credentials (admin/L@ranet2025)

### Network Services
- **Tailscale VPN**: Secure remote access and device connectivity
- **UCI Network**: OpenWrt interface and wireless configuration

## Development Workflow

### Script Architecture (2273 lines)

#### Main Execution Flow
1. **Argument Processing**: Command line flag parsing and validation
2. **Pre-flight Checks**: Root/sudo verification, architecture detection
3. **Service Status Assessment**: Existing installation detection
4. **UCI Configuration**: OpenWrt system configuration (if applicable)
5. **Infrastructure Deployment**: Node-RED, Docker, Tailscale installation
6. **Service Integration**: Serial ports, management scripts, verification

#### Critical Functions (for code analysis)
- `main()`: Primary execution controller (line 2136)
- `check_existing_services()`: Service detection and status reporting
- `validate_nodered_flows()`: JSON flow validation and integrity checking
- `backup_uci_config()`: OpenWrt configuration backup
- `import_flows()`: Node-RED flow download and import (lines 1089-1241)
- `create_nodered_systemd_service()`: Service file generation
- `verify_installation()`: Final system verification

#### Key Variables and Configuration
```bash
# Version and environment
NODE_VERSION="18"                    # Node.js version
NVM_VERSION="v0.39.1"               # NVM version
TIMEZONE="Asia/Kuala_Lumpur"        # Default timezone

# Service credentials
RESTREAMER_USERNAME="admin"
RESTREAMER_PASSWORD="L@ranet2025"

# Directory structure
NODERED_USER="$USER"
NODERED_HOME="/home/$USER"
PORTAINER_DATA_DIR="/data/portainer"
RESTREAMER_DATA_DIR="/data/restreamer/db"

# UCI Configuration (OpenWrt)
TARGET_HOSTNAME=""                  # Set interactively or via --auto
TARGET_WIFI_SSID=""                # Defaults to hostname
TARGET_WIFI_PASSWORD="1qaz2wsx"    # Default WiFi password
TARGET_WIFI_CHANNEL="10"           # Default WiFi channel
```

#### Integration Points
- **Service Dependencies**: Docker → Portainer/Restreamer, NVM → Node.js → Node-RED
- **Configuration Cascade**: UCI → Network → Wireless → Services
- **Flow Management**: Repository → Local Download → Validation → Import
- **Backup Strategy**: UCI backup → Flow backup → Service state preservation

### Installation Process
1. **Pre-deployment preparation**: System package management and dependency fixes
2. **UCI Configuration** (OpenWrt only): System settings, hostname, wireless setup
3. **Node-RED Setup**: NVM installation, Node.js v18, service configuration
4. **Flow Management**: Download/validation from repository, backup creation
5. **Docker Services**: Container deployment with persistent storage
6. **Service Integration**: Tailscale VPN, serial port configuration

### Code Modification Guidelines
When modifying the main script, consider:
- **Error Handling**: All functions use `set -e` and explicit error checking
- **Logging**: Consistent color-coded status reporting with print_* functions
- **Idempotency**: Services check for existing installations before proceeding
- **Rollback Capability**: All critical operations create backups first
- **Platform Detection**: OpenWrt vs Linux conditional execution paths

### Flow Management Features
- **Automatic Backup**: Timestamped backups before changes
- **Flow Validation**: JSON parsing and tab count verification
- **Smart Restoration**: Automatic recovery from valid backups
- **Error Detection**: File size and structure validation
- **Cloud Download**: Multi-URL redundancy for flow retrieval

### Testing and Validation Framework

#### Automated Testing Commands
```bash
# Test flow download connectivity
./test_flow_download.sh

# Validate existing flows
./complete_infrastructure_setup.sh --check-flows

# Fix flow corruption issues
./complete_infrastructure_setup.sh --fix-nodered

# Test complete installation in cloud mode
./complete_infrastructure_setup.sh --test-download
```

#### Flow Validation Mechanics
The system includes comprehensive flow validation:
```bash
# Flow validation criteria:
1. File exists and is readable
2. File size > 1000 bytes (prevents empty/corrupted files)
3. Valid JSON structure parsing
4. Contains at least one flow tab (type: 'tab')
5. Node-RED dependency validation

# Validation functions:
validate_nodered_flows()     # Main validation function
check_nodered_flows()        # Service-level flow checking
restore_nodered_flows()      # Backup restoration logic
```

#### Test Infrastructure Components
- **Download Testing**: Multi-URL redundancy testing for GitHub repository access
- **JSON Validation**: Python-based JSON parsing and structure verification  
- **Service Health Checks**: Systemd service status verification
- **Container Status**: Docker container health monitoring
- **Network Connectivity**: DNS and repository accessibility testing

#### Quality Assurance Features
- **Backup Strategy**: Automatic timestamped backups before any changes
- **Rollback Capability**: Automatic restoration from valid backups on failure
- **Error Detection**: File corruption and network failure detection
- **Recovery Procedures**: Multi-level fallback mechanisms
- **Idempotency**: Safe re-execution without side effects

#### Installation Status Reporting
```bash
# Generated status files:
/home/$USER/installation_status_[timestamp].md    # Detailed installation report
/home/$USER/installation_status_latest.md         # Latest status (symlink)

# Status includes:
- Service status and URLs
- Credential information
- Backup locations  
- Management command reference
- Troubleshooting procedures
```

## Configuration Management

### System Requirements
- **Ubuntu/Debian**: 18.04+ (primary support)
- **OpenWrt**: 19.07+ (for UCI configuration)
- **Architecture**: x86_64, ARM64, ARMv7
- **Resources**: 2GB RAM minimum, 10GB storage

### Default Configuration
- **Node.js Version**: 18 (via NVM)
- **Admin Password**: 1qaz2wsx (OpenWrt systems)
- **WiFi Channel**: 10 (configurable)
- **Timezone**: Asia/Kuala_Lumpur
- **Data Directories**: /data/portainer, /data/restreamer

### Security Features

#### Default Credentials (CHANGE IN PRODUCTION)
```bash
# OpenWrt System Access
Username: admin
Password: 1qaz2wsx                     # DEFAULT - CHANGE IMMEDIATELY
SSH/Telnet: Available with above credentials

# Restreamer Service  
URL: http://[IP]:8080
Username: admin
Password: L@ranet2025                  # DEFAULT - CHANGE IMMEDIATELY

# Portainer (set during first access)
URL: http://[IP]:9000 or https://[IP]:9443
Username: [set by user on first login]
Password: [set by user on first login]

# Node-RED (no authentication by default)
URL: http://[IP]:1880
Authentication: None (consider enabling for production)
```

#### Security Configuration Steps
```bash
# 1. Change OpenWrt admin password immediately
uci set system.system.password='your-secure-password'
uci commit system

# 2. Configure Node-RED authentication (recommended)
# Edit ~/.node-red/settings.js and add:
adminAuth: {
    type: "credentials",
    users: [{
        username: "admin",
        password: "$2a$08$zZWtXTja0fB1pzD4sHCMyOCMYz2Z6dNbM6tl8sJogENOMcxWV9DN.",
        permissions: "*"
    }]
}

# 3. Enable firewall rules (OpenWrt)
uci set firewall.nodered=rule
uci set firewall.nodered.src='lan'
uci set firewall.nodered.dest_port='1880'
uci set firewall.nodered.target='ACCEPT'
uci commit firewall

# 4. Configure Tailscale for secure remote access
sudo tailscale up --accept-routes
```

#### Security Best Practices
- **Network Isolation**: Docker containers run in isolated networks
- **Service Authentication**: Portainer and Restreamer have login protection
- **VPN Integration**: Tailscale provides secure remote connectivity
- **User Permissions**: Docker group management for container access
- **File Permissions**: Proper ownership of configuration files
- **UCI Backup**: Configuration rollback capability for OpenWrt systems

#### Credential Storage Locations
```bash
# OpenWrt password hash
/etc/config/system                     # UCI system configuration

# Restreamer credentials (in compose file)
/data/restreamer/docker-compose.yml    # Environment variables

# Node-RED settings (if authentication enabled)
/home/$USER/.node-red/settings.js     # Authentication configuration

# Tailscale authentication
sudo tailscale status                  # Check connection status
```

#### Security Warnings
⚠️ **CRITICAL**: Default passwords are used for rapid deployment. Change all default credentials before production use.

⚠️ **NETWORK**: Node-RED has no authentication by default. Enable authentication for production deployments.

⚠️ **FIREWALL**: Configure appropriate firewall rules for your network environment.

## Troubleshooting Commands

### Service Status Verification
```bash
# Check all services
sudo systemctl status nodered docker

# Container status
docker ps -a

# Network connectivity
ping -c 3 8.8.8.8

# Flow validation
python3 -c "import json; json.load(open('/home/$USER/.node-red/flows.json'))"
```

### Common Issues and Recovery Procedures

#### Installation Failures
```bash
# If installation fails mid-process
./complete_infrastructure_setup.sh --force    # Force reinstall

# If pre-deployment prep fails
sudo dpkg --configure -a && sudo apt-get -f install -y
./complete_infrastructure_setup.sh --skip-pre-deploy

# If specific component fails
./complete_infrastructure_setup.sh --skip-[failed-component]
```

#### Docker Issues
```bash
# Permission problems
newgrp docker                    # Apply group membership immediately
sudo usermod -aG docker $USER    # Add user to docker group
# Then logout/login for permanent fix

# Docker service not running
sudo systemctl enable docker
sudo systemctl start docker

# Container startup failures
docker logs portainer --tail 20
docker logs restreamer --tail 20
cd /data/portainer && docker compose up -d
cd /data/restreamer && docker compose up -d
```

#### Node-RED Flow Problems
```bash
# Flow corruption detection and recovery
./complete_infrastructure_setup.sh --check-flows

# Automatic flow restoration
./complete_infrastructure_setup.sh --fix-nodered

# Manual flow backup restoration
cp /home/$USER/.node-red/.flows.json.backup /home/$USER/.node-red/flows.json
sudo systemctl restart nodered

# Complete flow redownload
./test_flow_download.sh
# If successful, restart Node-RED
```

#### UCI Configuration Issues (OpenWrt)
```bash
# Configuration rollback
cp -r /tmp/uci_backup_*/* /etc/config/
sudo uci commit
sudo /etc/init.d/network restart

# Network service restart failures
sudo wifi reload                    # Try wifi reload first
sudo /etc/init.d/network restart    # Full network restart
sudo reboot                         # Ultimate fallback

# Wireless configuration problems
sudo uci show wireless
sudo uci set wireless.wlan0.disabled='0'
sudo uci commit wireless
sudo wifi reload
```

#### Service Dependency Problems
```bash
# Check service startup order
sudo systemctl list-dependencies nodered
sudo systemctl list-dependencies docker

# Force service restart with dependencies
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl restart nodered

# NVM/Node.js path issues
source ~/.nvm/nvm.sh
nvm use 18
which node                          # Verify Node.js path
```

#### Network Connectivity Issues
```bash
# DNS resolution problems
echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf

# Repository download failures
curl -I https://raw.githubusercontent.com/Loranet-Technologies/bivicom-radar/main/
ping -c 3 raw.githubusercontent.com

# Tailscale connectivity
sudo tailscale status
sudo tailscale up --reset
```

#### Emergency Recovery Procedures
```bash
# Complete system reset (nuclear option)
sudo systemctl stop nodered docker tailscaled
sudo docker system prune -af
sudo rm -rf /data/portainer /data/restreamer
sudo rm -rf /home/$USER/.node-red
sudo rm -rf /home/$USER/.nvm

# Then run fresh installation
./complete_infrastructure_setup.sh --force
```

## File Structure

### Repository Layout
```
bivicom-radar/
├── complete_infrastructure_setup.sh    # Main deployment script (78KB)
├── install.sh                          # Cloud installation wrapper (7KB)
├── test_flow_download.sh               # Flow testing utility (6KB)
├── setup_github.sh                     # Repository management (5KB)
├── nodered_flows/                      # Node-RED configuration
│   ├── flows.json                     # Complete flow definitions (62KB)
│   └── package.json                   # Node-RED dependencies
├── README.md                           # Comprehensive documentation (10KB)
├── LICENSE                             # MIT license
└── .gitignore                          # Git ignore rules
```

### Critical File Locations

#### Installation and Configuration Paths
```bash
# Main installation directory (temporary)
/tmp/loranet-setup/                     # Download location for cloud installs

# Node-RED locations
/home/$USER/.node-red/                  # Node-RED user directory
/home/$USER/.node-red/flows.json       # Active flows
/home/$USER/.node-red/.flows.json.backup   # Standard backup
/home/$USER/.node-red/flows_*.json     # Timestamped backups
/home/$USER/.node-red/package.json     # Node dependencies
/etc/systemd/system/nodered.service    # Service configuration

# Docker service locations
/data/portainer/                       # Portainer data directory
/data/portainer/docker-compose.yml     # Portainer compose file
/data/restreamer/                      # Restreamer config directory
/data/restreamer/db/                   # Restreamer data directory
/data/restreamer/docker-compose.yml    # Restreamer compose file

# Management scripts
/home/$USER/management-scripts/manage-services.sh    # Service control
/home/$USER/management-scripts/backup-services.sh   # Backup script

# UCI backup locations (OpenWrt)
/home/$USER/uci-backup-*/              # UCI configuration backups
/tmp/uci-backup-*/                     # Fallback backup location

# Log locations
/var/log/syslog                        # System logs
journalctl -u nodered                  # Node-RED service logs
journalctl -u docker                   # Docker service logs
docker logs portainer                  # Portainer container logs
docker logs restreamer                 # Restreamer container logs
```

#### Repository and Download Paths
```bash
# Repository structure
nodered_flows/flows.json               # Primary flows (62KB)
nodered_flows/package.json             # Node dependencies
nodered_flows/nodered_flows_backup/    # Backup flows

# Download URLs
https://raw.githubusercontent.com/Loranet-Technologies/bivicom-radar/main/nodered_flows/flows.json
https://raw.githubusercontent.com/Loranet-Technologies/bivicom-radar/main/install.sh
https://raw.githubusercontent.com/Loranet-Technologies/bivicom-radar/main/complete_infrastructure_setup.sh
```

#### Service Access Points
- **Node-RED**: http://[IP]:1880
- **Portainer**: http://[IP]:9000 (HTTP), https://[IP]:9443 (HTTPS)  
- **Restreamer**: http://[IP]:8080 (admin/L@ranet2025)
- **Management Scripts**: /home/$USER/management-scripts/

#### Backup and Recovery Locations
```bash
# Automated backup locations
/home/$USER/nodered_flows_backup/      # Flow backup directory
/home/$USER/backups/                   # Service backup directory (created by backup script)
/home/$USER/installation_status_*.md   # Installation status reports
/home/$USER/installation_status_latest.md  # Latest status (symlink)

# Configuration backups
/etc/config/*                          # UCI configuration files (OpenWrt)
/etc/systemd/system/                   # Service files
~/.nvm/                               # Node Version Manager
```

This infrastructure provides a complete edge computing platform optimized for radar data processing, remote monitoring, and containerized service deployment on OpenWrt and Linux systems.