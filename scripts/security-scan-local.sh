#!/bin/bash

# Local Security Scan Script for PrediGroweeV2-UI
# Run this before pushing to catch issues early

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}Frontend Security Scan (Local)${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

# Check if required tools are installed
echo -e "${YELLOW}Checking available tools...${NC}"

TOOLS_AVAILABLE=1
check_tool() {
    if command -v $1 &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $1"
    else
        echo -e "  ${RED}✗${NC} $1 (not installed)"
        TOOLS_AVAILABLE=0
    fi
}

check_tool hadolint
check_tool docker
check_tool trivy
check_tool syft
check_tool grype
check_tool npm
check_tool prettier
check_tool gitleaks

echo ""

# 1. Hadolint - Dockerfile linting
echo -e "${BLUE}[1/8] Running Hadolint (Dockerfile linting)...${NC}"
if command -v hadolint &> /dev/null; then
    for dockerfile in Dockerfile.dev Dockerfile.prod; do
        if [ -f "$dockerfile" ]; then
            echo "  Checking $dockerfile..."
            hadolint --failure-threshold style "$dockerfile" || echo -e "    ${RED}⚠️  Issues found${NC}"
        fi
    done
else
    echo -e "${YELLOW}⚠️  hadolint not installed, skipping...${NC}"
fi
echo ""

# 2. TypeScript Type Check
echo -e "${BLUE}[2/8] Running TypeScript Type Check...${NC}"
if [ -f "package.json" ]; then
    npm run type-check || echo -e "${RED}⚠️  Type errors found${NC}"
else
    echo -e "${YELLOW}⚠️  package.json not found, skipping...${NC}"
fi
echo ""

# 3. ESLint
echo -e "${BLUE}[3/8] Running ESLint...${NC}"
if [ -f "package.json" ]; then
    npm run lint || echo -e "${RED}⚠️  Lint errors found${NC}"
else
    echo -e "${YELLOW}⚠️  package.json not found, skipping...${NC}"
fi
echo ""

# 4. Prettier
echo -e "${BLUE}[4/8] Running Prettier...${NC}"
if command -v prettier &> /dev/null || [ -f "node_modules/.bin/prettier" ]; then
    PRETTIER_CMD="prettier"
    [ -f "node_modules/.bin/prettier" ] && PRETTIER_CMD="npx prettier"
    $PRETTIER_CMD --check "**/*.{ts,tsx,js,jsx,json,css,scss}" || echo -e "${RED}⚠️  Formatting issues found${NC}"
else
    echo -e "${YELLOW}⚠️  prettier not installed, skipping...${NC}"
fi
echo ""

# 5. NPM Audit
echo -e "${BLUE}[5/8] Running npm audit...${NC}"
if [ -f "package.json" ]; then
    npm audit --audit-level=high || echo -e "${RED}⚠️  Vulnerabilities found${NC}"
else
    echo -e "${YELLOW}⚠️  package.json not found, skipping...${NC}"
fi
echo ""

# 6. Build Docker images and scan with Trivy
echo -e "${BLUE}[6/8] Building Docker images and scanning with Trivy...${NC}"
if command -v docker &> /dev/null && command -v trivy &> /dev/null; then
    for dockerfile in dev prod; do
        echo "  Building frontend:$dockerfile..."
        docker build -f Dockerfile.$dockerfile -t frontend:$dockerfile . || {
            echo -e "${RED}⚠️  Build failed for $dockerfile${NC}"
            continue
        }
        
        echo "  Scanning frontend:$dockerfile with Trivy..."
        trivy image \
            --severity CRITICAL,HIGH,MEDIUM,LOW \
            --scanners vuln,secret \
            --ignore-unfixed \
            --timeout 15m \
            frontend:$dockerfile || echo -e "${RED}⚠️  Vulnerabilities found${NC}"
    done
else
    echo -e "${YELLOW}⚠️  docker or trivy not installed, skipping...${NC}"
fi
echo ""

# 7. SBOM Generation and Grype Scan
echo -e "${BLUE}[7/8] Generating SBOM and scanning with Grype...${NC}"
if command -v syft &> /dev/null && command -v grype &> /dev/null; then
    if docker images -q frontend:prod &> /dev/null; then
        echo "  Generating SBOM..."
        mkdir -p ./security-reports/sbom
        syft frontend:prod -o spdx-json > ./security-reports/sbom/frontend-sbom.json
        
        echo "  Scanning SBOM with Grype..."
        grype sbom:./security-reports/sbom/frontend-sbom.json --fail-on medium || echo -e "${RED}⚠️  Vulnerabilities found${NC}"
    else
        echo -e "${YELLOW}⚠️  frontend:prod image not found, build it first${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  syft or grype not installed, skipping...${NC}"
fi
echo ""

# 8. Secret Scanning with Gitleaks
echo -e "${BLUE}[8/8] Running Gitleaks (secret scanning)...${NC}"
if command -v gitleaks &> /dev/null; then
    gitleaks detect --no-git --verbose || echo -e "${RED}⚠️  Secrets found${NC}"
else
    echo -e "${YELLOW}⚠️  gitleaks not installed, skipping...${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}=====================================${NC}"
echo -e "${GREEN}✅ Local security scan completed!${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""
echo -e "Reports saved in: ${YELLOW}./security-reports/${NC}"
echo ""
echo -e "${YELLOW}Note: This is a local scan. Full CI/CD scan will run on push.${NC}"
echo -e "${YELLOW}Install missing tools with: scripts/install-security-tools.sh${NC}"
echo ""

exit 0
