#!/usr/bin/env bash
#
# PR Code Review Script
# Portable script that works with GitHub, Bitbucket, and locally
#
set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Platform detection (github, bitbucket, local)
PLATFORM="${PLATFORM:-local}"

# GitHub specific
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-}"
PR_NUMBER="${PR_NUMBER:-}"

# Bitbucket specific
BITBUCKET_TOKEN="${BITBUCKET_TOKEN:-}"
BITBUCKET_WORKSPACE="${BITBUCKET_WORKSPACE:-}"
BITBUCKET_REPO_SLUG="${BITBUCKET_REPO_SLUG:-}"

# Review tool configuration
REVIEW_COMMAND="${REVIEW_COMMAND:-gh copilot explain}"
REVIEW_ARGS="${REVIEW_ARGS:-}"

# Output configuration
OUTPUT_FILE="${OUTPUT_FILE:-/tmp/pr-review-output.md}"
MAX_COMMENT_LENGTH="${MAX_COMMENT_LENGTH:-65000}"

# ============================================================================
# Logging
# ============================================================================

log_info() {
    echo "[INFO] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

# ============================================================================
# Diff Retrieval
# ============================================================================

get_diff_github() {
    log_info "Fetching diff from GitHub PR #${PR_NUMBER}"

    if [[ -z "$GITHUB_TOKEN" ]]; then
        log_error "GITHUB_TOKEN is required for GitHub platform"
        exit 1
    fi

    curl -sL \
        -H "Accept: application/vnd.github.v3.diff" \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}"
}

get_diff_bitbucket() {
    log_info "Fetching diff from Bitbucket PR #${PR_NUMBER}"

    if [[ -z "$BITBUCKET_TOKEN" ]]; then
        log_error "BITBUCKET_TOKEN is required for Bitbucket platform"
        exit 1
    fi

    curl -sL \
        -H "Authorization: Bearer ${BITBUCKET_TOKEN}" \
        "https://api.bitbucket.org/2.0/repositories/${BITBUCKET_WORKSPACE}/${BITBUCKET_REPO_SLUG}/pullrequests/${PR_NUMBER}/diff"
}

get_diff_local() {
    log_info "Generating diff locally"

    # Get diff against main/master branch
    local base_branch="${BASE_BRANCH:-$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo 'main')}"

    git diff "${base_branch}...HEAD"
}

get_diff() {
    case "$PLATFORM" in
        github)
            get_diff_github
            ;;
        bitbucket)
            get_diff_bitbucket
            ;;
        local)
            get_diff_local
            ;;
        *)
            log_error "Unknown platform: $PLATFORM"
            exit 1
            ;;
    esac
}

# ============================================================================
# Code Review
# ============================================================================

generate_review_prompt() {
    cat <<'EOF'
You are a senior software engineer performing a code review. Analyze the following git diff and provide a thorough code review.

Focus on:
1. **Bugs & Issues**: Potential bugs, logic errors, or runtime issues
2. **Security**: Security vulnerabilities or concerns
3. **Performance**: Performance issues or optimization opportunities
4. **Code Quality**: Readability, maintainability, and best practices
5. **Testing**: Missing tests or test coverage concerns

Format your response as markdown with clear sections. Be constructive and specific.
For each issue, reference the file and line if possible.

If the code looks good, acknowledge what was done well.

Here is the diff to review:

```diff
EOF
}

run_review() {
    local diff="$1"
    local prompt
    prompt=$(generate_review_prompt)

    log_info "Running code review with: $REVIEW_COMMAND"

    # Combine prompt and diff
    local full_input="${prompt}
${diff}
\`\`\`"

    # Run the review command
    # gh copilot explain reads from stdin or takes text as argument
    # shellcheck disable=SC2086
    echo "$full_input" | $REVIEW_COMMAND $REVIEW_ARGS 2>/dev/null || \
        $REVIEW_COMMAND "$full_input" $REVIEW_ARGS
}

# ============================================================================
# Comment Posting
# ============================================================================

post_comment_github() {
    local comment="$1"

    log_info "Posting comment to GitHub PR #${PR_NUMBER}"

    # Truncate if too long
    if [[ ${#comment} -gt $MAX_COMMENT_LENGTH ]]; then
        comment="${comment:0:$MAX_COMMENT_LENGTH}

---
*Comment truncated due to length limits*"
    fi

    # Escape for JSON
    local escaped_comment
    escaped_comment=$(echo "$comment" | jq -Rs .)

    curl -sL \
        -X POST \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/${GITHUB_REPOSITORY}/issues/${PR_NUMBER}/comments" \
        -d "{\"body\": ${escaped_comment}}"
}

post_comment_bitbucket() {
    local comment="$1"

    log_info "Posting comment to Bitbucket PR #${PR_NUMBER}"

    # Truncate if too long
    if [[ ${#comment} -gt $MAX_COMMENT_LENGTH ]]; then
        comment="${comment:0:$MAX_COMMENT_LENGTH}

---
*Comment truncated due to length limits*"
    fi

    # Escape for JSON
    local escaped_comment
    escaped_comment=$(echo "$comment" | jq -Rs .)

    curl -sL \
        -X POST \
        -H "Authorization: Bearer ${BITBUCKET_TOKEN}" \
        -H "Content-Type: application/json" \
        "https://api.bitbucket.org/2.0/repositories/${BITBUCKET_WORKSPACE}/${BITBUCKET_REPO_SLUG}/pullrequests/${PR_NUMBER}/comments" \
        -d "{\"content\": {\"raw\": ${escaped_comment}}}"
}

post_comment_local() {
    local comment="$1"

    log_info "Review output (local mode - not posting):"
    echo ""
    echo "$comment"
    echo ""
    log_info "Review saved to: $OUTPUT_FILE"
}

post_comment() {
    local comment="$1"

    # Add header
    local formatted_comment="## 🤖 Automated Code Review

${comment}

---
*Generated by [Copilot CLI Code Reviewer](https://github.com)*"

    # Save to file
    echo "$formatted_comment" > "$OUTPUT_FILE"

    case "$PLATFORM" in
        github)
            post_comment_github "$formatted_comment"
            ;;
        bitbucket)
            post_comment_bitbucket "$formatted_comment"
            ;;
        local)
            post_comment_local "$formatted_comment"
            ;;
    esac
}

# ============================================================================
# Main
# ============================================================================

main() {
    log_info "Starting PR code review"
    log_info "Platform: $PLATFORM"
    log_info "Review command: $REVIEW_COMMAND $REVIEW_ARGS"

    # Validate required vars based on platform
    case "$PLATFORM" in
        github)
            if [[ -z "$GITHUB_TOKEN" || -z "$GITHUB_REPOSITORY" || -z "$PR_NUMBER" ]]; then
                log_error "Missing required variables for GitHub: GITHUB_TOKEN, GITHUB_REPOSITORY, PR_NUMBER"
                exit 1
            fi
            ;;
        bitbucket)
            if [[ -z "$BITBUCKET_TOKEN" || -z "$BITBUCKET_WORKSPACE" || -z "$BITBUCKET_REPO_SLUG" || -z "$PR_NUMBER" ]]; then
                log_error "Missing required variables for Bitbucket: BITBUCKET_TOKEN, BITBUCKET_WORKSPACE, BITBUCKET_REPO_SLUG, PR_NUMBER"
                exit 1
            fi
            ;;
    esac

    # Get the diff
    local diff
    diff=$(get_diff)

    if [[ -z "$diff" ]]; then
        log_info "No changes detected in this PR"
        post_comment "No code changes detected in this pull request."
        exit 0
    fi

    log_debug "Diff size: ${#diff} characters"

    # Run the review
    local review
    review=$(run_review "$diff")

    if [[ -z "$review" ]]; then
        log_error "Review command produced no output"
        exit 1
    fi

    log_debug "Review size: ${#review} characters"

    # Post the comment
    post_comment "$review"

    log_info "Code review completed successfully"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
