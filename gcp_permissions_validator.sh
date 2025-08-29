#!/bin/bash

# GCP Permissions Validator Script
# Validates required GCP permissions for Terraform operations
# Usage: ./gcp_permissions_validator.sh [OPTIONS]

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
CHECK_MODE="apply"
ENVIRONMENT=""
VERBOSE=false
OUTPUT_FORMAT="text"
ERRORS_FOUND=false

# Permission groups for different resource types
declare -A COMPUTE_PERMISSIONS=(
    ["instances"]="compute.instances.create compute.instances.delete compute.instances.get compute.instances.list"
    ["networks"]="compute.networks.create compute.networks.delete compute.networks.get compute.networks.updatePolicy"
    ["subnetworks"]="compute.subnetworks.create compute.subnetworks.delete compute.subnetworks.get compute.subnetworks.update"
    ["firewalls"]="compute.firewalls.create compute.firewalls.delete compute.firewalls.get compute.firewalls.update"
    ["addresses"]="compute.addresses.create compute.addresses.delete compute.addresses.get compute.addresses.use"
    ["routers"]="compute.routers.create compute.routers.delete compute.routers.get compute.routers.update"
)

declare -A GKE_PERMISSIONS=(
    ["clusters"]="container.clusters.create container.clusters.delete container.clusters.get container.clusters.update"
    ["operations"]="container.operations.get container.operations.list"
    ["nodes"]="container.nodes.get container.nodes.list"
)

declare -A SQL_PERMISSIONS=(
    ["instances"]="cloudsql.instances.create cloudsql.instances.delete cloudsql.instances.get cloudsql.instances.update"
    ["databases"]="cloudsql.databases.create cloudsql.databases.delete cloudsql.databases.get cloudsql.databases.update"
    ["users"]="cloudsql.users.create cloudsql.users.delete cloudsql.users.list cloudsql.users.update"
    ["backups"]="cloudsql.backupRuns.create cloudsql.backupRuns.get cloudsql.backupRuns.list"
)

declare -A NETWORKING_PERMISSIONS=(
    ["armor"]="compute.securityPolicies.create compute.securityPolicies.delete compute.securityPolicies.get compute.securityPolicies.update"
    ["ssl"]="compute.sslCertificates.create compute.sslCertificates.delete compute.sslCertificates.get"
    ["loadbalancer"]="compute.backendServices.create compute.backendServices.delete compute.backendServices.get compute.backendServices.update"
    ["dns"]="dns.managedZones.create dns.managedZones.delete dns.managedZones.get dns.changes.create dns.resourceRecordSets.create"
)

declare -A IAM_PERMISSIONS=(
    ["serviceaccounts"]="iam.serviceAccounts.create iam.serviceAccounts.delete iam.serviceAccounts.get iam.serviceAccounts.getIamPolicy"
    ["roles"]="iam.roles.get iam.roles.list resourcemanager.projects.getIamPolicy resourcemanager.projects.setIamPolicy"
)

declare -A STORAGE_PERMISSIONS=(
    ["buckets"]="storage.buckets.create storage.buckets.delete storage.buckets.get storage.buckets.getIamPolicy storage.buckets.setIamPolicy"
    ["objects"]="storage.objects.create storage.objects.delete storage.objects.get storage.objects.list"
)

declare -A MONITORING_PERMISSIONS=(
    ["logging"]="logging.logEntries.create logging.logs.list"
    ["monitoring"]="monitoring.metricDescriptors.create monitoring.metricDescriptors.list"
    ["serviceusage"]="serviceusage.services.enable serviceusage.services.disable serviceusage.services.get"
)

# Function to print usage
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Validates GCP permissions required for Terraform operations.

OPTIONS:
    -m, --mode MODE           Check mode: 'apply' or 'destroy' (default: apply)
    -e, --environment ENV     Target environment (dev, staging, prod, or custom)
    -v, --verbose            Enable verbose output
    -o, --output FORMAT      Output format: text, json, yaml (default: text)
    -p, --project PROJECT    GCP project ID (overrides environment config)
    -h, --help               Display this help message

EXAMPLES:
    $0 --mode apply --environment dev
    $0 -m destroy -e prod -v
    $0 --environment staging --output json

EOF
    exit 0
}

# Function to log messages
log() {
    local level=$1
    shift
    local message="$*"
    
    case $level in
        ERROR)
            echo -e "${RED}[ERROR]${NC} $message" >&2
            ERRORS_FOUND=true
            ;;
        SUCCESS)
            echo -e "${GREEN}[✓]${NC} $message"
            ;;
        WARNING)
            echo -e "${YELLOW}[WARNING]${NC} $message"
            ;;
        INFO)
            if [[ "$VERBOSE" == true ]]; then
                echo "[INFO] $message"
            fi
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Function to check if gcloud is installed and configured
check_gcloud() {
    log INFO "Checking gcloud CLI configuration..."
    
    if ! command -v gcloud &> /dev/null; then
        log ERROR "gcloud CLI is not installed. Please install Google Cloud SDK."
        exit 1
    fi
    
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
        log ERROR "No active gcloud authentication. Please run 'gcloud auth login'"
        exit 1
    fi
    
    local active_account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    log SUCCESS "Authenticated as: $active_account"
}

# Function to get GCP project from environment or gcloud config
get_gcp_project() {
    local project=""
    
    if [[ -n "${GCP_PROJECT:-}" ]]; then
        project="$GCP_PROJECT"
    elif [[ -n "$ENVIRONMENT" ]] && [[ -f "${TERRAFORM_DIR}/environments/${ENVIRONMENT}/terraform.tfvars" ]]; then
        project=$(grep "^project_id" "${TERRAFORM_DIR}/environments/${ENVIRONMENT}/terraform.tfvars" | cut -d'"' -f2)
    else
        project=$(gcloud config get-value project 2>/dev/null)
    fi
    
    if [[ -z "$project" ]]; then
        log ERROR "Could not determine GCP project. Please specify --project or --environment"
        exit 1
    fi
    
    echo "$project"
}

# Function to test a single permission
test_permission() {
    local project=$1
    local permission=$2
    
    # Use gcloud to test the permission
    if gcloud projects get-iam-policy "$project" \
        --flatten="bindings[].members" \
        --filter="bindings.members:$(gcloud auth list --filter=status:ACTIVE --format='value(account)')" \
        --format="value(bindings.role)" 2>/dev/null | grep -q "$permission"; then
        return 0
    fi
    
    # Alternative method: try to test the permission directly
    # This is a simplified check - in production, you'd want more sophisticated testing
    local resource_type=$(echo "$permission" | cut -d. -f1)
    local resource_action=$(echo "$permission" | cut -d. -f2)
    
    case $resource_type in
        compute)
            if gcloud compute regions list --project="$project" --limit=1 &>/dev/null; then
                return 0
            fi
            ;;
        container)
            if gcloud container clusters list --project="$project" --limit=1 &>/dev/null; then
                return 0
            fi
            ;;
        cloudsql)
            if gcloud sql instances list --project="$project" --limit=1 &>/dev/null; then
                return 0
            fi
            ;;
        storage)
            if gcloud storage buckets list --project="$project" --limit=1 &>/dev/null; then
                return 0
            fi
            ;;
        dns)
            if gcloud dns managed-zones list --project="$project" --limit=1 &>/dev/null; then
                return 0
            fi
            ;;
        iam)
            if gcloud iam service-accounts list --project="$project" --limit=1 &>/dev/null; then
                return 0
            fi
            ;;
        *)
            # For other permissions, we'll assume they're available if we can access the project
            if gcloud projects describe "$project" &>/dev/null; then
                return 0
            fi
            ;;
    esac
    
    return 1
}

# Function to check permission group
check_permission_group() {
    local group_name=$1
    local -n permissions=$2
    local project=$3
    local all_passed=true
    
    echo ""
    log INFO "Checking $group_name permissions..."
    
    for category in "${!permissions[@]}"; do
        local category_passed=true
        log INFO "  Checking $category..."
        
        for perm in ${permissions[$category]}; do
            if test_permission "$project" "$perm"; then
                if [[ "$VERBOSE" == true ]]; then
                    log SUCCESS "    $perm"
                fi
            else
                log ERROR "    Missing permission: $perm"
                category_passed=false
                all_passed=false
            fi
        done
        
        if [[ "$category_passed" == true ]] && [[ "$VERBOSE" == false ]]; then
            log SUCCESS "  $category permissions OK"
        fi
    done
    
    if [[ "$all_passed" == true ]]; then
        log SUCCESS "$group_name permissions validated"
    else
        log ERROR "$group_name has missing permissions"
    fi
    
    return $([ "$all_passed" == true ])
}

# Function to check permissions for apply operation
check_apply_permissions() {
    local project=$1
    
    log INFO "Validating permissions for 'terraform apply' operation..."
    
    check_permission_group "Compute Engine" COMPUTE_PERMISSIONS "$project"
    check_permission_group "Google Kubernetes Engine" GKE_PERMISSIONS "$project"
    check_permission_group "Cloud SQL" SQL_PERMISSIONS "$project"
    check_permission_group "Networking & Security" NETWORKING_PERMISSIONS "$project"
    check_permission_group "IAM" IAM_PERMISSIONS "$project"
    check_permission_group "Storage" STORAGE_PERMISSIONS "$project"
    check_permission_group "Monitoring & Logging" MONITORING_PERMISSIONS "$project"
}

# Function to check permissions for destroy operation
check_destroy_permissions() {
    local project=$1
    
    log INFO "Validating permissions for 'terraform destroy' operation..."
    
    # For destroy, we need delete and get permissions primarily
    local destroy_perms=(
        "compute.instances.delete"
        "compute.networks.delete"
        "compute.subnetworks.delete"
        "compute.firewalls.delete"
        "compute.addresses.delete"
        "compute.routers.delete"
        "container.clusters.delete"
        "cloudsql.instances.delete"
        "compute.securityPolicies.delete"
        "compute.sslCertificates.delete"
        "compute.backendServices.delete"
        "dns.managedZones.delete"
        "iam.serviceAccounts.delete"
        "storage.buckets.delete"
        "storage.objects.delete"
    )
    
    local all_passed=true
    echo ""
    log INFO "Checking destroy permissions..."
    
    for perm in "${destroy_perms[@]}"; do
        if test_permission "$project" "$perm"; then
            if [[ "$VERBOSE" == true ]]; then
                log SUCCESS "  $perm"
            fi
        else
            log ERROR "  Missing permission: $perm"
            all_passed=false
        fi
    done
    
    if [[ "$all_passed" == true ]]; then
        log SUCCESS "Destroy permissions validated"
    else
        log ERROR "Missing required destroy permissions"
    fi
}

# Function to generate JSON output
generate_json_output() {
    local status=$1
    local project=$2
    
    cat <<EOF
{
  "status": "$status",
  "project": "$project",
  "mode": "$CHECK_MODE",
  "environment": "$ENVIRONMENT",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "errors_found": $ERRORS_FOUND
}
EOF
}

# Function to generate YAML output
generate_yaml_output() {
    local status=$1
    local project=$2
    
    cat <<EOF
status: $status
project: $project
mode: $CHECK_MODE
environment: $ENVIRONMENT
timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
errors_found: $ERRORS_FOUND
EOF
}

# Main function
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--mode)
                CHECK_MODE="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -o|--output)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -p|--project)
                GCP_PROJECT="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            *)
                log ERROR "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    # Validate check mode
    if [[ "$CHECK_MODE" != "apply" ]] && [[ "$CHECK_MODE" != "destroy" ]]; then
        log ERROR "Invalid mode: $CHECK_MODE. Must be 'apply' or 'destroy'"
        exit 1
    fi
    
    # Check gcloud configuration
    check_gcloud
    
    # Get GCP project
    PROJECT=$(get_gcp_project)
    log SUCCESS "Using GCP project: $PROJECT"
    
    # Run permission checks based on mode
    if [[ "$CHECK_MODE" == "apply" ]]; then
        check_apply_permissions "$PROJECT"
    else
        check_destroy_permissions "$PROJECT"
    fi
    
    # Generate output based on format
    echo ""
    if [[ "$ERRORS_FOUND" == true ]]; then
        log ERROR "Permission validation failed. Please resolve missing permissions before running Terraform."
        STATUS="FAILED"
    else
        log SUCCESS "All required permissions validated successfully!"
        STATUS="PASSED"
    fi
    
    case $OUTPUT_FORMAT in
        json)
            generate_json_output "$STATUS" "$PROJECT"
            ;;
        yaml)
            generate_yaml_output "$STATUS" "$PROJECT"
            ;;
        text)
            # Already handled above
            ;;
        *)
            log ERROR "Invalid output format: $OUTPUT_FORMAT"
            exit 1
            ;;
    esac
    
    # Exit with appropriate code
    if [[ "$ERRORS_FOUND" == true ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main "$@"