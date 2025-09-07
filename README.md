# Loranet Complete Infrastructure Setup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Author: Aqmar](https://img.shields.io/badge/Author-Aqmar-blue.svg)](https://github.com/loranet)
[![OpenWrt Compatible](https://img.shields.io/badge/OpenWrt-Compatible-green.svg)](https://openwrt.org/)

A comprehensive infrastructure setup script that combines Node-RED, Tailscale, Docker services, and UCI configuration for OpenWrt systems. This script provides a complete solution for setting up a full-featured router/edge device.

## 🚀 Quick Start

### One-Line Installation

```bash
curl -sSL https://raw.githubusercontent.com/Loranet-Technologies/bivicom-radar/main/install.sh | bash
```

### Manual Installation

```bash
# Download the setup script
curl -sSL https://raw.githubusercontent.com/Loranet-Technologies/bivicom-radar/main/complete_infrastructure_setup.sh -o setup.sh

# Make executable and run
chmod +x setup.sh
./setup.sh
```

## 📋 Features

### Infrastructure Services
- ✅ **Node-RED**: IoT platform with pre-configured flows
- ✅ **Tailscale**: VPN connectivity
- ✅ **Docker**: Container runtime
- ✅ **Portainer**: Container management UI
- ✅ **Restreamer**: Video streaming service

### UCI Configuration (OpenWrt)
- ✅ **Interactive Configuration**: User prompts for customization
- ✅ **Network Setup**: LAN/WAN interface configuration
- ✅ **Wireless Configuration**: WiFi access point setup
- ✅ **System Configuration**: Hostname, timezone, NTP
- ✅ **User Password**: Admin/root password configuration
- ✅ **Firewall Rules**: Comprehensive security configuration

## 🛠️ Installation Process

### Part 1: Node-RED and Tailscale Setup
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

### Part 2: Docker Services Setup
1. **Docker Installation**: Docker CE with Compose
2. **Directory Creation**: Required directories setup
3. **Portainer Configuration**: Container management UI
4. **Restreamer Configuration**: Video streaming service
5. **Service Startup**: Docker containers launch
6. **Management Scripts**: Service control tools

### Part 3: UCI Configuration (OpenWrt Only)
1. **Configuration Backup**: Current UCI backup
2. **System Configuration**: Hostname, timezone, NTP
3. **User Password**: Admin/root password setup
4. **Network Configuration**: LAN/WAN interfaces
5. **Wireless Configuration**: WiFi access point
6. **Service Restart**: Network services restart

## 🔧 Configuration Details

### Node-RED Configuration
- **Version**: Node.js 18
- **Port**: 1880
- **Service**: systemd managed
- **Flows**: Local flows from current server
- **Nodes**: ffmpeg, queue-gate, sqlite, serialport support

### Docker Services
- **Portainer**: Ports 9000 (HTTP), 9443 (HTTPS)
- **Restreamer**: Port 8080
- **Architecture**: Auto-detected (ARM64/x86_64)
- **Data Persistence**: Configured volumes

### UCI Configuration (OpenWrt)
- **Network**: Bridge LAN, LTE WAN
- **Wireless**: WPA2-PSK encryption
- **Firewall**: Comprehensive rules
- **System**: NTP, timezone, hostname
- **User**: Admin/root password: 1qaz2wsx

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

# Docker Services
/opt/portainer/manage-services.sh status
/opt/portainer/manage-services.sh restart
/opt/portainer/manage-services.sh logs

# Tailscale
sudo tailscale status
sudo tailscale up
```

### UCI Management (OpenWrt)
```bash
# View configuration
uci show
uci show network
uci show wireless

# Modify configuration
uci set system.system.hostname='new-hostname'
uci commit
/etc/init.d/network restart
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

## 🚨 Troubleshooting

### Common Issues

#### Docker Permission Issues
```bash
# Apply Docker group membership
newgrp docker

# Or logout and login again
```

#### Node-RED Service Issues
```bash
# Check service status
sudo systemctl status nodered

# Check logs
sudo journalctl -u nodered -f

# Restart service
sudo systemctl restart nodered
```

#### UCI Configuration Issues
```bash
# Check UCI syntax
uci show

# Restore from backup
cp -r /tmp/uci_backup_*/* /etc/config/
uci commit
/etc/init.d/network restart
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
**Version**: 1.0.0  
**Last Updated**: September 8, 2025  

*This script provides a complete solution for setting up a full-featured router/edge device with infrastructure services and UCI configuration.*