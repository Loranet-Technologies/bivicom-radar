#!/usr/bin/env python3
"""
Loranet Infrastructure Deployment Bot
=====================================

This bot automatically discovers devices on the network, identifies them by MAC address,
and deploys the Loranet infrastructure setup via SSH.

Author: Aqmar
Date: 2025-01-08
"""

import subprocess
import paramiko
import socket
import threading
import time
import json
import argparse
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, List, Optional, Tuple
import ipaddress
import re

class LoranetDeploymentBot:
    def __init__(self, config_file: str = "bot_config.json"):
        self.config = self.load_config(config_file)
        self.ssh_client = None
        self.discovered_devices = []
        self.target_devices = []
        
        # Default configuration
        self.default_config = {
            "network_range": "192.168.1.0/24",
            "default_credentials": {
                "username": "admin",
                "password": "admin"
            },
            "target_mac_prefixes": [
                "00:52:24",  # Bivicom devices
                "02:52:24",  # Alternative Bivicom prefix
                "aa:bb:cc"   # Add your specific MAC prefixes
            ],
            "deployment_mode": "auto",  # auto, interactive, or manual
            "ssh_timeout": 10,
            "scan_timeout": 5,
            "max_threads": 50,
            "log_level": "INFO",
            "backup_before_deploy": True,
            "verify_deployment": True
        }
        
        # Merge with loaded config
        if self.config:
            self.default_config.update(self.config)
        self.config = self.default_config

    def load_config(self, config_file: str) -> Dict:
        """Load configuration from JSON file"""
        try:
            with open(config_file, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            print(f"[INFO] Config file {config_file} not found, using defaults")
            return {}
        except json.JSONDecodeError as e:
            print(f"[ERROR] Invalid JSON in config file: {e}")
            return {}

    def save_config(self, config_file: str = "bot_config.json"):
        """Save current configuration to JSON file"""
        try:
            with open(config_file, 'w') as f:
                json.dump(self.config, f, indent=2)
            print(f"[SUCCESS] Configuration saved to {config_file}")
        except Exception as e:
            print(f"[ERROR] Failed to save config: {e}")

    def log(self, message: str, level: str = "INFO"):
        """Log message with timestamp"""
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] [{level}] {message}")

    def scan_network(self, network_range: str) -> List[str]:
        """Scan network range for active hosts"""
        self.log(f"Scanning network range: {network_range}")
        active_hosts = []
        
        try:
            network = ipaddress.ip_network(network_range, strict=False)
        except ValueError as e:
            self.log(f"Invalid network range: {e}", "ERROR")
            return active_hosts

        def ping_host(ip):
            """Ping a single host"""
            try:
                result = subprocess.run(
                    ['ping', '-c', '1', '-W', str(self.config['scan_timeout']), str(ip)],
                    capture_output=True,
                    timeout=self.config['scan_timeout'] + 2
                )
                if result.returncode == 0:
                    return str(ip)
            except (subprocess.TimeoutExpired, Exception):
                pass
            return None

        # Use ThreadPoolExecutor for concurrent scanning
        with ThreadPoolExecutor(max_workers=self.config['max_threads']) as executor:
            futures = {executor.submit(ping_host, ip): ip for ip in network.hosts()}
            
            for future in as_completed(futures):
                result = future.result()
                if result:
                    active_hosts.append(result)
                    self.log(f"Found active host: {result}")

        self.log(f"Network scan completed. Found {len(active_hosts)} active hosts")
        return active_hosts

    def get_mac_address(self, ip: str) -> Optional[str]:
        """Get MAC address of a host using ARP table"""
        try:
            # Try to get MAC from ARP table
            result = subprocess.run(['arp', '-n', ip], capture_output=True, text=True)
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                for line in lines:
                    if ip in line:
                        # Extract MAC address from ARP output
                        mac_match = re.search(r'([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}', line)
                        if mac_match:
                            return mac_match.group(0).replace('-', ':').lower()
            
            # Alternative method using nmap if available
            try:
                result = subprocess.run(['nmap', '-sn', ip], capture_output=True, text=True)
                if result.returncode == 0:
                    mac_match = re.search(r'([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}', result.stdout)
                    if mac_match:
                        return mac_match.group(0).replace('-', ':').lower()
            except FileNotFoundError:
                pass
                
        except Exception as e:
            self.log(f"Failed to get MAC for {ip}: {e}", "WARNING")
        
        return None

    def is_target_device(self, mac: str) -> bool:
        """Check if MAC address matches target device prefixes"""
        if not mac:
            return False
            
        mac_lower = mac.lower()
        for prefix in self.config['target_mac_prefixes']:
            if mac_lower.startswith(prefix.lower()):
                return True
        return False

    def test_ssh_connection(self, ip: str, username: str, password: str) -> bool:
        """Test SSH connection to a host"""
        try:
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            
            ssh.connect(
                ip,
                username=username,
                password=password,
                timeout=self.config['ssh_timeout'],
                allow_agent=False,
                look_for_keys=False
            )
            
            ssh.close()
            return True
            
        except Exception as e:
            self.log(f"SSH connection failed to {ip}: {e}", "DEBUG")
            return False

    def discover_devices(self) -> List[Dict]:
        """Discover and identify target devices on the network"""
        self.log("Starting device discovery...")
        
        # Scan network for active hosts
        active_hosts = self.scan_network(self.config['network_range'])
        
        discovered_devices = []
        
        for ip in active_hosts:
            self.log(f"Analyzing host: {ip}")
            
            # Get MAC address
            mac = self.get_mac_address(ip)
            if not mac:
                self.log(f"Could not determine MAC for {ip}", "WARNING")
                continue
            
            # Check if it's a target device
            if self.is_target_device(mac):
                self.log(f"Found target device: {ip} (MAC: {mac})")
                
                # Test SSH connection
                if self.test_ssh_connection(ip, self.config['default_credentials']['username'], 
                                         self.config['default_credentials']['password']):
                    device_info = {
                        'ip': ip,
                        'mac': mac,
                        'username': self.config['default_credentials']['username'],
                        'password': self.config['default_credentials']['password'],
                        'status': 'ready'
                    }
                    discovered_devices.append(device_info)
                    self.log(f"Device {ip} is ready for deployment", "SUCCESS")
                else:
                    self.log(f"Device {ip} found but SSH connection failed", "WARNING")
            else:
                self.log(f"Host {ip} (MAC: {mac}) is not a target device", "DEBUG")
        
        self.discovered_devices = discovered_devices
        self.log(f"Discovery completed. Found {len(discovered_devices)} target devices")
        return discovered_devices

    def deploy_to_device(self, device: Dict) -> bool:
        """Deploy infrastructure to a single device"""
        ip = device['ip']
        username = device['username']
        password = device['password']
        
        self.log(f"Starting deployment to {ip}")
        
        try:
            # Create SSH connection
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            ssh.connect(ip, username=username, password=password, timeout=self.config['ssh_timeout'])
            
            # Create backup if enabled
            if self.config['backup_before_deploy']:
                self.log(f"Creating backup for {ip}")
                backup_cmd = "mkdir -p /tmp/backup && cp -r /etc/config /tmp/backup/ 2>/dev/null || true"
                stdin, stdout, stderr = ssh.exec_command(backup_cmd)
                stdout.channel.recv_exit_status()
            
            # Deploy based on mode
            if self.config['deployment_mode'] == 'auto':
                deploy_cmd = "curl -sSL https://raw.githubusercontent.com/Loranet-Technologies/bivicom-radar/main/install_auto.sh | bash -s -- --auto"
            elif self.config['deployment_mode'] == 'interactive':
                deploy_cmd = "curl -sSL https://raw.githubusercontent.com/Loranet-Technologies/bivicom-radar/main/install.sh | bash"
            else:
                deploy_cmd = "curl -sSL https://raw.githubusercontent.com/Loranet-Technologies/bivicom-radar/main/install.sh | bash"
            
            self.log(f"Executing deployment command on {ip}")
            stdin, stdout, stderr = ssh.exec_command(deploy_cmd)
            
            # Monitor deployment progress
            deployment_success = self.monitor_deployment(ssh, stdout, stderr, ip)
            
            ssh.close()
            
            if deployment_success:
                self.log(f"Deployment to {ip} completed successfully", "SUCCESS")
                device['status'] = 'deployed'
                return True
            else:
                self.log(f"Deployment to {ip} failed", "ERROR")
                device['status'] = 'failed'
                return False
                
        except Exception as e:
            self.log(f"Deployment to {ip} failed with error: {e}", "ERROR")
            device['status'] = 'error'
            return False

    def monitor_deployment(self, ssh, stdout, stderr, ip: str) -> bool:
        """Monitor deployment progress and return success status"""
        self.log(f"Monitoring deployment on {ip}")
        
        start_time = time.time()
        timeout = 1800  # 30 minutes timeout
        
        try:
            while True:
                if time.time() - start_time > timeout:
                    self.log(f"Deployment timeout on {ip}", "ERROR")
                    return False
                
                # Check if process is still running
                if stdout.channel.exit_status_ready():
                    exit_status = stdout.channel.recv_exit_status()
                    if exit_status == 0:
                        self.log(f"Deployment completed successfully on {ip}", "SUCCESS")
                        return True
                    else:
                        self.log(f"Deployment failed on {ip} with exit code {exit_status}", "ERROR")
                        return False
                
                # Read output
                if stdout.channel.recv_ready():
                    output = stdout.channel.recv(1024).decode('utf-8')
                    if output.strip():
                        self.log(f"[{ip}] {output.strip()}")
                
                # Check for errors
                if stderr.channel.recv_ready():
                    error = stderr.channel.recv(1024).decode('utf-8')
                    if error.strip():
                        self.log(f"[{ip}] ERROR: {error.strip()}", "ERROR")
                
                time.sleep(1)
                
        except Exception as e:
            self.log(f"Error monitoring deployment on {ip}: {e}", "ERROR")
            return False

    def verify_deployment(self, device: Dict) -> bool:
        """Verify that deployment was successful"""
        if not self.config['verify_deployment']:
            return True
            
        ip = device['ip']
        username = device['username']
        password = device['password']
        
        self.log(f"Verifying deployment on {ip}")
        
        try:
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            ssh.connect(ip, username=username, password=password, timeout=self.config['ssh_timeout'])
            
            # Check if services are running
            checks = [
                ("Node-RED", "systemctl is-active nodered"),
                ("Docker", "systemctl is-active docker"),
                ("Tailscale", "systemctl is-active tailscaled")
            ]
            
            all_services_running = True
            for service_name, check_cmd in checks:
                stdin, stdout, stderr = ssh.exec_command(check_cmd)
                exit_status = stdout.channel.recv_exit_status()
                
                if exit_status == 0:
                    self.log(f"[{ip}] {service_name} is running", "SUCCESS")
                else:
                    self.log(f"[{ip}] {service_name} is not running", "WARNING")
                    all_services_running = False
            
            ssh.close()
            return all_services_running
            
        except Exception as e:
            self.log(f"Verification failed for {ip}: {e}", "ERROR")
            return False

    def deploy_all(self) -> Dict:
        """Deploy to all discovered devices"""
        self.log("Starting deployment to all devices")
        
        results = {
            'total': len(self.discovered_devices),
            'successful': 0,
            'failed': 0,
            'devices': []
        }
        
        for device in self.discovered_devices:
            success = self.deploy_to_device(device)
            
            if success:
                results['successful'] += 1
                # Verify deployment if enabled
                if self.config['verify_deployment']:
                    if self.verify_deployment(device):
                        device['verified'] = True
                    else:
                        device['verified'] = False
            else:
                results['failed'] += 1
            
            results['devices'].append(device)
        
        self.log(f"Deployment completed. Success: {results['successful']}, Failed: {results['failed']}")
        return results

    def generate_report(self, results: Dict) -> str:
        """Generate deployment report"""
        report = f"""
Loranet Deployment Bot Report
============================
Date: {time.strftime('%Y-%m-%d %H:%M:%S')}
Total Devices: {results['total']}
Successful Deployments: {results['successful']}
Failed Deployments: {results['failed']}

Device Details:
"""
        
        for device in results['devices']:
            report += f"""
IP: {device['ip']}
MAC: {device['mac']}
Status: {device['status']}
Verified: {device.get('verified', 'N/A')}
"""
        
        return report

    def run(self):
        """Main execution function"""
        self.log("Loranet Deployment Bot started")
        
        # Discover devices
        devices = self.discover_devices()
        
        if not devices:
            self.log("No target devices found. Exiting.", "WARNING")
            return
        
        # Confirm deployment
        if self.config['deployment_mode'] != 'auto':
            print(f"\nFound {len(devices)} target devices:")
            for device in devices:
                print(f"  - {device['ip']} (MAC: {device['mac']})")
            
            confirm = input("\nProceed with deployment? (y/N): ").strip().lower()
            if confirm != 'y':
                self.log("Deployment cancelled by user")
                return
        
        # Deploy to all devices
        results = self.deploy_all()
        
        # Generate and save report
        report = self.generate_report(results)
        report_file = f"deployment_report_{int(time.time())}.txt"
        
        try:
            with open(report_file, 'w') as f:
                f.write(report)
            self.log(f"Deployment report saved to {report_file}")
        except Exception as e:
            self.log(f"Failed to save report: {e}", "ERROR")
        
        print(report)


def main():
    parser = argparse.ArgumentParser(description='Loranet Infrastructure Deployment Bot')
    parser.add_argument('--config', '-c', default='bot_config.json', help='Configuration file path')
    parser.add_argument('--network', '-n', help='Network range to scan (e.g., 192.168.1.0/24)')
    parser.add_argument('--mode', '-m', choices=['auto', 'interactive', 'manual'], 
                       help='Deployment mode')
    parser.add_argument('--username', '-u', help='SSH username')
    parser.add_argument('--password', '-p', help='SSH password')
    parser.add_argument('--mac-prefix', action='append', help='MAC address prefix to target')
    parser.add_argument('--discover-only', action='store_true', help='Only discover devices, do not deploy')
    
    args = parser.parse_args()
    
    # Initialize bot
    bot = LoranetDeploymentBot(args.config)
    
    # Override config with command line arguments
    if args.network:
        bot.config['network_range'] = args.network
    if args.mode:
        bot.config['deployment_mode'] = args.mode
    if args.username:
        bot.config['default_credentials']['username'] = args.username
    if args.password:
        bot.config['default_credentials']['password'] = args.password
    if args.mac_prefix:
        bot.config['target_mac_prefixes'] = args.mac_prefix
    
    # Run bot
    if args.discover_only:
        devices = bot.discover_devices()
        print(f"\nDiscovered {len(devices)} target devices:")
        for device in devices:
            print(f"  - {device['ip']} (MAC: {device['mac']})")
    else:
        bot.run()


if __name__ == "__main__":
    main()
