#!/bin/bash
# 
# OpenShift CCO Credential Rotation Script
# Convenience wrapper for running the Ansible playbook
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --dry-run                Run in dry-run mode (no changes made)"
    echo "  --tags TAG1,TAG2        Run only specific tags"
    echo "  --skip-tags TAG1,TAG2   Skip specific tags"
    echo "  --aws-profile PROFILE   Use specific AWS profile"
    echo "  --kubeconfig PATH       Use specific kubeconfig file"
    echo "  --cluster-name NAME     Override cluster name"
    echo "  --vault-password-file   Use vault password file instead of prompt"
    echo "  --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Full rotation"
    echo "  $0 --dry-run                         # Test run"
    echo "  $0 --tags preflight,cluster-id       # Run only preflight and discovery"
    echo "  $0 --aws-profile prod                # Use 'prod' AWS profile"
    echo ""
}

# Default values
DRY_RUN=false
TAGS=""
SKIP_TAGS=""
AWS_PROFILE=""
KUBECONFIG_PATH=""
CLUSTER_NAME=""
VAULT_PASSWORD_FILE=""
EXTRA_VARS=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --tags)
            TAGS="$2"
            shift 2
            ;;
        --skip-tags)
            SKIP_TAGS="$2"
            shift 2
            ;;
        --aws-profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        --kubeconfig)
            KUBECONFIG_PATH="$2"
            shift 2
            ;;
        --cluster-name)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --vault-password-file)
            VAULT_PASSWORD_FILE="$2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Pre-flight checks
echo -e "${YELLOW}OpenShift CCO Credential Rotation${NC}"
echo "=================================="
echo ""

# Check if required files exist
if [ ! -f "vars/vault.yml" ]; then
    echo -e "${RED}Error: vars/vault.yml not found${NC}"
    echo "Please copy vars/vault.yml.template to vars/vault.yml and configure it"
    exit 1
fi

# Check if ansible-playbook is available
if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${RED}Error: ansible-playbook not found${NC}"
    echo "Please install Ansible"
    exit 1
fi

# Build ansible-playbook command
ANSIBLE_CMD="ansible-playbook main.yml"

# Add vault password option
if [ -n "$VAULT_PASSWORD_FILE" ]; then
    ANSIBLE_CMD="$ANSIBLE_CMD --vault-password-file $VAULT_PASSWORD_FILE"
else
    ANSIBLE_CMD="$ANSIBLE_CMD --ask-vault-pass"
fi

# Add tags if specified
if [ -n "$TAGS" ]; then
    ANSIBLE_CMD="$ANSIBLE_CMD --tags $TAGS"
fi

# Add skip tags if specified
if [ -n "$SKIP_TAGS" ]; then
    ANSIBLE_CMD="$ANSIBLE_CMD --skip-tags $SKIP_TAGS"
fi

# Build extra vars
if [ "$DRY_RUN" = true ]; then
    EXTRA_VARS="dry_run=true"
fi

if [ -n "$AWS_PROFILE" ]; then
    if [ -n "$EXTRA_VARS" ]; then
        EXTRA_VARS="$EXTRA_VARS aws_profile=$AWS_PROFILE"
    else
        EXTRA_VARS="aws_profile=$AWS_PROFILE"
    fi
fi

if [ -n "$KUBECONFIG_PATH" ]; then
    if [ -n "$EXTRA_VARS" ]; then
        EXTRA_VARS="$EXTRA_VARS kubeconfig_path=$KUBECONFIG_PATH"
    else
        EXTRA_VARS="kubeconfig_path=$KUBECONFIG_PATH"
    fi
fi

if [ -n "$CLUSTER_NAME" ]; then
    if [ -n "$EXTRA_VARS" ]; then
        EXTRA_VARS="$EXTRA_VARS ocp_cluster_name=$CLUSTER_NAME"
    else
        EXTRA_VARS="ocp_cluster_name=$CLUSTER_NAME"
    fi
fi

# Add extra vars to command
if [ -n "$EXTRA_VARS" ]; then
    ANSIBLE_CMD="$ANSIBLE_CMD -e \"$EXTRA_VARS\""
fi

# Display configuration
echo "Configuration:"
echo "  Dry Run: $DRY_RUN"
echo "  Tags: ${TAGS:-all}"
echo "  Skip Tags: ${SKIP_TAGS:-none}"
echo "  AWS Profile: ${AWS_PROFILE:-default}"
echo "  Kubeconfig: ${KUBECONFIG_PATH:-default}"
echo "  Cluster Name: ${CLUSTER_NAME:-auto-detect}"
echo ""

# Confirmation prompt (unless in dry-run mode)
if [ "$DRY_RUN" = false ]; then
    echo -e "${YELLOW}WARNING: This will rotate CCO credentials in your OpenShift cluster${NC}"
    echo -e "${YELLOW}Make sure you have tested this in a non-production environment first${NC}"
    echo ""
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted"
        exit 1
    fi
fi

# Create logs directory if it doesn't exist
mkdir -p logs

# Run the playbook
echo -e "${GREEN}Starting CCO credential rotation...${NC}"
echo "Command: $ANSIBLE_CMD"
echo ""

# Execute the command
eval $ANSIBLE_CMD

# Check the result
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}CCO credential rotation completed successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Check the logs in the logs/ directory"
    echo "2. Monitor cluster operators for any issues"
    echo "3. Verify all applications are functioning normally"
    echo "4. Update any external systems that may reference the old credentials"
else
    echo ""
    echo -e "${RED}CCO credential rotation failed!${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "1. Check the error messages above"
    echo "2. Review logs in the logs/ directory"
    echo "3. Check backups in the backups/ directory for recovery"
    echo "4. Consult the README.md for common issues"
    exit 1
fi 