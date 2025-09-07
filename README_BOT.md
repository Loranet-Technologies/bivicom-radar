# Loranet Deployment Bot

An automated bot that discovers devices on your network, identifies them by MAC address, and deploys the Loranet infrastructure setup via SSH.

## 🚀 Features

- **Network Discovery**: Automatically scans network ranges for active devices
- **MAC Address Validation**: Validates devices against authorized Bivicom manufacturer prefixes
- **Security Logging**: Comprehensive security audit logging for unauthorized access attempts
- **SSH Automation**: Connects to devices using default credentials (admin/admin)
- **Automated Deployment**: Runs the Loranet infrastructure setup script remotely
- **Progress Monitoring**: Real-time monitoring of deployment progress
- **Verification**: Verifies successful deployment of services
- **Reporting**: Generates detailed deployment reports
- **OUI Validation**: Checks against IEEE OUI database for manufacturer verification

## 📋 Prerequisites

- Python 3.6 or higher
- Network access to target devices
- SSH access with admin/admin credentials
- Target devices must be on the same network

## 🛠️ Installation

### Quick Install
```bash
# Download and install the bot
curl -sSL https://raw.githubusercontent.com/Loranet-Technologies/bivicom-radar/main/install_bot.sh | bash
```

### Manual Install
```bash
# Install Python dependencies
pip3 install -r requirements.txt

# Make bot executable
chmod +x loranet_deployment_bot.py
```

## ⚙️ Configuration

Edit `bot_config.json` to customize the bot behavior:

```json
{
  "network_range": "192.168.1.0/24",
  "default_credentials": {
    "username": "admin",
    "password": "admin"
  },
  "target_mac_prefixes": [
    "00:52:24",
    "02:52:24"
  ],
  "authorized_ouis": {
    "a4:7a:cf": "VIBICOM COMMUNICATIONS INC.",
    "00:06:2c": "Bivio Networks",
    "00:24:d9": "BICOM, Inc.",
    "00:52:24": "Bivicom (custom/private)",
    "02:52:24": "Bivicom (alternative)"
  },
  "deployment_mode": "auto",
  "ssh_timeout": 10,
  "scan_timeout": 5,
  "max_threads": 50,
  "backup_before_deploy": true,
  "verify_deployment": true
}
```

### Configuration Options

- **network_range**: Network range to scan (CIDR notation)
- **default_credentials**: SSH username and password for target devices
- **target_mac_prefixes**: MAC address prefixes to identify target devices
- **deployment_mode**: "auto", "interactive", or "manual"
- **ssh_timeout**: SSH connection timeout in seconds
- **scan_timeout**: Network scan timeout per host
- **max_threads**: Maximum concurrent threads for scanning
- **backup_before_deploy**: Create backup before deployment
- **verify_deployment**: Verify services after deployment

## 🎯 Usage

### Basic Usage

```bash
# Discover devices only
python3 loranet_deployment_bot.py --discover-only

# Deploy to all discovered devices (auto mode)
python3 loranet_deployment_bot.py --mode auto

# Deploy with custom network range
python3 loranet_deployment_bot.py --network 192.168.0.0/24 --mode auto
```

### Advanced Usage

```bash
# Deploy with custom credentials
python3 loranet_deployment_bot.py --username admin --password admin123 --mode auto

# Deploy with custom MAC prefixes
python3 loranet_deployment_bot.py --mac-prefix 00:52:24 --mac-prefix 02:52:24 --mode auto

# Use custom configuration file
python3 loranet_deployment_bot.py --config my_config.json --mode auto

# Validate a specific MAC address
python3 loranet_deployment_bot.py --validate-mac 00:52:24:4d:d8:cc

# List all authorized MAC prefixes
python3 loranet_deployment_bot.py --list-authorized
```

### MAC Address Validation

The bot includes comprehensive MAC address validation to ensure only authorized Bivicom devices are targeted:

```bash
# Test MAC validation
python3 test_mac_simple.py

# Validate specific MAC
python3 loranet_deployment_bot.py --validate-mac 00:52:24:4d:d8:cc
```

**Authorized Bivicom MAC Prefixes:**
- `a4:7a:cf` - VIBICOM COMMUNICATIONS INC.
- `00:06:2c` - Bivio Networks
- `00:24:d9` - BICOM, Inc.
- `00:52:24` - Bivicom (custom/private)
- `02:52:24` - Bivicom (alternative)

### Command Line Options

- `--config, -c`: Configuration file path (default: bot_config.json)
- `--network, -n`: Network range to scan (e.g., 192.168.1.0/24)
- `--mode, -m`: Deployment mode (auto, interactive, manual)
- `--username, -u`: SSH username
- `--password, -p`: SSH password
- `--mac-prefix`: MAC address prefix to target (can be used multiple times)
- `--discover-only`: Only discover devices, do not deploy
- `--validate-mac`: Validate a specific MAC address
- `--list-authorized`: List all authorized MAC address prefixes

## 🔍 How It Works

1. **Network Scanning**: Scans the specified network range for active hosts
2. **MAC Address Detection**: Uses ARP table to get MAC addresses of active hosts
3. **MAC Validation**: Validates MAC addresses against authorized Bivicom manufacturer prefixes
4. **Security Logging**: Logs unauthorized device attempts for security auditing
5. **Device Identification**: Matches MAC addresses against target prefixes
6. **SSH Connection**: Tests SSH connectivity with default credentials
7. **Deployment**: Executes the Loranet infrastructure setup script
8. **Monitoring**: Monitors deployment progress in real-time
9. **Verification**: Verifies that services are running after deployment
10. **Reporting**: Generates detailed deployment report

## 📊 Example Output

```
[2025-01-08 10:30:15] [INFO] Starting device discovery...
[2025-01-08 10:30:16] [INFO] Scanning network range: 192.168.1.0/24
[2025-01-08 10:30:18] [INFO] Found active host: 192.168.1.1
[2025-01-08 10:30:19] [SUCCESS] Device 192.168.1.1 (00:52:24) authorized: Bivicom (custom/private)
[2025-01-08 10:30:20] [SUCCESS] Device 192.168.1.1 is ready for deployment
[2025-01-08 10:30:21] [INFO] Starting deployment to 192.168.1.1
[2025-01-08 10:30:22] [INFO] Executing deployment command on 192.168.1.1
[2025-01-08 10:35:45] [SUCCESS] Deployment to 192.168.1.1 completed successfully

# Security logging example
[2025-01-08 10:30:25] [WARNING] SECURITY [UNAUTHORIZED_DEVICE] 192.168.1.100 (00:50:56:12:34:56): OUI: 00:50:56 - Not in authorized Bivicom OUI list
```

## 🛡️ Security Considerations

- **MAC Address Validation**: Only deploys to authorized Bivicom devices
- **Security Logging**: All unauthorized access attempts are logged to `security_audit.log`
- **OUI Verification**: Validates against known Bivicom manufacturer prefixes
- **Default Credentials**: Uses admin/admin - change these in production
- **SSH Security**: Connections made with auto-accept host keys
- **Network Trust**: Ensure the bot runs on a trusted network
- **Audit Trail**: Complete logging of all security events for compliance

## 🐛 Troubleshooting

### Common Issues

1. **No devices found**: Check network range and MAC prefixes
2. **SSH connection failed**: Verify credentials and network connectivity
3. **Deployment timeout**: Increase timeout values in configuration
4. **Permission denied**: Ensure the bot has necessary permissions

### Debug Mode

Enable debug logging by setting log level in configuration:

```json
{
  "log_level": "DEBUG"
}
```

## 📝 Deployment Report

The bot generates a detailed report after deployment:

```
Loranet Deployment Bot Report
============================
Date: 2025-01-08 10:35:45
Total Devices: 3
Successful Deployments: 2
Failed Deployments: 1

Device Details:

IP: 192.168.1.1
MAC: 00:52:24:4d:d8:cc
Status: deployed
Verified: true

IP: 192.168.1.2
MAC: 00:52:24:4d:d8:cd
Status: deployed
Verified: true

IP: 192.168.1.3
MAC: 00:52:24:4d:d8:ce
Status: failed
Verified: false
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👨‍💻 Author

**Aqmar** - *Initial work* - [Loranet Technologies](https://github.com/Loranet-Technologies)

## 🙏 Acknowledgments

- OpenWrt community for UCI configuration system
- Node-RED team for the excellent platform
- Docker team for containerization
- Tailscale for VPN solution
