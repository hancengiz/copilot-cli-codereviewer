# Deployment Guide

This guide covers deploying the Copilot CLI PR Code Reviewer to GitHub Actions, Bitbucket Pipelines, and local environments.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Deploy](#quick-deploy)
- [GitHub Actions Deployment](#github-actions-deployment)
- [Bitbucket Pipelines Deployment](#bitbucket-pipelines-deployment)
- [Local Setup](#local-setup)
- [Configuration Reference](#configuration-reference)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

| Tool | Purpose | Installation |
|------|---------|--------------|
| GitHub CLI (`gh`) | Copilot access & GitHub API | [cli.github.com](https://cli.github.com/) |
| `jq` | JSON processing | `brew install jq` / `apt install jq` |
| `curl` | HTTP requests | Usually pre-installed |
| `git` | Version control | Usually pre-installed |

### Required Accounts & Access

- **GitHub Account** with Copilot subscription (Individual, Business, or Enterprise)
- **GitHub Personal Access Token (PAT)** with Copilot scope
- **Repository admin access** (to add secrets/variables)

---

## Quick Deploy

### GitHub (Automated)

```bash
# Clone this repository
git clone https://github.com/your-org/copilot-cli-codereviewer.git
cd copilot-cli-codereviewer

# Run the deployment script
./scripts/deploy-github.sh
```

### Bitbucket (Automated)

```bash
# Clone this repository
git clone https://github.com/your-org/copilot-cli-codereviewer.git
cd copilot-cli-codereviewer

# Run the deployment script
./scripts/deploy-bitbucket.sh
```

### Local (Setup)

```bash
# Run the setup script
./scripts/setup-local.sh
```

---

## GitHub Actions Deployment

### Step 1: Create GitHub Personal Access Token

1. Go to [GitHub Settings → Developer settings → Personal access tokens](https://github.com/settings/tokens)
2. Click **"Generate new token (classic)"**
3. Name: `Copilot Code Review`
4. Select scopes:
   - `copilot` - For Copilot API access
5. Click **"Generate token"**
6. **Copy the token immediately** (you won't see it again)

### Step 2: Add Repository Secret

1. Go to your repository on GitHub
2. Navigate to **Settings → Secrets and variables → Actions**
3. Click **"New repository secret"**
4. Name: `GH_COPILOT_TOKEN`
5. Value: Paste your PAT from Step 1
6. Click **"Add secret"**

### Step 3: Add Workflow Files

#### Option A: Using Deploy Script

```bash
TARGET_REPO="owner/repo" ./scripts/deploy-github.sh
```

#### Option B: Manual Copy

Copy these files to your repository:

```
your-repo/
├── .github/
│   └── workflows/
│       └── pr-review.yml    # Copy from this repo
└── scripts/
    └── review-pr.sh         # Copy from this repo
```

Commit and push:

```bash
git add .github/workflows/pr-review.yml scripts/review-pr.sh
git commit -m "Add automated PR code review"
git push
```

### Step 4: Verify Deployment

1. Create a new branch with some code changes
2. Open a Pull Request
3. Go to **Actions** tab to see the workflow run
4. Check the PR for the review comment

---

## Bitbucket Pipelines Deployment

### Step 1: Create GitHub PAT for Copilot

Same as GitHub Step 1 above - you need a GitHub PAT with Copilot access.

### Step 2: Create Bitbucket App Password

1. Go to [Bitbucket Settings → App passwords](https://bitbucket.org/account/settings/app-passwords/)
2. Click **"Create app password"**
3. Label: `PR Code Review`
4. Permissions:
   - `Pull requests: Write`
5. Click **"Create"**
6. **Copy the password immediately**

### Step 3: Add Repository Variables

1. Go to your Bitbucket repository
2. Navigate to **Repository settings → Pipelines → Repository variables**
3. Add the following variables:

| Name | Value | Secured |
|------|-------|---------|
| `GH_COPILOT_TOKEN` | Your GitHub PAT | Yes |
| `BITBUCKET_TOKEN` | Your Bitbucket app password | Yes |

### Step 4: Enable Pipelines

1. Go to **Repository settings → Pipelines → Settings**
2. Toggle **"Enable Pipelines"** to ON

### Step 5: Add Pipeline Files

#### Option A: Using Deploy Script

```bash
BITBUCKET_WORKSPACE="your-workspace" \
BITBUCKET_REPO="your-repo" \
./scripts/deploy-bitbucket.sh
```

#### Option B: Manual Copy

Copy these files to your repository:

```
your-repo/
├── bitbucket-pipelines.yml  # Copy from this repo
└── scripts/
    └── review-pr.sh         # Copy from this repo
```

Commit and push:

```bash
git add bitbucket-pipelines.yml scripts/review-pr.sh
git commit -m "Add automated PR code review"
git push
```

### Step 6: Verify Deployment

1. Create a new branch with some code changes
2. Open a Pull Request
3. Check **Pipelines** for the build
4. Check the PR for the review comment

---

## Local Setup

### Automated Setup

```bash
./scripts/setup-local.sh
```

This script will:
1. Check for GitHub CLI installation
2. Authenticate with GitHub
3. Install Copilot extension
4. Verify Copilot access
5. Check other dependencies

### Manual Setup

```bash
# Install GitHub CLI
brew install gh          # macOS
# or see https://cli.github.com/ for other platforms

# Authenticate
gh auth login

# Install Copilot extension
gh extension install github/gh-copilot

# Verify
gh copilot --version
```

### Running Locally

```bash
# Navigate to your git repository
cd /path/to/your/repo

# Run against main branch
PLATFORM=local ./path/to/scripts/review-pr.sh

# Run against a specific branch
BASE_BRANCH=develop PLATFORM=local ./path/to/scripts/review-pr.sh

# Debug mode
DEBUG=true PLATFORM=local ./path/to/scripts/review-pr.sh
```

---

## Configuration Reference

### Environment Variables

| Variable | Platform | Required | Description |
|----------|----------|----------|-------------|
| `PLATFORM` | All | Yes | `github`, `bitbucket`, or `local` |
| `GH_TOKEN` | All | Yes | GitHub PAT with Copilot access |
| `REVIEW_COMMAND` | All | No | CLI command (default: `gh copilot explain`) |
| `REVIEW_ARGS` | All | No | Additional CLI arguments |
| `DEBUG` | All | No | Enable verbose logging |
| `MAX_COMMENT_LENGTH` | All | No | Max comment chars (default: 65000) |

#### GitHub-specific

| Variable | Required | Description |
|----------|----------|-------------|
| `GITHUB_TOKEN` | Yes | Token for PR comments (auto-provided in Actions) |
| `GITHUB_REPOSITORY` | Yes | `owner/repo` format (auto-provided) |
| `PR_NUMBER` | Yes | Pull request number (auto-provided) |

#### Bitbucket-specific

| Variable | Required | Description |
|----------|----------|-------------|
| `BITBUCKET_TOKEN` | Yes | App password for PR comments |
| `BITBUCKET_WORKSPACE` | Yes | Workspace name (auto-provided) |
| `BITBUCKET_REPO_SLUG` | Yes | Repository slug (auto-provided) |
| `PR_NUMBER` | Yes | Use `$BITBUCKET_PR_ID` |

#### Local-specific

| Variable | Required | Description |
|----------|----------|-------------|
| `BASE_BRANCH` | No | Branch to diff against (default: auto-detect) |

---

## Troubleshooting

### Common Issues

#### "gh: command not found"

Install GitHub CLI:
```bash
# macOS
brew install gh

# Ubuntu/Debian
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh
```

#### "gh copilot: command not found"

Install the Copilot extension:
```bash
gh extension install github/gh-copilot
```

#### "You need a GitHub Copilot subscription"

Ensure your GitHub account has an active Copilot subscription:
- Copilot Individual
- Copilot Business
- Copilot Enterprise

#### "Bad credentials" or "401 Unauthorized"

1. Regenerate your PAT with correct scopes
2. Update the secret/variable with the new token
3. Ensure the token hasn't expired

#### Empty review or no output

1. Check that the diff isn't empty
2. Enable debug mode: `DEBUG=true`
3. Check Copilot rate limits
4. Verify network connectivity

#### Comment not appearing on PR

**GitHub:**
- Ensure workflow has `pull-requests: write` permission
- Check the `GITHUB_TOKEN` is valid

**Bitbucket:**
- Ensure app password has PR write permission
- Verify `BITBUCKET_TOKEN` is set correctly

### Getting Help

1. Run with `DEBUG=true` for verbose output
2. Check workflow/pipeline logs
3. Verify all secrets and variables are set
4. Test Copilot locally: `echo "test" | gh copilot explain`

---

## Security Considerations

- **Never commit tokens** to the repository
- Use repository secrets/variables for sensitive data
- PATs should have minimal required scopes
- Rotate tokens periodically
- Review workflow permissions carefully
