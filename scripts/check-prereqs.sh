#!/usr/bin/env bash

# This script verifies that the required CLI tools are installed on the Jenkins build agent.
# It returns 0 if all tools are available, or 1 if any tool is missing.

set -eo pipefail

REQUIRED_TOOLS=("aws" "terraform" "kubectl" "helm")
OPTIONAL_TOOLS=("tfsec" "tflint" "checkov")

echo "===================================================="
echo " Checking platform prerequisites on Jenkins Agent..."
echo "===================================================="

MISSING_REQUIRED=0

# Check required tools
for tool in "${REQUIRED_TOOLS[@]}"; do
    if command -v "$tool" &> /dev/null; then
        version=$("$tool" --version 2>&1 | head -n 1 || true)
        echo "✅ [REQUIRED] $tool is installed: $version"
    else
        echo "❌ [REQUIRED] $tool is NOT installed!"
        MISSING_REQUIRED=$((MISSING_REQUIRED + 1))
    fi
done

echo ""
echo "----------------------------------------------------"
echo " Checking optional security/linting tools..."
echo "----------------------------------------------------"

# Check optional tools
for tool in "${OPTIONAL_TOOLS[@]}"; do
    if command -v "$tool" &> /dev/null; then
        version=$("$tool" --version 2>&1 | head -n 1 || true)
        echo "ℹ️ [OPTIONAL] $tool is installed: $version"
    else
        echo "⚠️ [OPTIONAL] $tool is not installed. Scans for this tool will be skipped."
    fi
done

echo "===================================================="

if [ "$MISSING_REQUIRED" -gt 0 ]; then
    echo "❌ Validation failed! $MISSING_REQUIRED required tool(s) missing."
    exit 1
else
    echo "✅ Validation succeeded! All required tools are available."
    exit 0
fi
