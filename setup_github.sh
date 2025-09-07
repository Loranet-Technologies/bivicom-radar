#!/bin/bash

# =============================================================================
# GitHub Repository Setup Script
# =============================================================================
# This script helps set up the GitHub repository for the Loranet infrastructure setup
# 
# Author: Aqmar
# =============================================================================

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Repository information
REPO_NAME="bivicom-radar"
ORG_NAME="Loranet-Technologies"
FULL_REPO_NAME="$ORG_NAME/$REPO_NAME"
REPO_URL="https://github.com/$FULL_REPO_NAME"

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

# Function to check if gh CLI is installed
check_gh_cli() {
    if ! command -v gh >/dev/null 2>&1; then
        print_warning "GitHub CLI (gh) is not installed."
        print_status "You can install it from: https://cli.github.com/"
        print_status "Or use the manual setup instructions below."
        return 1
    fi
    return 0
}

# Function to create repository using GitHub CLI
create_repo_with_gh() {
    print_section "CREATING GITHUB REPOSITORY WITH GH CLI"
    
    # Check if already authenticated
    if ! gh auth status >/dev/null 2>&1; then
        print_status "Please authenticate with GitHub CLI first:"
        print_status "  gh auth login"
        exit 1
    fi
    
    # Create the repository
    print_status "Creating repository: $FULL_REPO_NAME"
    gh repo create "$FULL_REPO_NAME" \
        --public \
        --description "Bivicom Radar Infrastructure Setup Script with Node-RED, Tailscale, Docker, and UCI Configuration" \
        --add-readme=false \
        --clone=false
    
    print_success "Repository created successfully!"
    
    # Add remote and push
    print_status "Adding remote origin..."
    git remote add origin "https://github.com/$FULL_REPO_NAME.git"
    
    print_status "Pushing to GitHub..."
    git branch -M main
    git push -u origin main
    
    print_success "Repository pushed to GitHub successfully!"
    print_status "Repository URL: $REPO_URL"
}

# Function to show manual setup instructions
show_manual_setup() {
    print_section "MANUAL GITHUB REPOSITORY SETUP"
    
    echo "Since GitHub CLI is not available, please follow these steps:"
    echo
    echo "1. Go to GitHub and create a new repository:"
    echo "   URL: https://github.com/new"
    echo
    echo "2. Repository settings:"
    echo "   - Owner: $ORG_NAME"
    echo "   - Repository name: $REPO_NAME"
    echo "   - Description: Bivicom Radar Infrastructure Setup Script with Node-RED, Tailscale, Docker, and UCI Configuration"
    echo "   - Visibility: Public"
    echo "   - Initialize: Don't initialize (we already have files)"
    echo
    echo "3. After creating the repository, run these commands:"
    echo "   git remote add origin https://github.com/$FULL_REPO_NAME.git"
    echo "   git branch -M main"
    echo "   git push -u origin main"
    echo
    echo "4. Repository will be available at: $REPO_URL"
}

# Function to show curl installation command
show_curl_command() {
    print_section "CURL INSTALLATION COMMAND"
    
    echo "Once the repository is created, users can install with:"
    echo
    echo "curl -sSL https://raw.githubusercontent.com/$FULL_REPO_NAME/main/install.sh | bash"
    echo
    echo "Or download the main script directly:"
    echo
    echo "curl -sSL https://raw.githubusercontent.com/$FULL_REPO_NAME/main/complete_infrastructure_setup.sh -o setup.sh"
    echo "chmod +x setup.sh"
    echo "./setup.sh"
}

# Function to show repository information
show_repo_info() {
    print_section "REPOSITORY INFORMATION"
    
    echo "Repository Details:"
    echo "  Name: $REPO_NAME"
    echo "  Organization: $ORG_NAME"
    echo "  Full Name: $FULL_REPO_NAME"
    echo "  URL: $REPO_URL"
    echo
    echo "Files in Repository:"
    echo "  - complete_infrastructure_setup.sh (33.2KB) - Main setup script"
    echo "  - install.sh (5.8KB) - Curl installation script"
    echo "  - nodered_flows/ (72KB) - Node-RED flows and dependencies"
    echo "  - README.md (8.5KB) - Comprehensive documentation"
    echo "  - LICENSE (1KB) - MIT License"
    echo "  - .gitignore (442B) - Git ignore rules"
    echo
    echo "Total Repository Size: ~120KB"
}

# Main execution
main() {
    print_section "LORANET GITHUB REPOSITORY SETUP"
    
    show_repo_info
    
    if check_gh_cli; then
        create_repo_with_gh
    else
        show_manual_setup
    fi
    
    show_curl_command
    
    print_success "GitHub repository setup completed!"
    print_status "Repository: $REPO_URL"
    print_status "Curl command: curl -sSL https://raw.githubusercontent.com/$FULL_REPO_NAME/main/install.sh | bash"
}

# Run main function
main "$@"
