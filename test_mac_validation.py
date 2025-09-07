#!/usr/bin/env python3
"""
Test script for MAC address validation functionality
"""

import sys
import os

# Add current directory to path to import the bot
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from loranet_deployment_bot import LoranetDeploymentBot

def test_mac_validation():
    """Test MAC address validation with various examples"""
    
    print("=" * 60)
    print("MAC Address Validation Test")
    print("=" * 60)
    
    # Initialize bot
    bot = LoranetDeploymentBot()
    
    # Test cases
    test_cases = [
        # Valid Bivicom MACs
        ("00:52:24:4d:d8:cc", "Bivicom custom/private"),
        ("02:52:24:4d:d8:cd", "Bivicom alternative"),
        ("a4:7a:cf:12:34:56", "VIBICOM COMMUNICATIONS INC."),
        ("00:06:2c:12:34:56", "Bivio Networks"),
        ("00:24:d9:12:34:56", "BICOM, Inc."),
        
        # Invalid/Unauthorized MACs
        ("00:50:56:12:34:56", "VMware (should be unauthorized)"),
        ("08:00:27:12:34:56", "VirtualBox (should be unauthorized)"),
        ("52:54:00:12:34:56", "QEMU (should be unauthorized)"),
        
        # Invalid formats
        ("invalid-mac", "Invalid format"),
        ("00:52:24", "Too short"),
        ("00:52:24:4d:d8:cc:extra", "Too long"),
        ("", "Empty MAC"),
    ]
    
    print(f"\nTesting {len(test_cases)} MAC addresses...\n")
    
    authorized_count = 0
    unauthorized_count = 0
    invalid_count = 0
    
    for mac, description in test_cases:
        print(f"Testing: {mac} ({description})")
        print("-" * 40)
        
        validation = bot.validate_mac_address(mac)
        
        if not validation['valid']:
            print(f"❌ INVALID: {validation['reason']}")
            invalid_count += 1
        elif validation['authorized']:
            print(f"✅ AUTHORIZED: {validation['manufacturer']}")
            print(f"   OUI: {validation['oui']}")
            print(f"   Reason: {validation['reason']}")
            authorized_count += 1
        else:
            print(f"⚠️  UNAUTHORIZED: {validation['manufacturer']}")
            print(f"   OUI: {validation['oui']}")
            print(f"   Reason: {validation['reason']}")
            unauthorized_count += 1
        
        print()
    
    # Summary
    print("=" * 60)
    print("Test Summary:")
    print(f"  ✅ Authorized: {authorized_count}")
    print(f"  ⚠️  Unauthorized: {unauthorized_count}")
    print(f"  ❌ Invalid: {invalid_count}")
    print(f"  📊 Total: {len(test_cases)}")
    print("=" * 60)

def test_authorized_list():
    """Test listing authorized MAC prefixes"""
    
    print("\n" + "=" * 60)
    print("Authorized MAC Address Prefixes")
    print("=" * 60)
    
    bot = LoranetDeploymentBot()
    
    # Simulate the --list-authorized command
    authorized_ouis = {
        "a4:7a:cf": "VIBICOM COMMUNICATIONS INC.",
        "00:06:2c": "Bivio Networks", 
        "00:24:d9": "BICOM, Inc.",
        "00:52:24": "Bivicom (custom/private)",
        "02:52:24": "Bivicom (alternative)"
    }
    
    print("Authorized OUI Prefixes:")
    for oui, manufacturer in authorized_ouis.items():
        print(f"  {oui} - {manufacturer}")
    
    print(f"\nConfigured target prefixes: {bot.config['target_mac_prefixes']}")

if __name__ == "__main__":
    test_mac_validation()
    test_authorized_list()
