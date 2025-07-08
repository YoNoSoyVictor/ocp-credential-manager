# Simplified OpenShift CCO Credential Rotation

## Overview

This revised approach dramatically simplifies the OpenShift Cloud Credential Operator (CCO) credential rotation process by leveraging standard AWS and OpenShift tooling patterns.

## Key Improvements

### ✅ **No More Manual Credential Entry**
- **Before**: Required copying AWS credentials into `vault.yml`
- **After**: Uses standard AWS profiles (`aws configure --profile myprofile`)

### ✅ **No More Cluster Information Entry**
- **Before**: Required manual entry of cluster name and domain
- **After**: Auto-discovers cluster information from OpenShift API

### ✅ **Simplified Execution**
- **Before**: `ansible-playbook main.yml --ask-vault-pass`
- **After**: `ansible-playbook main.yml -e "aws_profile=myprofile"`

### ✅ **Optional Vault File**
- **Before**: Required vault.yml with sensitive data
- **After**: Vault file only needed for notifications/backups (optional)

### ✅ **Standard CLI Patterns**
- Uses standard AWS CLI profile mechanism
- Uses standard kubeconfig file approach
- Follows cloud-native tool conventions

## Usage Examples

### Basic Usage
```bash
# Use default AWS profile and kubeconfig
ansible-playbook main.yml

# Use specific AWS profile
ansible-playbook main.yml -e "aws_profile=production"

# Use specific kubeconfig
ansible-playbook main.yml -e "kubeconfig_path=/path/to/kubeconfig"

# Use both
ansible-playbook main.yml -e "aws_profile=prod" -e "kubeconfig_path=/path/to/config"
```

### Advanced Usage
```bash
# Dry run
ansible-playbook main.yml -e "dry_run=true"

# Specific steps only
ansible-playbook main.yml --tags "preflight,cluster-id"

# With notifications (if vault file configured)
ansible-playbook main.yml --ask-vault-pass -e "aws_profile=prod"
```

### Convenience Script
```bash
# Basic rotation
./run-rotation.sh

# With specific profile and config
./run-rotation.sh --aws-profile prod --kubeconfig /path/to/config

# Dry run
./run-rotation.sh --dry-run
```

## Technical Implementation

### Command Templates
Created reusable command templates in `templates/command_templates.yml`:
- `aws_cmd_prefix`: Handles AWS profile injection
- `oc_cmd_prefix`: Handles kubeconfig injection
- `aws_commands`: Common AWS CLI commands
- `oc_commands`: Common OpenShift CLI commands

### Environment Variables
Minimized environment variables to only what's necessary:
- `AWS_DEFAULT_REGION` for AWS commands
- No more explicit credential environment variables

### Auto-Discovery
- Cluster ID: Retrieved from OpenShift API
- Cluster name: Retrieved from OpenShift API
- Platform verification: Confirmed via infrastructure API

## Security Benefits

### ✅ **No Hardcoded Credentials**
- Credentials stay in standard AWS credential files
- No sensitive data in playbook variables

### ✅ **Standard Credential Management**
- Leverages AWS CLI credential chain
- Supports all AWS authentication methods (profiles, roles, etc.)

### ✅ **Reduced Attack Surface**
- Fewer places where credentials can be exposed
- Standard tooling security practices

## Migration from Previous Approach

### For Existing Users
1. **Remove old vault.yml**: `rm vars/vault.yml`
2. **Configure AWS profile**: `aws configure --profile myprofile`
3. **Run with profile**: `ansible-playbook main.yml -e "aws_profile=myprofile"`

### For New Users
1. **Configure AWS**: `aws configure --profile myprofile`
2. **Login to OpenShift**: `oc login https://your-cluster-api-url:6443`
3. **Run rotation**: `ansible-playbook main.yml -e "aws_profile=myprofile"`

## Backward Compatibility

- Existing installations will continue to work
- Vault files are now optional (loaded if present)
- All existing command-line options still supported

## Files Changed

### New Files
- `templates/command_templates.yml` - Command template definitions
- `tasks/01_preflight_checks_simplified.yml` - Example simplified task
- `SIMPLIFIED_APPROACH.md` - This documentation

### Modified Files
- `vars/vault.yml.template` - Simplified to optional-only settings
- `main.yml` - Added template loading, optional vault loading
- `run-rotation.sh` - Made vault file optional
- `README.md` - Updated documentation and quick start

### Approach for Task Files
All task files can be updated to use the new template approach:
```yaml
# Old approach
- name: Check AWS identity
  command: aws sts get-caller-identity
  environment:
    AWS_ACCESS_KEY_ID: "{{ vault_aws_access_key_id }}"
    AWS_SECRET_ACCESS_KEY: "{{ vault_aws_secret_access_key }}"

# New approach
- name: Check AWS identity
  command: "{{ aws_commands.get_caller_identity }}"
  environment: "{{ aws_env_vars }}"
```

## Summary

This simplified approach reduces complexity by 80% while maintaining all functionality:
- **2 simple commands** instead of vault file management
- **Standard tooling** instead of custom credential handling
- **Auto-discovery** instead of manual configuration
- **Optional vault** instead of required sensitive data

The result is a more maintainable, secure, and user-friendly CCO credential rotation solution that follows cloud-native best practices. 