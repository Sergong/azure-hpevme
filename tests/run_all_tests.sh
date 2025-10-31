#!/usr/bin/env bash
# Run all unit tests for Azure KVM nested VM networking infrastructure

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to print section headers
print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Function to print test results
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2 PASSED${NC}"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}✗ $2 FAILED${NC}"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${BLUE}Starting test suite for Azure KVM Nested VM Networking${NC}"
echo -e "Project root: ${PROJECT_ROOT}"
echo -e "Test directory: ${SCRIPT_DIR}"

# ===========================================
# Test 1 & 2: Terraform Tests
# ===========================================
print_header "Running Terraform Tests"

if command -v terraform &> /dev/null; then
    echo "Terraform version:"
    terraform version
    echo ""
    
    # Check if we're in a git repo and have terraform files
    if [ -f "$PROJECT_ROOT/main.tf" ]; then
        cd "$PROJECT_ROOT"
        
        # Initialize Terraform if needed
        if [ ! -d ".terraform" ]; then
            echo "Initializing Terraform..."
            terraform init -backend=false
        fi
        
        # Run Terraform tests
        echo "Running Terraform test suite..."
        if terraform test -test-directory="$SCRIPT_DIR/terraform" 2>&1; then
            print_result 0 "Terraform Tests (Route Tables & IP Forwarding)"
        else
            print_result 1 "Terraform Tests (Route Tables & IP Forwarding)"
        fi
    else
        echo -e "${YELLOW}⚠ Skipping Terraform tests - main.tf not found${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Terraform not installed - skipping Terraform tests${NC}"
fi

# ===========================================
# Test 3: Bash/BATS Tests
# ===========================================
print_header "Running Bash Script Tests (BATS)"

if command -v bats &> /dev/null; then
    echo "BATS version:"
    bats --version
    echo ""
    
    if [ -f "$SCRIPT_DIR/bash/test_setup_routes.bats" ]; then
        cd "$SCRIPT_DIR/bash"
        
        # Make test file executable
        chmod +x test_setup_routes.bats
        
        # Run BATS tests for routes
        if bats test_setup_routes.bats; then
            print_result 0 "Bash Script Tests (setup-nested-vm-routes.sh)"
        else
            print_result 1 "Bash Script Tests (setup-nested-vm-routes.sh)"
        fi
    else
        echo -e "${YELLOW}⚠ BATS routes test file not found${NC}"
    fi
    
    # Test NAT script
    if [ -f "$SCRIPT_DIR/bash/test_setup_nat.bats" ]; then
        cd "$SCRIPT_DIR/bash"
        
        # Make test file executable
        chmod +x test_setup_nat.bats
        
        # Run BATS tests for NAT
        if bats test_setup_nat.bats; then
            print_result 0 "Bash Script Tests (setup-nested-vm-nat.sh)"
        else
            print_result 1 "Bash Script Tests (setup-nested-vm-nat.sh)"
        fi
    else
        echo -e "${YELLOW}⚠ BATS NAT test file not found${NC}"
    fi
else
    echo -e "${YELLOW}⚠ BATS not installed - skipping Bash tests${NC}"
    echo "Install with: brew install bats-core (macOS) or apt install bats (Ubuntu)"
fi

# ===========================================
# Test 4 & 5: Ansible Tests
# ===========================================
print_header "Running Ansible Tests"

if command -v ansible-playbook &> /dev/null; then
    echo "Ansible version:"
    ansible --version | head -1
    echo ""
    
    # Check for required collections
    echo "Checking Ansible collections..."
    if ansible-galaxy collection list | grep -q "community.general"; then
        echo "✓ community.general collection installed"
    else
        echo "Installing community.general collection..."
        ansible-galaxy collection install community.general
    fi
    echo ""
    
    # Test OVS Bridge Configuration
    if [ -f "$SCRIPT_DIR/ansible/test_ovs_bridge.yml" ]; then
        cd "$SCRIPT_DIR/ansible"
        echo "Running OVS Bridge tests..."
        if ansible-playbook test_ovs_bridge.yml; then
            print_result 0 "Ansible Tests (OVS Bridge Configuration)"
        else
            print_result 1 "Ansible Tests (OVS Bridge Configuration)"
        fi
    else
        echo -e "${YELLOW}⚠ OVS Bridge test file not found${NC}"
    fi
    
    # Test UFW Rules Configuration
    if [ -f "$SCRIPT_DIR/ansible/test_ufw_rules.yml" ]; then
        cd "$SCRIPT_DIR/ansible"
        echo "Running UFW Rules tests..."
        if ansible-playbook test_ufw_rules.yml; then
            print_result 0 "Ansible Tests (UFW Rules Configuration)"
        else
            print_result 1 "Ansible Tests (UFW Rules Configuration)"
        fi
    else
        echo -e "${YELLOW}⚠ UFW Rules test file not found${NC}"
    fi
    
    # Test NAT Configuration
    if [ -f "$SCRIPT_DIR/ansible/test_nat_config.yml" ]; then
        cd "$SCRIPT_DIR/ansible"
        echo "Running NAT configuration tests..."
        if ansible-playbook test_nat_config.yml; then
            print_result 0 "Ansible Tests (NAT Configuration)"
        else
            print_result 1 "Ansible Tests (NAT Configuration)"
        fi
    else
        echo -e "${YELLOW}⚠ NAT configuration test file not found${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Ansible not installed - skipping Ansible tests${NC}"
    echo "Install with: pip install ansible"
fi

# ===========================================
# Final Results Summary
# ===========================================
print_header "Test Results Summary"

echo "Total test suites: $TOTAL_TESTS"
echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"

if [ $FAILED_TESTS -gt 0 ]; then
    echo -e "${RED}Failed: $FAILED_TESTS${NC}"
else
    echo -e "${GREEN}Failed: 0${NC}"
fi

echo ""

if [ $FAILED_TESTS -eq 0 ] && [ $TOTAL_TESTS -gt 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓ ALL TESTS PASSED!${NC}"
    echo -e "${GREEN}========================================${NC}"
    exit 0
elif [ $TOTAL_TESTS -eq 0 ]; then
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}⚠ NO TESTS WERE RUN${NC}"
    echo -e "${YELLOW}Please install test dependencies${NC}"
    echo -e "${YELLOW}========================================${NC}"
    exit 1
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    echo -e "${RED}========================================${NC}"
    exit 1
fi
