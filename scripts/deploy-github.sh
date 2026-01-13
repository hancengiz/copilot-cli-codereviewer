#!/usr/bin/env bash
#
# Deploy PR Code Reviewer to GitHub Repository
#
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Target repository (can be overridden)
TARGET_REPO="${TARGET_REPO:-}"
TARGET_BRANCH="${TARGET_BRANCH:-main}"

# ============================================================================
# Functions
# ============================================================================

check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is not installed. Install it from https://cli.github.com/"
        exit 1
    fi

    if ! gh auth status &> /dev/null; then
        log_error "Not authenticated with GitHub CLI. Run 'gh auth login' first."
        exit 1
    fi

    if ! gh extension list | grep -q "gh-copilot"; then
        log_warn "GitHub Copilot extension not installed. Installing..."
        gh extension install github/gh-copilot
    fi

    log_info "Prerequisites check passed"
}

get_target_repo() {
    if [[ -z "$TARGET_REPO" ]]; then
        echo ""
        read -rp "Enter target GitHub repository (owner/repo): " TARGET_REPO
    fi

    if [[ -z "$TARGET_REPO" ]]; then
        log_error "Repository is required"
        exit 1
    fi

    # Validate repo exists
    if ! gh repo view "$TARGET_REPO" &> /dev/null; then
        log_error "Repository '$TARGET_REPO' not found or not accessible"
        exit 1
    fi

    log_info "Target repository: $TARGET_REPO"
}

check_copilot_token() {
    log_info "Checking for GH_COPILOT_TOKEN secret..."

    if gh secret list -R "$TARGET_REPO" 2>/dev/null | grep -q "GH_COPILOT_TOKEN"; then
        log_info "GH_COPILOT_TOKEN secret already exists"
        return 0
    fi

    log_warn "GH_COPILOT_TOKEN secret not found"
    echo ""
    echo "You need to create a Personal Access Token with Copilot access."
    echo "1. Go to https://github.com/settings/tokens"
    echo "2. Generate new token (classic) with 'copilot' scope"
    echo "3. Copy the token"
    echo ""

    read -rp "Enter your GitHub PAT with Copilot access (or press Enter to skip): " token

    if [[ -n "$token" ]]; then
        echo "$token" | gh secret set GH_COPILOT_TOKEN -R "$TARGET_REPO"
        log_info "GH_COPILOT_TOKEN secret created"
    else
        log_warn "Skipping token setup. You'll need to add GH_COPILOT_TOKEN secret manually."
    fi
}

deploy_files() {
    log_info "Deploying workflow and scripts to $TARGET_REPO..."

    # Create a temporary directory
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap "rm -rf $tmp_dir" EXIT

    # Clone the target repo
    gh repo clone "$TARGET_REPO" "$tmp_dir/repo" -- --depth 1 -b "$TARGET_BRANCH"

    # Create directories
    mkdir -p "$tmp_dir/repo/.github/workflows"
    mkdir -p "$tmp_dir/repo/scripts"

    # Copy files
    cp "$PROJECT_ROOT/.github/workflows/pr-review.yml" "$tmp_dir/repo/.github/workflows/"
    cp "$PROJECT_ROOT/scripts/review-pr.sh" "$tmp_dir/repo/scripts/"
    chmod +x "$tmp_dir/repo/scripts/review-pr.sh"

    # Commit and push
    cd "$tmp_dir/repo"
    git add .github/workflows/pr-review.yml scripts/review-pr.sh

    if git diff --cached --quiet; then
        log_info "No changes to deploy (files already exist)"
    else
        git commit -m "Add automated PR code review workflow

- Add GitHub Actions workflow for PR review
- Add portable review script using GitHub Copilot CLI"

        git push origin "$TARGET_BRANCH"
        log_info "Files deployed successfully"
    fi
}

print_summary() {
    echo ""
    echo "=============================================="
    echo -e "${GREEN}Deployment Complete!${NC}"
    echo "=============================================="
    echo ""
    echo "The PR Code Reviewer has been deployed to: $TARGET_REPO"
    echo ""
    echo "Next steps:"
    echo "1. Ensure GH_COPILOT_TOKEN secret is set (if not done already)"
    echo "2. Create a Pull Request to test the workflow"
    echo "3. Check the Actions tab for workflow runs"
    echo ""
    echo "Repository: https://github.com/$TARGET_REPO"
    echo "Actions: https://github.com/$TARGET_REPO/actions"
    echo ""
}

# ============================================================================
# Main
# ============================================================================

main() {
    echo ""
    echo "=========================================="
    echo "  GitHub PR Code Reviewer - Deployment"
    echo "=========================================="
    echo ""

    check_prerequisites
    get_target_repo
    check_copilot_token
    deploy_files
    print_summary
}

main "$@"
