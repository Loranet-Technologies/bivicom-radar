#!/usr/bin/env python3
"""
Simple MAC address validation test without external dependencies
"""

import re
import json

def validate_mac_address(mac: str) -> dict:
    """Validate MAC address and check against authorized manufacturers"""
    if not mac:
        return {'valid': False, 'reason': 'Empty MAC address'}
    
    mac_lower = mac.lower()
    
    # Validate MAC format
    if not re.match(r'^([0-9a-f]{2}[:-]){5}[0-9a-f]{2}$', mac_lower):
        return {'valid': False, 'reason': 'Invalid MAC address format'}
    
    # Extract OUI (first 3 octets)
    oui = mac_lower[:8]  # XX:XX:XX format
    
    # Known Bivicom manufacturer prefixes
    authorized_ouis = {
        "a4:7a:cf": "VIBICOM COMMUNICATIONS INC.",
        "00:06:2c": "Bivio Networks", 
        "00:24:d9": "BICOM, Inc.",
        "00:52:24": "Bivicom (custom/private)",
        "02:52:24": "Bivicom (alternative)"
    }
    
    # Check against known Bivicom OUIs
    if oui in authorized_ouis:
        return {
            'valid': True,
            'authorized': True, 
            'oui': oui,
            'manufacturer': authorized_ouis[oui],
            'reason': 'Matches authorized Bivicom OUI'
        }
    
    return {
        'valid': True,
        'authorized': False,
        'oui': oui,
        'manufacturer': 'Unknown',
        'reason': 'Not in authorized Bivicom OUI list'
    }

def test_mac_validation():
    """Test MAC address validation with various examples"""
    
    print("=" * 60)
    print("MAC Address Validation Test")
    print("=" * 60)
    
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
        
        validation = validate_mac_address(mac)
        
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

def show_authorized_list():
    """Show authorized MAC prefixes"""
    
    print("\n" + "=" * 60)
    print("Authorized MAC Address Prefixes")
    print("=" * 60)
    
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
    
    print(f"\nConfigured target prefixes: ['00:52:24', '02:52:24']")

if __name__ == "__main__":
    test_mac_validation()
    show_authorized_list()
