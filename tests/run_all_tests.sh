#!/usr/bin/env bash
# Run all unit tests for Azure KVM VXLAN overlay infrastructure

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

echo -e "${BLUE}Starting test suite for Azure KVM VXLAN Overlay Infrastructure${NC}"
echo -e "Project root: ${PROJECT_ROOT}"
echo -e "Test directory: ${SCRIPT_DIR}"

# ===========================================
# Test 1: OpenTofu Tests
# ===========================================
print_header "Running OpenTofu Tests"

if command -v tofu &> /dev/null; then
    echo "OpenTofu version:"
    tofu version
    echo ""
    
    # Check if we're in a git repo and have OpenTofu files
    if [ -f "$PROJECT_ROOT/main.tf" ]; then
        cd "$PROJECT_ROOT"
        
        # Initialize OpenTofu if needed
        if [ ! -d ".terraform" ]; then
            echo "Initializing OpenTofu..."
            tofu init -backend=false
        fi
        
        # Run OpenTofu tests
        echo "Running OpenTofu test suite..."
        if tofu test 2>&1; then
            print_result 0 "OpenTofu Tests"
        else
            print_result 1 "OpenTofu Tests"
        fi
    else
        echo -e "${YELLOW}⚠ Skipping OpenTofu tests - main.tf not found${NC}"
    fi
else
    echo -e "${YELLOW}⚠ OpenTofu not installed - skipping OpenTofu tests${NC}"
fi

# ===========================================
# Test 2: Ansible Tests
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
    
    cd "$SCRIPT_DIR/ansible"
    echo "Running Ansible tests..."
    if ansible-playbook test_ovs_bridge.yml test_nat_config.yml test_iptables_persistent.yml; then
        print_result 0 "Ansible Tests"
    else
        print_result 1 "Ansible Tests"
    fi
else
    echo -e "${YELLOW}⚠ Ansible not installed - skipping Ansible tests${NC}"
    echo "Install with: pip install ansible"
fi

# ===========================================
# Test 3: Bash/BATS Tests
# ===========================================
print_header "Running Bash Script Tests (BATS)"

if command -v bats &> /dev/null; then
    echo "BATS version:"
    bats --version
    echo ""
    
    if [ -f "$SCRIPT_DIR/bash/test_setup_nat.bats" ]; then
        cd "$SCRIPT_DIR/bash"
        
        # Make test file executable
        chmod +x test_setup_nat.bats
        
        # Run BATS tests
        if bats test_setup_nat.bats; then
            print_result 0 "Bash Script Tests"
        else
            print_result 1 "Bash Script Tests"
        fi
    else
        echo -e "${YELLOW}⚠ BATS test file not found${NC}"
    fi
else
    echo -e "${YELLOW}⚠ BATS not installed - skipping Bash tests${NC}"
    echo "Install with: brew install bats-core (macOS) or apt install bats (Ubuntu)"
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