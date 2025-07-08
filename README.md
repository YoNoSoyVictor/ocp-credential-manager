# OpenShift Cloud Credential Operator (CCO) AWS Credential Rotation

This Ansible playbook automates the rotation of AWS credentials for the OpenShift Cloud Credential Operator (CCO) running in "mint mode." This is a critical security maintenance task that should be performed regularly.

## Overview

The Cloud Credential Operator (CCO) uses a "root" AWS credential to dynamically create and manage granular AWS credentials for various OpenShift components. This playbook safely rotates these credentials while maintaining cluster operations.

## Prerequisites

- OpenShift 4.10+ cluster running on AWS
- CCO configured in "mint mode"
- Ansible 2.9+ installed on control node
- Required CLI tools: `oc`, `aws`, `jq`
- AWS credentials with sufficient IAM permissions
- OpenShift cluster administrator access

## Project Structure

```
ocp-credential-manager/
├── ansible.cfg              # Ansible configuration
├── main.yml                 # Main playbook
├── inventory/
│   └── hosts.yml           # Inventory configuration
├── vars/
│   ├── main.yml            # Non-sensitive variables
│   └── vault.yml.template  # Template for sensitive variables
├── tasks/
│   ├── 01_preflight_checks.yml
│   ├── 02_get_ocp_cluster_id.yml
│   ├── 05_rotate_iam_access_key.yml
│   ├── 06_update_cco_root_secret.yml
│   └── ... (other task files)
├── roles/
│   └── aws_iam_user_management/
│       └── tasks/
│           └── main.yml
├── logs/                   # Rotation logs and metadata
└── backups/               # Backup files
```

## Setup Instructions

### 1. Configure AWS and OpenShift Access

**AWS Access**: Configure your AWS credentials using standard AWS CLI profiles:
```bash
aws configure --profile myprofile
# or use existing AWS credentials in ~/.aws/credentials
```

**OpenShift Access**: Ensure your kubeconfig is configured:
```bash
oc login https://your-cluster-api-url:6443
# or use existing kubeconfig file
```

### 2. Optional: Configure Notifications (Optional)

Only if you want notifications or custom backup settings:
```bash
cp vars/vault.yml.template vars/vault.yml
# Edit vars/vault.yml with notification settings
ansible-vault encrypt vars/vault.yml
```

### 3. Required AWS Permissions

The AWS credentials used for rotation must have the following IAM permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateAccessKey",
        "iam:CreateUser",
        "iam:DeleteAccessKey",
        "iam:DeleteUser",
        "iam:DeleteUserPolicy",
        "iam:GetUser",
        "iam:GetUserPolicy",
        "iam:ListAccessKeys",
        "iam:PutUserPolicy",
        "iam:TagUser",
        "iam:SimulatePrincipalPolicy",
        "iam:GetRole",
        "iam:ListRoles",
        "iam:PassRole"
      ],
      "Resource": "*"
    }
  ]
}
```

## Quick Start Guide

**That's it!** You just need:

1. **AWS Profile configured**: `aws configure --profile myprofile`
2. **OpenShift access**: `oc login https://your-cluster-api-url:6443`
3. **Run the rotation**: `ansible-playbook main.yml -e "aws_profile=myprofile"`

No vault files, no manual credential entry, no complex setup required!

## Usage

### Basic Rotation

```bash
# Run the full rotation process (uses default AWS profile and kubeconfig)
ansible-playbook main.yml

# Use specific AWS profile and kubeconfig
ansible-playbook main.yml -e "aws_profile=myprofile" -e "kubeconfig_path=/path/to/kubeconfig"

# Dry run mode (testing)
ansible-playbook main.yml -e "dry_run=true"
```

### Advanced Usage

```bash
# Run with specific tags
ansible-playbook main.yml --tags "preflight,cluster-id"

# Skip certain steps
ansible-playbook main.yml --skip-tags "cleanup"

# Use vault file (if you have notifications configured)
ansible-playbook main.yml --ask-vault-pass -e "aws_profile=myprofile"
```

## How the Rotation Process Works

### Step-by-Step Walkthrough

1. **Pre-flight Checks** (`tasks/01_preflight_checks.yml`)
   - Verifies required CLI tools are installed and configured
   - Checks OpenShift cluster connectivity and admin permissions
   - Validates AWS credentials and IAM permissions
   - Confirms CCO is in mint mode and functioning

2. **Cluster Discovery** (`tasks/02_get_ocp_cluster_id.yml`)
   - Dynamically retrieves the OpenShift cluster ID
   - Generates unique IAM user name based on cluster ID
   - Validates cluster is running on AWS platform

3. **IAM User Management** (`roles/aws_iam_user_management/`)
   - Creates dedicated IAM user for CCO (if not exists)
   - Applies required IAM policies for CCO operations
   - Verifies user has proper permissions

4. **Cleanup Old Keys** (`tasks/04_cleanup_old_keys.yml`)
   - Identifies and removes orphaned AWS access keys
   - Safely cleans up old credentials from previous rotations
   - Prevents accumulation of unused access keys

5. **Key Rotation** (`tasks/05_rotate_iam_access_key.yml`)
   - Backs up current access key information
   - Deactivates and deletes existing access keys
   - Creates new access key for CCO IAM user
   - Validates new key functionality

6. **Update CCO Secret** (`tasks/06_update_cco_root_secret.yml`)
   - Backs up current CCO secret
   - Updates `kube-system/aws-creds` secret with new credentials
   - Verifies secret update was successful
   - Adds tracking annotations

7. **Component Credential Rotation** (`tasks/07_rotate_component_credentials.yml`)
   - Lists all CredentialsRequest objects
   - Deletes component secrets to trigger CCO re-minting
   - Waits for CCO to recreate credentials
   - Verifies all components have new credentials

8. **Verification** (`tasks/08_post_rotation_verification.yml`)
   - Checks health of CCO and related cluster operators
   - Validates all components are functioning
   - Confirms no degraded operators
   - Provides rotation status summary

### Key Design Decisions

- **Idempotency**: All tasks are designed to be safely re-runnable
- **Safety First**: Extensive validation and backup procedures
- **Cleanup Before Rotation**: Old keys are cleaned up before creating new ones to avoid conflicts
- **Granular Tagging**: Each step can be run independently for troubleshooting
- **Comprehensive Logging**: All operations are logged with timestamps and metadata

## Safety Features

- **Backup Creation**: Automatic backup of all credentials before rotation
- **Dry Run Mode**: Test the playbook without making changes
- **Rollback Support**: Backups can be used to restore previous state
- **Validation Checks**: Extensive verification at each step
- **Confirmation Prompts**: Optional confirmations for destructive operations

## Monitoring and Logging

- Rotation logs are stored in `logs/` directory
- Backup files are stored in `backups/` directory
- Each rotation creates a metadata file with operation details
- All operations include timestamps and cluster identification

## Troubleshooting

### Common Issues

1. **AWS Permission Errors**
   - Verify IAM permissions are correctly configured
   - Check AWS credentials are valid and not expired

2. **OpenShift Connectivity Issues**
   - Confirm kubeconfig is valid and accessible
   - Verify cluster admin permissions

3. **CCO Not in Mint Mode**
   - Check cluster installation method
   - Verify `aws-creds` secret exists in `kube-system` namespace

4. **Operator Degradation**
   - Allow additional time for operators to stabilize
   - Check operator logs for specific issues

### Recovery Procedures

If rotation fails:

1. Check logs in `logs/` directory for specific errors
2. Use backup files in `backups/` to restore previous state
3. Run verification tasks independently to identify issues
4. Contact support with log files and error messages

## Security Considerations

- Store vault password securely
- Regularly rotate the AWS credentials used for rotation
- Monitor AWS CloudTrail for rotation activities
- Review and audit rotation logs regularly
- Follow principle of least privilege for all credentials

## Maintenance

- Review and update IAM policies as OpenShift versions change
- Test rotation process in non-production environments
- Update CLI tools to latest versions
- Monitor for new OpenShift credential requirements

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review logs for specific error messages
3. Test in a non-production environment first
4. Consult OpenShift documentation for CCO-specific issues 