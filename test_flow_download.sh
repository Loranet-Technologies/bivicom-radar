#!/bin/bash

# =============================================================================
# Node-RED Flow Download Test Script
# =============================================================================
# This script tests the Node-RED flow download functionality
# 
# Author: Aqmar
# =============================================================================

# set -e  # Commented out to prevent early exit on validation errors

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to test flow download
test_flow_download() {
    print_section "TESTING NODE-RED FLOW DOWNLOAD"
    
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
            if [ -s "test_flows.json" ]; then
                if validate_nodered_flows "test_flows.json"; then
                    print_success "Flow download test successful from: $url"
                    flows_downloaded=true
                    break
                else
                    print_warning "Downloaded file is invalid from: $url"
                    rm -f "test_flows.json"
                fi
            else
                print_warning "Downloaded file is empty from: $url"
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

# Main execution
main() {
    print_section "NODE-RED FLOW DOWNLOAD TEST"
    print_status "This script tests the Node-RED flow download functionality"
    print_status "Repository: https://github.com/Loranet-Technologies/bivicom-radar"
    echo
    
    # Check if curl is available
    if ! command -v curl >/dev/null 2>&1; then
        print_error "curl is required but not installed. Please install curl first."
        exit 1
    fi
    
    # Check if python3 is available
    if ! command -v python3 >/dev/null 2>&1; then
        print_error "python3 is required but not installed. Please install python3 first."
        exit 1
    fi
    
    # Run the test
    test_flow_download
}

# Run main function
main "$@"
