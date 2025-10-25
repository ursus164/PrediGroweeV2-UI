#!/bin/bash

# Quick test for vulnerability fixes
set -e

echo "=== Quick Vulnerability Test ==="
echo ""

echo "1. Testing Prettier auto-fix..."
npx prettier --write "security-reports/sbom/*.json" 2>&1 | head -5
echo "✓ Prettier works"
echo ""

echo "2. Checking Node version in Docker image..."
docker run --rm frontend:prod node --version
echo ""

echo "3. Generating SBOM..."
mkdir -p ./security-reports/sbom
syft frontend:prod -o spdx-json > ./security-reports/sbom/frontend-sbom.json 2>&1
echo "✓ SBOM generated"
echo ""

echo "4. Running Grype scan (HIGH severity only)..."
grype sbom:./security-reports/sbom/frontend-sbom.json --fail-on high
echo ""

echo "=== All tests passed! ==="
