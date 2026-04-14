#!/bin/bash
# Ansible Pi Cluster Deployment Script
# ====================================
# Usage:
#   ./deploy.sh                    # Deploy all roles (default)
#   ./deploy.sh --dry-run          # Preview changes without applying
#   ./deploy.sh --roles=common,controller  # Deploy specific roles only
#   ./deploy.sh --skip-roles=worker # Skip certain roles during deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ROLES="common,controller,worker,storage-controller,loadbalancer"
SKIP_ROLES=""
DRY_RUN=false
CHECK_MODE=false
HELP_REQUEST=false
REPLAY=false

# Print colored output
print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     Ansible Pi Cluster Deployment System                 ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
}

print_success() {
    echo -e "${GREEN}[✓] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

print_error() {
    echo -e "${RED}[✗] $1${NC}"
}

print_info() {
    echo -e "${BLUE}[ℹ] $1${NC}"
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                print_info "Dry-run mode enabled (no changes will be made)"
                ;;
            --check)
                CHECK_MODE=true
                print_info "Check mode enabled (validation only)"
                ;;
            --roles=*)
                ROLES="${1#*=}"
                print_info "Roles to deploy: $ROLES"
                ;;
            --skip-roles=*)
                SKIP_ROLES="${1#*=}"
                print_info "Roles to skip: $SKIP_ROLES"
                ;;
            --replay)
                REPLAY=true
                print_info "Replaying last successful deployment"
                ;;
            -h|--help)
                HELP_REQUEST=true
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information."
                exit 1
                ;;
        esac
        shift
    done
}

# Display help message
show_help() {
    cat << EOF
Ansible Pi Cluster Deployment System
=====================================

Usage: $(basename "$0") [OPTIONS]

Options:
  --dry-run          Preview changes without applying them
  --check            Run in check mode (validation only)
  --roles=ROLES      Deploy only specified roles (comma-separated)
                     Example: --roles=common,controller
  --skip-roles=ROLES Skip specified roles during deployment
                     Example: --skip-roles=worker
  --replay           Replay last successful deployment
  -h, --help         Display this help message

Examples:
  $(basename "$0")                    # Deploy all roles (default)
  $(basename "$0") --dry-run          # Preview changes first
  $(basename "$0") --roles=common     # Deploy only common role
  $(basename "$0") --skip-roles=worker # Skip worker deployment

EOF
}

# Check if Ansible is installed
check_ansible() {
    print_info "Checking Ansible installation..."
    
    if ! command -v ansible &> /dev/null; then
        print_error "Ansible is not installed on this system."
        print_error "Please install Ansible first: sudo apt install ansible"
        exit 1
    fi
    
    print_success "Ansible version: $(ansible --version | head -n1)"
}

# Validate inventory file exists and is properly formatted
validate_inventory() {
    print_info "Validating inventory configuration..."
    
    if [[ ! -f "inventory.ini" ]]; then
        print_error "Inventory file not found: inventory.ini"
        print_error "Please create the inventory file with your node definitions."
        exit 1
    fi
    
    # Check for required variables
    local missing_vars=()
    if ! grep -q "controller_ip" inventory.ini; then
        missing_vars+=("controller_ip")
    fi
    if ! grep -q "storage_controller_ip" inventory.ini; then
        missing_vars+=("storage_controller_ip")
    fi
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        print_warning "Missing required variables in inventory.ini:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        print_info "You can add these defaults to inventory.ini:
cluster_name='Raspberry-Pi-Cluster'
controller_ip=rk01.local
storage_controller_ip=rk01.local
pihole_ip=rpi02.local
loadbalancer_ip=rpi02.local"
    fi
    
    print_success "Inventory validation passed"
}

# Deploy a single role
deploy_role() {
    local role_name="$1"
    
    print_info "Deploying role: $role_name..."
    
    if [[ -d "roles/$role_name" ]]; then
        # Run the role deployment
        ansible-playbook roles/$role_name/tasks/main.yml \
            --inventory inventory.ini \
            ${CHECK_MODE:+--check} \
            ${DRY_RUN:+--dry-run}
    else
        print_warning "Role directory not found: roles/$role_name"
    fi
}

# Deploy all selected roles
deploy_all_roles() {
    local deployed_count=0
    local skipped_count=0
    
    # Parse roles
    IFS=',' read -ra ROLE_ARRAY <<< "$ROLES"
    
    for role in "${ROLE_ARRAY[@]}"; do
        # Check if role should be skipped
        if [[ -n "$SKIP_ROLES" ]]; then
            IFS=',' read -ra SKIP_ARRAY <<< "$SKIP_ROLES"
            for skip_role in "${SKIP_ARRAY[@]}"; do
                if [[ "$role" == "$skip_role" ]]; then
                    print_info "Skipping role: $role (requested to be skipped)"
                    ((skipped_count++))
                    continue 2
                fi
            done
        fi
        
        # Check if role directory exists
        if [[ -d "roles/$role" ]]; then
            deploy_role "$role"
            ((deployed_count++))
        else
            print_warning "Skipping role: $role (directory not found)"
            ((skipped_count++))
        fi
    done
    
    # Print summary
    echo "----------------------------------------"
    print_info "Deployment complete!"
    print_info "Roles deployed:  $deployed_count"
    print_info "Roles skipped:   $skipped_count"
}

# Replay last successful deployment
replay_deployment() {
    if [[ -f ".deployment_history" ]]; then
        local last_run=$(cat .deployment_history)
        print_info "Replaying deployment from: $last_run"
        # Re-run the same command that was used last time
        deploy_all_roles
    else
        print_error "No deployment history found. Use --help to see available options."
    fi
}

# Main function
main() {
    parse_arguments "$@"
    
    if [[ $HELP_REQUEST == true ]]; then
        show_help
    fi
    
    # Check prerequisites
    check_ansible
    validate_inventory
    
    # Display summary before deployment
    show_deployment_summary
    
    echo ""
    print_info "Starting deployment..."
    echo ""
    
    if [[ $REPLAY == true ]]; then
        replay_deployment
    else
        deploy_all_roles
    fi
    
    # Record deployment timestamp (if not in dry-run/check mode)
    if [[ "$DRY_RUN" == false && "$CHECK_MODE" == false ]]; then
        date +%s > .deployment_history
    fi
}

# Run main function with all arguments
main "$@"