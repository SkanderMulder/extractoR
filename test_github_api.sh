#!/bin/bash

# Test if we can access GitHub API
echo "Testing GitHub API access..."

# Try to get repo info
curl -s -w "\nHTTP Status: %{http_code}\n" \
  https://api.github.com/repos/SkanderMulder/extractoR \
  | head -20

echo ""
echo "---"
echo "Trying with potential token from git..."

# Try to extract token from git credential helper
GIT_TOKEN=$(git credential fill <<EOF | grep password | cut -d= -f2
protocol=https
host=github.com
EOF
)

if [ -n "$GIT_TOKEN" ]; then
    echo "Found potential token, testing..."
    curl -s -w "\nHTTP Status: %{http_code}\n" \
      -H "Authorization: token $GIT_TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      https://api.github.com/repos/SkanderMulder/extractoR \
      | head -20
else
    echo "No token found in git credentials"
fi
