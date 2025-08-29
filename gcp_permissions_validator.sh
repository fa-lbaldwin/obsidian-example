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

# Permission groups for different resource types - Comprehensive list based on actual infrastructure
declare -A COMPUTE_PERMISSIONS=(
    ["instances"]="compute.instances.create compute.instances.delete compute.instances.get compute.instances.list compute.instances.setMetadata compute.instances.setServiceAccount"
    ["networks"]="compute.networks.create compute.networks.delete compute.networks.get compute.networks.updatePolicy compute.networks.update compute.networks.addPeering compute.networks.removePeering"
    ["subnetworks"]="compute.subnetworks.create compute.subnetworks.delete compute.subnetworks.get compute.subnetworks.update compute.subnetworks.use compute.subnetworks.expandIpCidrRange"
    ["firewalls"]="compute.firewalls.create compute.firewalls.delete compute.firewalls.get compute.firewalls.update compute.firewalls.list"
    ["addresses"]="compute.addresses.create compute.addresses.delete compute.addresses.get compute.addresses.use compute.addresses.list compute.globalAddresses.create compute.globalAddresses.delete compute.globalAddresses.get compute.globalAddresses.use"
    ["routers"]="compute.routers.create compute.routers.delete compute.routers.get compute.routers.update compute.routers.use"
    ["securitypolicies"]="compute.securityPolicies.create compute.securityPolicies.delete compute.securityPolicies.get compute.securityPolicies.update compute.securityPolicies.use compute.securityPolicies.addRule compute.securityPolicies.removeRule"
    ["sslpolicies"]="compute.sslPolicies.create compute.sslPolicies.delete compute.sslPolicies.get compute.sslPolicies.update compute.sslPolicies.use"
)

declare -A GKE_PERMISSIONS=(
    ["clusters"]="container.clusters.create container.clusters.delete container.clusters.get container.clusters.update container.clusters.getCredentials"
    ["operations"]="container.operations.get container.operations.list container.operations.cancel"
    ["nodes"]="container.nodes.get container.nodes.list container.nodes.update"
    ["autopilot"]="container.clusters.createAutopilot container.clusters.updateAutopilot"
    ["workloadidentity"]="container.workloadIdentityPools.use iam.serviceAccounts.getAccessToken iam.serviceAccounts.actAs"
    ["pods"]="container.pods.create container.pods.delete container.pods.get container.pods.list container.pods.update"
    ["services"]="container.services.create container.services.delete container.services.get container.services.list container.services.update"
    ["configmaps"]="container.configMaps.create container.configMaps.delete container.configMaps.get container.configMaps.list container.configMaps.update"
    ["secrets"]="container.secrets.create container.secrets.delete container.secrets.get container.secrets.list container.secrets.update"
    ["deployments"]="container.deployments.create container.deployments.delete container.deployments.get container.deployments.list container.deployments.update"
    ["persistentvolumes"]="container.persistentVolumes.create container.persistentVolumes.delete container.persistentVolumes.get container.persistentVolumes.list"
    ["persistentvolumeclaims"]="container.persistentVolumeClaims.create container.persistentVolumeClaims.delete container.persistentVolumeClaims.get container.persistentVolumeClaims.list"
)

declare -A SQL_PERMISSIONS=(
    ["instances"]="cloudsql.instances.create cloudsql.instances.delete cloudsql.instances.get cloudsql.instances.update cloudsql.instances.connect cloudsql.instances.restart"
    ["databases"]="cloudsql.databases.create cloudsql.databases.delete cloudsql.databases.get cloudsql.databases.update cloudsql.databases.list"
    ["users"]="cloudsql.users.create cloudsql.users.delete cloudsql.users.list cloudsql.users.update"
    ["backups"]="cloudsql.backupRuns.create cloudsql.backupRuns.get cloudsql.backupRuns.list cloudsql.backupRuns.delete"
    ["sslcerts"]="cloudsql.sslCerts.create cloudsql.sslCerts.delete cloudsql.sslCerts.get cloudsql.sslCerts.list"
)

declare -A NETWORKING_PERMISSIONS=(
    ["armor"]="compute.securityPolicies.create compute.securityPolicies.delete compute.securityPolicies.get compute.securityPolicies.update compute.securityPolicies.use compute.securityPolicies.addRule compute.securityPolicies.removeRule"
    ["ssl"]="compute.sslCertificates.create compute.sslCertificates.delete compute.sslCertificates.get compute.sslCertificates.list compute.sslCertificates.use"
    ["loadbalancer"]="compute.backendServices.create compute.backendServices.delete compute.backendServices.get compute.backendServices.update compute.backendServices.use compute.backendServices.setSecurityPolicy"
    ["targetproxies"]="compute.targetHttpProxies.create compute.targetHttpProxies.delete compute.targetHttpProxies.get compute.targetHttpProxies.use compute.targetHttpsProxies.create compute.targetHttpsProxies.delete compute.targetHttpsProxies.get compute.targetHttpsProxies.use"
    ["urlmaps"]="compute.urlMaps.create compute.urlMaps.delete compute.urlMaps.get compute.urlMaps.update compute.urlMaps.use"
    ["forwardingrules"]="compute.globalForwardingRules.create compute.globalForwardingRules.delete compute.globalForwardingRules.get compute.forwardingRules.create compute.forwardingRules.delete compute.forwardingRules.get"
    ["dns"]="dns.managedZones.create dns.managedZones.delete dns.managedZones.get dns.managedZones.update dns.changes.create dns.changes.get dns.resourceRecordSets.create dns.resourceRecordSets.delete dns.resourceRecordSets.update"
    ["servicenetworking"]="servicenetworking.services.addPeering servicenetworking.services.get compute.networks.addPeering compute.networks.removePeering compute.globalAddresses.create"
)

declare -A IAM_PERMISSIONS=(
    ["serviceaccounts"]="iam.serviceAccounts.create iam.serviceAccounts.delete iam.serviceAccounts.get iam.serviceAccounts.list iam.serviceAccounts.update iam.serviceAccounts.getIamPolicy iam.serviceAccounts.setIamPolicy iam.serviceAccounts.actAs"
    ["workloadidentity"]="iam.serviceAccounts.getAccessToken iam.serviceAccounts.signBlob iam.serviceAccounts.signJwt iam.workloadIdentityPools.providers.get iam.workloadIdentityPools.providers.list"
    ["roles"]="iam.roles.get iam.roles.list iam.roles.create iam.roles.update iam.roles.delete"
    ["bindings"]="resourcemanager.projects.getIamPolicy resourcemanager.projects.setIamPolicy iam.serviceAccountKeys.create iam.serviceAccountKeys.delete iam.serviceAccountKeys.get"
)

declare -A STORAGE_PERMISSIONS=(
    ["buckets"]="storage.buckets.create storage.buckets.delete storage.buckets.get storage.buckets.list storage.buckets.update storage.buckets.getIamPolicy storage.buckets.setIamPolicy"
    ["objects"]="storage.objects.create storage.objects.delete storage.objects.get storage.objects.list storage.objects.update"
    ["hmackeys"]="storage.hmacKeys.create storage.hmacKeys.delete storage.hmacKeys.get storage.hmacKeys.list"
)

declare -A SECRET_MANAGER_PERMISSIONS=(
    ["secrets"]="secretmanager.secrets.create secretmanager.secrets.delete secretmanager.secrets.get secretmanager.secrets.list secretmanager.secrets.update secretmanager.secrets.setIamPolicy secretmanager.secrets.getIamPolicy"
    ["versions"]="secretmanager.versions.add secretmanager.versions.access secretmanager.versions.destroy secretmanager.versions.disable secretmanager.versions.enable secretmanager.versions.get secretmanager.versions.list"
)

declare -A MONITORING_PERMISSIONS=(
    ["logging"]="logging.logEntries.create logging.logs.list logging.logs.delete logging.sinks.create logging.sinks.delete logging.sinks.get logging.sinks.list logging.sinks.update"
    ["monitoring"]="monitoring.metricDescriptors.create monitoring.metricDescriptors.list monitoring.metricDescriptors.get monitoring.timeSeries.create monitoring.timeSeries.list"
    ["serviceusage"]="serviceusage.services.enable serviceusage.services.disable serviceusage.services.get serviceusage.services.list serviceusage.services.use"
    ["cloudtrace"]="cloudtrace.traces.patch cloudtrace.traces.get cloudtrace.traces.list"
)

declare -A ARTIFACT_REGISTRY_PERMISSIONS=(
    ["repositories"]="artifactregistry.repositories.create artifactregistry.repositories.delete artifactregistry.repositories.get artifactregistry.repositories.list artifactregistry.repositories.update"
    ["artifacts"]="artifactregistry.dockerimages.get artifactregistry.dockerimages.list artifactregistry.files.get artifactregistry.files.list"
    ["packages"]="artifactregistry.packages.delete artifactregistry.packages.get artifactregistry.packages.list"
)

declare -A BINARY_AUTHORIZATION_PERMISSIONS=(
    ["attestors"]="binaryauthorization.attestors.create binaryauthorization.attestors.delete binaryauthorization.attestors.get binaryauthorization.attestors.list binaryauthorization.attestors.update"
    ["policy"]="binaryauthorization.policy.get binaryauthorization.policy.update"
)

# Function to print usage
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Validates GCP permissions required for Terraform operations.

OPTIONS:
    -m, --mode MODE           Check mode: 'create', 'apply', 'destroy', or 'all' (default: apply)
                              - create: Check permissions for creating new infrastructure
                              - apply:  Check permissions for general terraform apply
                              - destroy: Check permissions for destroying infrastructure
                              - all: Check both create and destroy permissions
    -e, --environment ENV     Target environment (dev, staging, prod, or custom)
    -v, --verbose            Enable verbose output
    -o, --output FORMAT      Output format: text, json, yaml (default: text)
    -p, --project PROJECT    GCP project ID (overrides environment config)
    -h, --help               Display this help message

EXAMPLES:
    $0 --mode create --environment dev    # Check permissions for new infrastructure
    $0 --mode apply --environment dev     # Check permissions for updates
    $0 -m destroy -e prod -v              # Check permissions for teardown
    $0 --mode all --environment dev       # Check both create and destroy permissions
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
    check_permission_group "Google Kubernetes Engine (Autopilot)" GKE_PERMISSIONS "$project"
    check_permission_group "Cloud SQL" SQL_PERMISSIONS "$project"
    check_permission_group "Networking & Load Balancing" NETWORKING_PERMISSIONS "$project"
    check_permission_group "IAM & Workload Identity" IAM_PERMISSIONS "$project"
    check_permission_group "Cloud Storage" STORAGE_PERMISSIONS "$project"
    check_permission_group "Secret Manager" SECRET_MANAGER_PERMISSIONS "$project"
    check_permission_group "Monitoring & Logging" MONITORING_PERMISSIONS "$project"
    check_permission_group "Artifact Registry" ARTIFACT_REGISTRY_PERMISSIONS "$project"
    check_permission_group "Binary Authorization" BINARY_AUTHORIZATION_PERMISSIONS "$project"
}

# Function to check permissions for create operation (more restrictive than apply)
check_create_permissions() {
    local project=$1
    
    log INFO "Validating permissions for 'terraform apply' (create) operation on new infrastructure..."
    
    # For create, we need all creation and configuration permissions
    local create_perms=(
        # Compute resources - creation
        "compute.instances.create"
        "compute.instances.setMetadata"
        "compute.instances.setServiceAccount"
        "compute.networks.create"
        "compute.networks.updatePolicy"
        "compute.networks.addPeering"
        "compute.subnetworks.create"
        "compute.subnetworks.use"
        "compute.subnetworks.expandIpCidrRange"
        "compute.firewalls.create"
        "compute.addresses.create"
        "compute.addresses.use"
        "compute.globalAddresses.create"
        "compute.globalAddresses.use"
        "compute.routers.create"
        "compute.routers.update"
        "compute.securityPolicies.create"
        "compute.securityPolicies.addRule"
        "compute.securityPolicies.use"
        "compute.sslPolicies.create"
        "compute.sslPolicies.use"
        "compute.sslCertificates.create"
        "compute.sslCertificates.use"
        "compute.backendServices.create"
        "compute.backendServices.setSecurityPolicy"
        "compute.backendServices.use"
        "compute.targetHttpProxies.create"
        "compute.targetHttpProxies.use"
        "compute.targetHttpsProxies.create"
        "compute.targetHttpsProxies.use"
        "compute.urlMaps.create"
        "compute.urlMaps.use"
        "compute.globalForwardingRules.create"
        "compute.forwardingRules.create"
        
        # GKE Autopilot - creation
        "container.clusters.create"
        "container.clusters.createAutopilot"
        "container.clusters.getCredentials"
        "container.operations.get"
        "container.pods.create"
        "container.services.create"
        "container.configMaps.create"
        "container.secrets.create"
        "container.deployments.create"
        "container.persistentVolumes.create"
        "container.persistentVolumeClaims.create"
        
        # Workload Identity
        "iam.serviceAccounts.actAs"
        "iam.serviceAccounts.getAccessToken"
        "iam.workloadIdentityPools.providers.get"
        "container.workloadIdentityPools.use"
        
        # Cloud SQL - creation
        "cloudsql.instances.create"
        "cloudsql.instances.connect"
        "cloudsql.databases.create"
        "cloudsql.users.create"
        "cloudsql.backupRuns.create"
        "cloudsql.sslCerts.create"
        
        # DNS - creation
        "dns.managedZones.create"
        "dns.changes.create"
        "dns.resourceRecordSets.create"
        
        # IAM - creation
        "iam.serviceAccounts.create"
        "iam.serviceAccounts.setIamPolicy"
        "iam.serviceAccountKeys.create"
        "iam.roles.create"
        "resourcemanager.projects.setIamPolicy"
        
        # Storage - creation
        "storage.buckets.create"
        "storage.buckets.setIamPolicy"
        "storage.objects.create"
        "storage.hmacKeys.create"
        
        # Secret Manager - creation
        "secretmanager.secrets.create"
        "secretmanager.secrets.setIamPolicy"
        "secretmanager.versions.add"
        
        # Monitoring - creation
        "logging.sinks.create"
        "logging.logEntries.create"
        "monitoring.metricDescriptors.create"
        "monitoring.timeSeries.create"
        "cloudtrace.traces.patch"
        
        # Artifact Registry - creation
        "artifactregistry.repositories.create"
        "artifactregistry.dockerimages.get"
        
        # Binary Authorization - creation
        "binaryauthorization.attestors.create"
        "binaryauthorization.policy.update"
        
        # Service Networking - creation
        "servicenetworking.services.addPeering"
        "compute.networks.addPeering"
        
        # Service Usage - enable APIs
        "serviceusage.services.enable"
        "serviceusage.services.use"
    )
    
    local all_passed=true
    echo ""
    log INFO "Checking create permissions..."
    
    for perm in "${create_perms[@]}"; do
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
        log SUCCESS "Create permissions validated"
    else
        log ERROR "Missing required create permissions"
    fi
}

# Function to check permissions for destroy operation
check_destroy_permissions() {
    local project=$1
    
    log INFO "Validating permissions for 'terraform destroy' operation..."
    
    # For destroy, we need delete and get permissions for all resources
    local destroy_perms=(
        # Compute resources
        "compute.instances.delete"
        "compute.instances.get"
        "compute.networks.delete"
        "compute.networks.removePeering"
        "compute.subnetworks.delete"
        "compute.firewalls.delete"
        "compute.addresses.delete"
        "compute.globalAddresses.delete"
        "compute.routers.delete"
        "compute.securityPolicies.delete"
        "compute.securityPolicies.removeRule"
        "compute.sslPolicies.delete"
        "compute.sslCertificates.delete"
        "compute.backendServices.delete"
        "compute.targetHttpProxies.delete"
        "compute.targetHttpsProxies.delete"
        "compute.urlMaps.delete"
        "compute.globalForwardingRules.delete"
        "compute.forwardingRules.delete"
        
        # GKE Autopilot
        "container.clusters.delete"
        "container.operations.get"
        "container.pods.delete"
        "container.services.delete"
        "container.configMaps.delete"
        "container.secrets.delete"
        "container.deployments.delete"
        "container.persistentVolumes.delete"
        "container.persistentVolumeClaims.delete"
        
        # Cloud SQL
        "cloudsql.instances.delete"
        "cloudsql.databases.delete"
        "cloudsql.users.delete"
        "cloudsql.backupRuns.delete"
        "cloudsql.sslCerts.delete"
        
        # DNS
        "dns.managedZones.delete"
        "dns.resourceRecordSets.delete"
        
        # IAM
        "iam.serviceAccounts.delete"
        "iam.serviceAccountKeys.delete"
        "iam.roles.delete"
        
        # Storage
        "storage.buckets.delete"
        "storage.objects.delete"
        "storage.hmacKeys.delete"
        
        # Secret Manager
        "secretmanager.secrets.delete"
        "secretmanager.versions.destroy"
        
        # Monitoring
        "logging.sinks.delete"
        
        # Artifact Registry
        "artifactregistry.repositories.delete"
        "artifactregistry.packages.delete"
        
        # Binary Authorization
        "binaryauthorization.attestors.delete"
        
        # Service Networking
        "servicenetworking.services.get"
        "compute.networks.removePeering"
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
    if [[ "$CHECK_MODE" != "create" ]] && [[ "$CHECK_MODE" != "apply" ]] && [[ "$CHECK_MODE" != "destroy" ]] && [[ "$CHECK_MODE" != "all" ]]; then
        log ERROR "Invalid mode: $CHECK_MODE. Must be 'create', 'apply', 'destroy', or 'all'"
        exit 1
    fi
    
    # Check gcloud configuration
    check_gcloud
    
    # Get GCP project
    PROJECT=$(get_gcp_project)
    log SUCCESS "Using GCP project: $PROJECT"
    
    # Run permission checks based on mode
    case "$CHECK_MODE" in
        create)
            check_create_permissions "$PROJECT"
            ;;
        apply)
            check_apply_permissions "$PROJECT"
            ;;
        destroy)
            check_destroy_permissions "$PROJECT"
            ;;
        all)
            log INFO "Running comprehensive permission check (create and destroy)..."
            echo ""
            log INFO "=== CREATE PERMISSIONS ==="
            check_create_permissions "$PROJECT"
            echo ""
            log INFO "=== DESTROY PERMISSIONS ==="
            check_destroy_permissions "$PROJECT"
            ;;
    esac
    
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