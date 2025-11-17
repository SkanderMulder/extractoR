#!/usr/bin/env python3
"""
Script to create GitHub issues for extractoR roadmap using requests.
Tries to auto-detect authentication.
"""

import os
import sys
import json
import time
import subprocess

# Try to get token from git credentials or environment
def get_github_token():
    # Try environment variable first
    token = os.environ.get('GITHUB_TOKEN')
    if token:
        return token

    # Try to get from gh CLI if available
    try:
        result = subprocess.run(
            ['gh', 'auth', 'token'],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    return None

# Import requests
try:
    import requests
except ImportError:
    print("Installing requests library...")
    subprocess.run([sys.executable, '-m', 'pip', 'install', 'requests', '-q'])
    import requests

REPO_OWNER = 'SkanderMulder'
REPO_NAME = 'extractoR'
API_URL = f'https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/issues'

# Get token
token = get_github_token()

if not token:
    print("=" * 70)
    print("GITHUB TOKEN REQUIRED")
    print("=" * 70)
    print()
    print("I need a GitHub personal access token to create issues.")
    print()
    print("Please:")
    print("1. Go to: https://github.com/settings/tokens/new")
    print("2. Create a token with 'repo' scope")
    print("3. Run: export GITHUB_TOKEN='your_token_here'")
    print("4. Run this script again")
    print()
    sys.exit(1)

headers = {
    'Authorization': f'token {token}',
    'Accept': 'application/vnd.github.v3+json',
}

# Test authentication
print("Testing GitHub authentication...")
test_response = requests.get(f'https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}', headers=headers)
if test_response.status_code != 200:
    print(f"✗ Authentication failed: {test_response.status_code}")
    print(f"Response: {test_response.text}")
    sys.exit(1)
print("✓ Authentication successful!")
print()

# Load issues from the Python script
exec(open('create_issues.py').read())

# Now create the issues
main()
