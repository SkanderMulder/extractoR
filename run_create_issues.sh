#!/bin/bash

# Script to create GitHub issues
# Requires GITHUB_TOKEN environment variable

if [ -z "$GITHUB_TOKEN" ]; then
    echo "ERROR: GITHUB_TOKEN environment variable is not set"
    echo ""
    echo "Please set your GitHub token with:"
    echo "  export GITHUB_TOKEN='your_github_token_here'"
    echo ""
    echo "You can create a token at: https://github.com/settings/tokens"
    echo "Required scopes: 'repo' (full control of private repositories)"
    exit 1
fi

echo "Running issue creation script..."
python3 create_issues.py
