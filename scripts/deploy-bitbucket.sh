#!/usr/bin/env bash
#
# Deploy PR Code Reviewer to Bitbucket Repository
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
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Bitbucket configuration
BITBUCKET_WORKSPACE="${BITBUCKET_WORKSPACE:-}"
BITBUCKET_REPO="${BITBUCKET_REPO:-}"
BITBUCKET_BRANCH="${BITBUCKET_BRANCH:-main}"

# ============================================================================
# Functions
# ============================================================================

check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v git &> /dev/null; then
        log_error "Git is not installed"
        exit 1
    fi

    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed"
        exit 1
    fi

    log_info "Prerequisites check passed"
}

get_bitbucket_config() {
    echo ""
    log_step "Bitbucket Repository Configuration"
    echo ""

    if [[ -z "$BITBUCKET_WORKSPACE" ]]; then
        read -rp "Enter Bitbucket workspace: " BITBUCKET_WORKSPACE
    fi

    if [[ -z "$BITBUCKET_REPO" ]]; then
        read -rp "Enter Bitbucket repository slug: " BITBUCKET_REPO
    fi

    if [[ -z "$BITBUCKET_WORKSPACE" || -z "$BITBUCKET_REPO" ]]; then
        log_error "Workspace and repository are required"
        exit 1
    fi

    log_info "Target: $BITBUCKET_WORKSPACE/$BITBUCKET_REPO"
}

clone_and_deploy() {
    log_info "Deploying files to Bitbucket repository..."

    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap "rm -rf $tmp_dir" EXIT

    echo ""
    log_step "Cloning repository..."
    echo "You may be prompted for Bitbucket credentials."
    echo ""

    # Clone the target repo
    git clone --depth 1 -b "$BITBUCKET_BRANCH" \
        "https://bitbucket.org/${BITBUCKET_WORKSPACE}/${BITBUCKET_REPO}.git" \
        "$tmp_dir/repo"

    # Create directories
    mkdir -p "$tmp_dir/repo/scripts"

    # Copy files
    cp "$PROJECT_ROOT/bitbucket-pipelines.yml" "$tmp_dir/repo/"
    cp "$PROJECT_ROOT/scripts/review-pr.sh" "$tmp_dir/repo/scripts/"
    chmod +x "$tmp_dir/repo/scripts/review-pr.sh"

    # Commit and push
    cd "$tmp_dir/repo"
    git add bitbucket-pipelines.yml scripts/review-pr.sh

    if git diff --cached --quiet; then
        log_info "No changes to deploy (files already exist)"
    else
        git commit -m "Add automated PR code review pipeline

- Add Bitbucket Pipelines configuration for PR review
- Add portable review script using GitHub Copilot CLI"

        log_step "Pushing to Bitbucket..."
        git push origin "$BITBUCKET_BRANCH"
        log_info "Files deployed successfully"
    fi
}

print_manual_steps() {
    echo ""
    echo "=============================================="
    echo -e "${GREEN}Deployment Complete!${NC}"
    echo "=============================================="
    echo ""
    echo "Files deployed to: $BITBUCKET_WORKSPACE/$BITBUCKET_REPO"
    echo ""
    echo -e "${YELLOW}Manual Steps Required:${NC}"
    echo ""
    echo "1. Enable Pipelines:"
    echo "   - Go to Repository settings → Pipelines → Settings"
    echo "   - Toggle 'Enable Pipelines'"
    echo ""
    echo "2. Add Repository Variables:"
    echo "   - Go to Repository settings → Pipelines → Repository variables"
    echo "   - Add the following variables:"
    echo ""
    echo "   ┌─────────────────────┬────────────────────────────────────────┐"
    echo "   │ Variable            │ Description                            │"
    echo "   ├─────────────────────┼────────────────────────────────────────┤"
    echo "   │ GH_COPILOT_TOKEN    │ GitHub PAT with Copilot access         │"
    echo "   │ BITBUCKET_TOKEN     │ App password with PR write permission  │"
    echo "   └─────────────────────┴────────────────────────────────────────┘"
    echo ""
    echo "3. Create a Pull Request to test the pipeline"
    echo ""
    echo "Repository: https://bitbucket.org/$BITBUCKET_WORKSPACE/$BITBUCKET_REPO"
    echo "Pipelines:  https://bitbucket.org/$BITBUCKET_WORKSPACE/$BITBUCKET_REPO/pipelines"
    echo ""
}

# ============================================================================
# Main
# ============================================================================

main() {
    echo ""
    echo "=============================================="
    echo "  Bitbucket PR Code Reviewer - Deployment"
    echo "=============================================="
    echo ""

    check_prerequisites
    get_bitbucket_config
    clone_and_deploy
    print_manual_steps
}

main "$@"
