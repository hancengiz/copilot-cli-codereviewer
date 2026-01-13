# Copilot CLI PR Code Reviewer

Automated code review for pull requests using GitHub Copilot CLI. Works on GitHub Actions, Bitbucket Pipelines, and locally.

## Architecture Overview

```mermaid
flowchart TB
    subgraph Triggers["Trigger Events"]
        PR_GH["GitHub PR Created/Updated"]
        PR_BB["Bitbucket PR Created/Updated"]
        LOCAL["Local Git Changes"]
    end

    subgraph Platforms["CI/CD Platforms"]
        GHA["GitHub Actions"]
        BBP["Bitbucket Pipelines"]
        CLI["Local Terminal"]
    end

    subgraph Core["Core Components"]
        SCRIPT["review-pr.sh<br/>(Portable Script)"]
        DIFF["Diff Extraction"]
        PROMPT["Review Prompt<br/>Generation"]
    end

    subgraph AI["AI Processing"]
        COPILOT["GitHub Copilot CLI<br/>(gh copilot explain)"]
    end

    subgraph Output["Output"]
        COMMENT_GH["GitHub PR Comment"]
        COMMENT_BB["Bitbucket PR Comment"]
        TERMINAL["Terminal Output"]
    end

    PR_GH --> GHA
    PR_BB --> BBP
    LOCAL --> CLI

    GHA --> SCRIPT
    BBP --> SCRIPT
    CLI --> SCRIPT

    SCRIPT --> DIFF
    DIFF --> PROMPT
    PROMPT --> COPILOT
    COPILOT --> SCRIPT

    SCRIPT -->|"PLATFORM=github"| COMMENT_GH
    SCRIPT -->|"PLATFORM=bitbucket"| COMMENT_BB
    SCRIPT -->|"PLATFORM=local"| TERMINAL
```

## How It Works

```mermaid
sequenceDiagram
    autonumber
    participant Dev as Developer
    participant Git as Git Platform
    participant CI as CI/CD Runner
    participant Script as review-pr.sh
    participant GH as GitHub CLI
    participant Copilot as Copilot AI
    participant API as Platform API

    Dev->>Git: Create/Update PR
    Git->>CI: Trigger Workflow
    CI->>CI: Install GitHub CLI + Copilot Extension
    CI->>Script: Execute review-pr.sh

    Script->>API: Fetch PR Diff
    API-->>Script: Return Diff Content

    Script->>Script: Generate Review Prompt
    Script->>GH: Pipe prompt + diff to<br/>gh copilot explain
    GH->>Copilot: Send to Copilot API
    Copilot-->>GH: Return AI Review
    GH-->>Script: Return Review Output

    Script->>Script: Format as Markdown
    Script->>API: POST Comment to PR
    API-->>Script: Comment Created

    Script-->>CI: Exit Success
    CI-->>Git: Workflow Complete
    Git-->>Dev: PR Updated with Review
```

## Review Process Detail

```mermaid
flowchart LR
    subgraph Input
        A[PR Diff] --> B[Code Changes]
    end

    subgraph Processing
        B --> C{Generate Prompt}
        C --> D[Bug Detection]
        C --> E[Security Analysis]
        C --> F[Performance Review]
        C --> G[Code Quality]
        C --> H[Test Coverage]
    end

    subgraph AI
        D --> I[Copilot AI]
        E --> I
        F --> I
        G --> I
        H --> I
    end

    subgraph Output
        I --> J[Markdown Report]
        J --> K[PR Comment]
    end
```

## File Structure

```
copilot-cli-codereviewer/
├── .github/
│   └── workflows/
│       └── pr-review.yml        # GitHub Actions workflow
├── scripts/
│   ├── review-pr.sh             # Core review script (portable)
│   ├── deploy-github.sh         # GitHub deployment automation
│   ├── deploy-bitbucket.sh      # Bitbucket deployment automation
│   └── setup-local.sh           # Local environment setup
├── bitbucket-pipelines.yml      # Bitbucket Pipelines config
├── DEPLOYMENT.md                # Detailed deployment guide
└── README.md                    # This file
```

## Quick Start

### GitHub Actions

```bash
# Automated deployment
./scripts/deploy-github.sh
```

Or manually:
1. Add `GH_COPILOT_TOKEN` secret (GitHub PAT with Copilot access)
2. Copy `.github/workflows/pr-review.yml` and `scripts/review-pr.sh`
3. Create a PR to test

### Bitbucket Pipelines

```bash
# Automated deployment
./scripts/deploy-bitbucket.sh
```

Or manually:
1. Add `GH_COPILOT_TOKEN` and `BITBUCKET_TOKEN` as repository variables
2. Copy `bitbucket-pipelines.yml` and `scripts/review-pr.sh`
3. Enable Pipelines and create a PR

### Local Usage

```bash
# Setup local environment
./scripts/setup-local.sh

# Run review on current branch
cd /path/to/your/repo
PLATFORM=local /path/to/scripts/review-pr.sh
```

## Platform Comparison

```mermaid
flowchart TB
    subgraph GitHub["GitHub Actions"]
        GH_TRIGGER["on: pull_request"]
        GH_SECRET["secrets.GH_COPILOT_TOKEN"]
        GH_PERM["permissions:<br/>pull-requests: write"]
        GH_API["GitHub REST API"]
    end

    subgraph Bitbucket["Bitbucket Pipelines"]
        BB_TRIGGER["pipelines:<br/>  pull-requests:"]
        BB_VAR["$GH_COPILOT_TOKEN<br/>$BITBUCKET_TOKEN"]
        BB_API["Bitbucket REST API"]
    end

    subgraph Local["Local Execution"]
        LOCAL_TRIGGER["Manual execution"]
        LOCAL_AUTH["gh auth login"]
        LOCAL_OUTPUT["Terminal output"]
    end

    SCRIPT["review-pr.sh"]

    GH_TRIGGER --> SCRIPT
    GH_SECRET --> SCRIPT
    GH_PERM --> GH_API
    SCRIPT --> GH_API

    BB_TRIGGER --> SCRIPT
    BB_VAR --> SCRIPT
    SCRIPT --> BB_API

    LOCAL_TRIGGER --> SCRIPT
    LOCAL_AUTH --> SCRIPT
    SCRIPT --> LOCAL_OUTPUT
```

## Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `PLATFORM` | Target platform | `local` |
| `REVIEW_COMMAND` | AI CLI command | `gh copilot explain` |
| `REVIEW_ARGS` | Additional CLI args | (empty) |
| `DEBUG` | Enable verbose logging | `false` |
| `MAX_COMMENT_LENGTH` | Truncate long comments | `65000` |

See [DEPLOYMENT.md](DEPLOYMENT.md) for complete configuration reference.

## Example Review Output

```markdown
## 🤖 Automated Code Review

### Summary
This PR adds a new user authentication feature with JWT token support.

### Issues Found

#### 🐛 Potential Bug
**File:** `src/auth/token.js:45`
The token expiration check uses `<` instead of `<=`, which could cause
tokens to be valid for 1 second longer than intended.

#### 🔒 Security Concern
**File:** `src/auth/password.js:23`
Password is logged in debug mode. Consider removing or masking sensitive data.

### Suggestions

- Consider adding rate limiting to the login endpoint
- Add unit tests for edge cases in token validation
- Document the new environment variables in README

### What Looks Good
- Clean separation of concerns
- Proper error handling
- Consistent code style

---
*Generated by Copilot CLI Code Reviewer*
```

## Requirements

- GitHub account with Copilot access
- GitHub CLI (`gh`) v2.0+
- `jq` for JSON processing
- `curl` for API calls

## Documentation

- [DEPLOYMENT.md](DEPLOYMENT.md) - Step-by-step deployment instructions
- [scripts/](scripts/) - Automation scripts with inline documentation

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `gh copilot: command not found` | Run `gh extension install github/gh-copilot` |
| Empty review output | Check `DEBUG=true` for details |
| Comment not posting | Verify token permissions |
| Rate limiting | Wait and retry, or check quotas |

## License

MIT
