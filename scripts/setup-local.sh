#!/usr/bin/env bash
#
# Setup Local Environment for PR Code Reviewer
#
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $*"; }

# ============================================================================
# Functions
# ============================================================================

check_gh_cli() {
    log_step "Checking GitHub CLI..."

    if command -v gh &> /dev/null; then
        log_info "GitHub CLI is installed: $(gh --version | head -1)"
        return 0
    fi

    log_warn "GitHub CLI is not installed"
    echo ""
    echo "Install GitHub CLI:"
    echo "  macOS:   brew install gh"
    echo "  Linux:   See https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
    echo "  Windows: winget install GitHub.cli"
    echo ""

    read -rp "Press Enter after installing, or Ctrl+C to exit..."

    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI still not found"
        exit 1
    fi
}

check_gh_auth() {
    log_step "Checking GitHub authentication..."

    if gh auth status &> /dev/null; then
        log_info "GitHub CLI is authenticated"
        gh auth status
        return 0
    fi

    log_warn "Not authenticated with GitHub CLI"
    echo ""
    log_info "Starting GitHub authentication..."
    gh auth login

    if ! gh auth status &> /dev/null; then
        log_error "Authentication failed"
        exit 1
    fi
}

check_copilot_extension() {
    log_step "Checking GitHub Copilot extension..."

    if gh extension list 2>/dev/null | grep -q "gh-copilot"; then
        log_info "GitHub Copilot extension is installed"
        return 0
    fi

    log_warn "GitHub Copilot extension not installed"
    log_info "Installing GitHub Copilot extension..."

    gh extension install github/gh-copilot

    if ! gh extension list | grep -q "gh-copilot"; then
        log_error "Failed to install Copilot extension"
        exit 1
    fi

    log_info "GitHub Copilot extension installed successfully"
}

test_copilot() {
    log_step "Testing GitHub Copilot..."

    echo ""
    log_info "Running a quick Copilot test..."

    if echo "What is 2+2?" | gh copilot explain 2>/dev/null; then
        log_info "Copilot is working!"
    else
        log_warn "Copilot test may have failed. This could be due to:"
        echo "  - No Copilot subscription on your GitHub account"
        echo "  - Rate limiting"
        echo "  - Network issues"
        echo ""
        echo "You can still proceed, but the review might not work."
    fi
}

check_dependencies() {
    log_step "Checking other dependencies..."

    local missing=()

    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi

    if ! command -v curl &> /dev/null; then
        missing+=("curl")
    fi

    if ! command -v git &> /dev/null; then
        missing+=("git")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "Missing dependencies: ${missing[*]}"
        echo ""
        echo "Install them with:"
        echo "  macOS:  brew install ${missing[*]}"
        echo "  Ubuntu: sudo apt-get install ${missing[*]}"
        echo ""
    else
        log_info "All dependencies are installed"
    fi
}

print_usage() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    echo ""
    echo "=============================================="
    echo -e "${GREEN}Local Setup Complete!${NC}"
    echo "=============================================="
    echo ""
    echo "You can now run the code reviewer locally:"
    echo ""
    echo "  # Navigate to your git repository"
    echo "  cd /path/to/your/repo"
    echo ""
    echo "  # Run the review against main branch"
    echo "  PLATFORM=local $script_dir/review-pr.sh"
    echo ""
    echo "  # Or specify a different base branch"
    echo "  BASE_BRANCH=develop PLATFORM=local $script_dir/review-pr.sh"
    echo ""
    echo "  # Enable debug output"
    echo "  DEBUG=true PLATFORM=local $script_dir/review-pr.sh"
    echo ""
}

# ============================================================================
# Main
# ============================================================================

main() {
    echo ""
    echo "=============================================="
    echo "  PR Code Reviewer - Local Setup"
    echo "=============================================="
    echo ""

    check_gh_cli
    check_gh_auth
    check_copilot_extension
    check_dependencies
    test_copilot
    print_usage
}

main "$@"
