# Loranet Complete Infrastructure Setup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Author: Aqmar](https://img.shields.io/badge/Author-Aqmar-blue.svg)](https://github.com/loranet)
[![OpenWrt Compatible](https://img.shields.io/badge/OpenWrt-Compatible-green.svg)](https://openwrt.org/)

A comprehensive infrastructure setup script that combines Node-RED, Tailscale, Docker services, and UCI configuration for OpenWrt systems. This script provides a complete solution for setting up a full-featured router/edge device.

## 🚀 Quick Start

### One-Line Installation (Recommended)

```bash
curl -sSL https://raw.githubusercontent.com/Loranet-Technologies/bivicom-radar/main/install.sh | bash -s -- --auto
```

This command will:
- Download and run the installation script automatically
- Use default configuration values (no user prompts)
- Install all services: Node-RED, Tailscale, Docker, Portainer, and Restreamer
- Configure UCI settings for OpenWrt systems
- Set up complete infrastructure in one command

### Alternative Installation Methods

#### Interactive Installation (with prompts)
```bash
curl -sSL https://raw.githubusercontent.com/Loranet-Technologies/bivicom-radar/main/install.sh | bash
```

#### Manual Installation
```bash
# Download the setup script
curl -sSL https://raw.githubusercontent.com/Loranet-Technologies/bivicom-radar/main/complete_infrastructure_setup.sh -o setup.sh

# Make executable and run
sudo chmod +x setup.sh
./setup.sh
```

## 📋 Features

### Infrastructure Services
- ✅ **Node-RED**: IoT platform with pre-configured flows and validation
- ✅ **Flow Management**: Automatic backup, validation, and restoration
- ✅ **Error Recovery**: Enhanced error handling and automatic fixes
- ✅ **Tailscale**: VPN connectivity
- ✅ **Docker**: Container runtime
- ✅ **Portainer**: Container management UI
- ✅ **Restreamer**: Video streaming service

### UCI Configuration (OpenWrt)
- ✅ **Interactive Configuration**: User prompts for customization
- ✅ **System Configuration**: Hostname, timezone, NTP
- ✅ **User Password**: Admin/root password configuration
- ✅ **Wireless Configuration**: WiFi access point setup
- ⚠️ **Network Configuration**: Network interface commit only (no network settings applied)
- ✅ **Service Management**: Network services restart

## 🆕 New Features (v2.2)

### Pre-Deployment System Preparation
- **Hardened Package Repair**: Automatic `dpkg --configure -a` and `apt-get install -f -y` before installation
- **dnsmasq Repair**: Detects and fixes half-installed dnsmasq packages automatically
- **SQLite Dependencies**: Installs `libsqlite3-dev` and `sqlite3` for Node-RED SQLite node compilation
- **Non-Interactive Mode**: Forces `DEBIAN_FRONTEND=noninteractive` to prevent debconf dialog issues
- **Comprehensive Error Handling**: Each preparation step has individual error handling and logging
- **Skip Option**: `--skip-pre-deploy` to bypass pre-deployment preparation if needed

### Enhanced Restreamer Configuration
- **Fixed ARM Architecture Detection**: Correct image selection for ARM systems (aarch64 for armv7l)
- **Simplified Network Configuration**: Removed custom bridge network to prevent isolation issues
- **Removed Problematic tmpfs**: Eliminated tmpfs configuration that could cause memory issues
- **Better Error Handling**: Enhanced container startup with detailed error reporting and logs
- **Improved Debugging**: Clear success/failure indicators and automatic log checking

### Enhanced Package Management
- **Broken Package Detection**: Automatic detection and repair of broken package states
- **System Dependencies**: Ensures all required build dependencies are installed
- **Package Conflict Resolution**: Resolves package conflicts before any new installations
- **Clean Package Lists**: Updates and cleans package lists for fresh installations

### Previous Features (v2.1)

### Enhanced Security and Permissions
- **Sudo Requirements**: All Docker and UCI commands now use `sudo` for proper elevated privileges
- **Consistent Permissions**: Removed `newgrp docker` dependency in favor of direct `sudo` usage
- **Better Error Handling**: Improved Docker Compose startup with proper permission checks
- **Security Hardening**: All system administration commands properly escalated

### Previous Features (v2.0)

### Enhanced Node-RED Flow Management
- **Automatic Backup**: Creates timestamped backups before any changes
- **Flow Validation**: Checks for corrupted or empty flow files
- **Smart Restoration**: Automatically restores from backups when issues detected
- **Error Detection**: Identifies and reports flow problems
- **Recovery Tools**: Command-line options to fix flow issues

### Command Line Options
```bash
# Show help
./complete_infrastructure_setup.sh --help

# Auto-run without confirmation (recommended for automated deployments)
./complete_infrastructure_setup.sh --auto

# Force reinstall even if services exist
./complete_infrastructure_setup.sh --force

# Fix Node-RED flow issues
./complete_infrastructure_setup.sh --fix-nodered

# Check flow validity
./complete_infrastructure_setup.sh --check-flows

# Test flow download connectivity
./complete_infrastructure_setup.sh --test-download

# Skip specific components
./complete_infrastructure_setup.sh --skip-docker --skip-tailscale --skip-pre-deploy

# Skip pre-deployment system preparation
./complete_infrastructure_setup.sh --skip-pre-deploy

# Skip UCI configuration (for non-OpenWrt systems)
./complete_infrastructure_setup.sh --skip-uci
```

### Flow Recovery Commands
```bash
# Fix blank or corrupted flows
./complete_infrastructure_setup.sh --fix-nodered

# Validate existing flows
./complete_infrastructure_setup.sh --check-flows
```

## 🛠️ Installation Process

### Installation Modes
- **Interactive Mode**: Prompts for UCI configuration (hostname, etc.)
- **Auto-Run Mode**: Uses default values, minimal prompts (`--auto` flag)

### Pre-Deployment System Preparation (New in v2.2)
1. **Package Repair**: `dpkg --configure -a` and `apt-get install -f -y`
2. **dnsmasq Repair**: Detects and fixes half-installed dnsmasq packages
3. **System Dependencies**: Installs `libsqlite3-dev`, `sqlite3`, `build-essential`
4. **Package Lists**: Cleans and updates package lists
5. **Non-Interactive Mode**: Prevents debconf dialog issues

### Part 1: UCI Configuration (OpenWrt Only) - Runs First
1. **Configuration Backup**: Current UCI backup
2. **System Configuration**: Hostname, timezone, NTP
3. **User Password**: Admin/root password setup
4. **Network Configuration**: Network interface commit (no network settings applied)
5. **Wireless Configuration**: WiFi access point
6. **Service Restart**: Network services restart

### Part 2: Node-RED and Tailscale Setup
1. **Flow Backup**: Copy existing Node-RED flows to script directory
2. **System Update**: Updates packages and dependencies
3. **NVM Installation**: Node Version Manager setup
4. **Node.js Installation**: Node.js v18 installation
5. **Node-RED Installation**: Global Node-RED installation
6. **Node-RED Nodes**: Required nodes installation (ffmpeg, queue-gate, sqlite, serialport)
7. **Systemd Service**: Node-RED service configuration
8. **Flow Import**: Local flows from script directory
9. **Tailscale Installation**: VPN service setup
10. **Serial Ports**: Permission configuration

### Part 3: Docker Services Setup
1. **Docker Installation**: Docker CE with Compose
2. **Directory Creation**: Required directories setup
3. **Portainer Configuration**: Container management UI
4. **Restreamer Configuration**: Video streaming service
5. **Service Startup**: Docker containers launch
6. **Management Scripts**: Service control tools

## 🔧 Configuration Details

### Node-RED Configuration
- **Version**: Node.js 18
- **Port**: 1880
- **Service**: systemd managed
- **Flows**: Local flows from current server
- **Nodes**: ffmpeg, queue-gate, sqlite, serialport support

### Docker Services
- **Portainer**: Ports 9000 (HTTP), 9443 (HTTPS)
- **Restreamer**: Port 8080 (Enhanced in v2.2)
  - **Architecture Detection**: Fixed ARM image selection (aarch64 for armv7l)
  - **Network Configuration**: Simplified to default bridge (no isolation)
  - **Error Handling**: Enhanced startup with detailed logging
  - **Memory Optimization**: Removed problematic tmpfs configuration
- **Architecture**: Auto-detected (ARM64/x86_64/ARMv7)
- **Data Persistence**: Configured volumes with proper permissions
- **Docker Compose**: Uses modern `docker compose` V2 syntax

### UCI Configuration (OpenWrt)
- **System**: NTP, timezone, hostname
- **User**: Admin password: 1qaz2wsx
- **Wireless**: WPA2-PSK encryption
- **Network**: Interface commit only (no network settings applied)
- **Service**: Network services restart

## 🌐 Service Access

After installation, access services at:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Node-RED** | http://[IP]:1880 | None |
| **Portainer** | http://[IP]:9000 | Setup on first access |
| **Portainer HTTPS** | https://[IP]:9443 | Setup on first access |
| **Restreamer** | http://[IP]:8080 | admin / L@ranet2025 |
| **WiFi Network** | [Hostname] | [User Password] |
| **Admin Access** | SSH/Telnet | admin / 1qaz2wsx |

## 📊 Node-RED Flows

### Flow Tabs
1. **radar03**: Main radar data processing
2. **modbusSolar**: Solar/battery monitoring via Modbus
3. **pushToLedDisplay**: LED display control
4. **Recording**: Video recording (disabled)
5. **Data Handling**: Data processing and storage
6. **Decode Data**: Data decoding functions

### Key Features
- **TCP Client**: Connects to 192.168.14.11:8998 for radar data
- **Serial Communication**: Multiple serial ports (ttyS0, ttyS3)
- **MQTT Publishing**: Multiple MQTT brokers
- **Data Storage**: SQLite database and file storage
- **Data Decoding**: Custom functions for radar data parsing

## 🔧 Management Commands

### Service Management
```bash
# Node-RED
sudo systemctl status nodered
sudo systemctl restart nodered
sudo journalctl -u nodered -f

# Docker Services (all commands use sudo)
sudo docker ps
sudo docker logs [container_name]
sudo docker restart [container_name]

# Management Scripts
/home/$USER/management-scripts/manage-services.sh status
/home/$USER/management-scripts/manage-services.sh restart
/home/$USER/management-scripts/manage-services.sh logs

# Tailscale
sudo tailscale status
sudo tailscale up
```

### UCI Management (OpenWrt)
```bash
# View configuration (requires sudo)
sudo uci show
sudo uci show network
sudo uci show wireless

# Modify configuration (requires sudo)
sudo uci set system.system.hostname='new-hostname'
sudo uci commit
sudo /etc/init.d/network restart
```

## 📁 Repository Structure

```
complete-infrastructure-setup/
├── complete_infrastructure_setup.sh    # Main setup script (33.2KB)
├── install.sh                          # Curl installation script
├── nodered_flows/                      # Node-RED flow backup
│   ├── flows.json                     # Node-RED flows (62.2KB)
│   └── package.json                   # Node dependencies
├── README.md                           # This file
└── .gitignore                          # Git ignore rules
```

## 🎯 System Requirements

### Supported Operating Systems
- **Ubuntu**: 18.04+ (recommended)
- **Debian**: 9+ (recommended)
- **OpenWrt**: 19.07+ (for UCI configuration)

### User Requirements
- **Sudo Access**: Script requires sudo privileges for system administration
- **Non-root User**: Script should NOT be run as root (will exit with error)
- **Docker Group**: Docker group membership applied automatically during installation

### Hardware Requirements
- **RAM**: Minimum 2GB (4GB recommended)
- **Storage**: Minimum 10GB free space
- **Network**: Internet connection for downloads
- **Architecture**: x86_64, ARM64, ARMv7

## 🔒 Security Features

### Network Security
- **Firewall**: Comprehensive UCI firewall rules
- **VPN**: Tailscale secure connectivity
- **Container Isolation**: Docker network isolation
- **Access Control**: Proper service permissions

### Service Security
- **Node-RED**: Local access only
- **Portainer**: Web-based authentication
- **Restreamer**: Username/password protection
- **SSH**: Configurable access control
- **Sudo Usage**: All system commands use elevated privileges
- **Permission Management**: Proper file and directory permissions applied

## 🚨 Troubleshooting

### Common Issues

#### Pre-Deployment Preparation Issues (v2.2)
```bash
# Check if pre-deployment preparation completed successfully
# Look for these messages in the output:
# ✓ Command completed successfully
# ✓ Pre-deployment system preparation completed

# If preparation failed, check system packages
sudo dpkg --configure -a
sudo apt-get install -f -y
sudo apt-get clean && sudo apt-get update

# Skip pre-deployment if needed
./complete_infrastructure_setup.sh --skip-pre-deploy
```

#### Restreamer Container Issues (v2.2)
```bash
# Check Restreamer container status
sudo docker ps -a | grep restreamer

# Check Restreamer logs for specific errors
sudo docker logs restreamer --tail 50

# Check architecture and image
uname -m
sudo docker images | grep restreamer

# Restart Restreamer manually
cd /data/restreamer
sudo docker compose down
sudo docker compose up -d

# Check directory permissions
ls -la /data/restreamer/
ls -la /data/restreamer/db/
```

#### Docker Compose Issues
```bash
# Check if docker compose is available
sudo docker compose version

# If not available, check legacy version
sudo docker-compose --version

# All Docker commands use sudo for proper permissions
sudo docker ps
sudo docker logs [container_name]
sudo docker compose up -d

# Docker group membership is applied automatically during installation
# but sudo is recommended for consistent access
```

#### Node-RED Service Issues
```bash
# Check service status
sudo systemctl status nodered

# Check logs
sudo journalctl -u nodered -f

# Restart service
sudo systemctl restart nodered

# Fix Node-RED flow issues
./complete_infrastructure_setup.sh --fix-nodered
```

#### UCI Configuration Issues
```bash
# Check UCI syntax (requires sudo)
sudo uci show

# Restore from backup (requires sudo)
sudo cp -r /tmp/uci_backup_*/* /etc/config/
sudo uci commit
sudo /etc/init.d/network restart
```

#### Package Management Issues
```bash
# Fix broken packages manually
sudo dpkg --configure -a
sudo apt-get install -f -y

# Check for half-installed dnsmasq
dpkg -l | grep dnsmasq
sudo apt-get install --reinstall -y dnsmasq

# Install missing SQLite dependencies
sudo apt-get install -y libsqlite3-dev sqlite3 build-essential
```

## 📚 Documentation

- [Complete Setup Guide](README.md) - This file
- [Node-RED Flows Integration](Node-RED_Flows_Integration.md) - Flow documentation
- [UCI Configuration Guide](UCI_Configuration_Analysis.md) - UCI setup details

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**Aqmar** - *Initial work* - [Loranet](https://github.com/loranet)

## 🙏 Acknowledgments

- OpenWrt community for UCI configuration system
- Node-RED community for IoT platform
- Docker community for containerization
- Tailscale for VPN solution

## 📞 Support

For support and questions:
- Create an issue in this repository
- Contact: [Loranet GitHub](https://github.com/loranet)

---

**Repository**: https://github.com/Loranet-Technologies/bivicom-radar  
**Author**: Aqmar  
**Version**: 2.2  
**Last Updated**: January 2025  

*This script provides a complete solution for setting up a full-featured router/edge device with infrastructure services and UCI configuration. Version 2.2 includes enhanced pre-deployment preparation, improved Restreamer configuration, and comprehensive error handling for maximum reliability.*