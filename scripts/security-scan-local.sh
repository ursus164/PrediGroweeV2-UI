#!/bin/bash

# Local Security Scan Script for PrediGroweeV2-UI
# ZAWSZE SKANUJE CAŁE REPO - nie tylko zmienione pliki
# Run this before pushing to catch issues early

# Nie przerywamy na błędach - chcemy zobaczyć wszystkie wyniki
# set -e

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

# Licznik błędów
TOTAL_ERRORS=0

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

# File Hygiene Checks
echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}File Hygiene Checks${NC}"
echo -e "${BLUE}=====================================${NC}"

# Check file sizes
echo -e "${BLUE}[1/3] Checking file sizes...${NC}"
MAX_SIZE=1048576 # 1MB
FILES_TOO_LARGE=0
while IFS= read -r -d '' file; do
    if [ -f "$file" ]; then
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        if [ "$size" -gt "$MAX_SIZE" ]; then
            echo -e "${RED}  File too large: $file ($(($size / 1024))KB > 1MB)${NC}"
            FILES_TOO_LARGE=1
        fi
    fi
done < <(find . -type f -not -path "./.git/*" -not -path "./node_modules/*" -not -path "./.next/*" -not -path "./dist/*" -not -path "./build/*" -not -path "./security-reports/*" -print0)

if [ $FILES_TOO_LARGE -eq 1 ]; then
    echo -e "${RED}❌ Large files detected - consider using Git LFS${NC}"
    TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
else
    echo -e "${GREEN}✓ All files within size limit${NC}"
fi
echo ""

# Check trailing whitespace
echo -e "${BLUE}[2/3] Checking trailing whitespace...${NC}"
TRAILING_WS_FOUND=0
while IFS= read -r -d '' file; do
    if [ -f "$file" ]; then
        if grep -q '[[:space:]]$' "$file" 2>/dev/null; then
            echo -e "${RED}  Trailing whitespace: $file${NC}"
            TRAILING_WS_FOUND=1
        fi
    fi
done < <(find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.json" -o -name "*.css" -o -name "*.scss" -o -name "*.md" -o -name "*.yml" -o -name "*.yaml" \) -not -path "./.git/*" -not -path "./node_modules/*" -not -path "./.next/*" -not -path "./security-reports/*" -print0)

if [ $TRAILING_WS_FOUND -eq 1 ]; then
    echo -e "${RED}❌ Trailing whitespace found${NC}"
    TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
else
    echo -e "${GREEN}✓ No trailing whitespace${NC}"
fi
echo ""

# Check merge conflict markers
echo -e "${BLUE}[3/3] Checking merge conflict markers...${NC}"
MERGE_CONFLICTS_FOUND=0
while IFS= read -r -d '' file; do
    if [ -f "$file" ]; then
        if grep -n "^<<<<<<< \|^=======$\|^>>>>>>> " "$file" 2>/dev/null; then
            echo -e "${RED}  Merge conflict markers: $file${NC}"
            MERGE_CONFLICTS_FOUND=1
        fi
    fi
done < <(find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.json" -o -name "*.css" -o -name "*.scss" -o -name "*.md" -o -name "*.yml" -o -name "*.yaml" \) -not -path "./.git/*" -not -path "./node_modules/*" -not -path "./.next/*" -not -path "./security-reports/*" -print0)

if [ $MERGE_CONFLICTS_FOUND -eq 1 ]; then
    echo -e "${RED}❌ Merge conflict markers found${NC}"
    TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
else
    echo -e "${GREEN}✓ No merge conflict markers${NC}"
fi
echo ""

# 1. Hadolint - Dockerfile linting
echo -e "${BLUE}[1/8] Running Hadolint (Dockerfile linting)...${NC}"
if command -v hadolint &> /dev/null; then
    for dockerfile in Dockerfile.dev Dockerfile.prod; do
        if [ -f "$dockerfile" ]; then
            echo "  Checking $dockerfile..."
            if ! hadolint --failure-threshold style "$dockerfile"; then
                echo -e "    ${RED}⚠️  Hadolint found issues${NC}"
                TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
            fi
        fi
    done
else
    echo -e "${YELLOW}⚠️  hadolint not installed, skipping...${NC}"
fi
echo ""

# 2. TypeScript Type Check
echo -e "${BLUE}[2/8] Running TypeScript Type Check...${NC}"
if [ -f "package.json" ]; then
    if ! npm run type-check; then
        echo -e "${RED}⚠️  Type errors found${NC}"
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
else
    echo -e "${YELLOW}⚠️  package.json not found, skipping...${NC}"
fi
echo ""

# 3. ESLint
echo -e "${BLUE}[3/8] Running ESLint...${NC}"
if [ -f "package.json" ]; then
    if ! npm run lint; then
        echo -e "${RED}⚠️  Lint errors found${NC}"
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
else
    echo -e "${YELLOW}⚠️  package.json not found, skipping...${NC}"
fi
echo ""

# 4. Prettier
echo -e "${BLUE}[4/8] Running Prettier...${NC}"
if command -v prettier &> /dev/null || [ -f "node_modules/.bin/prettier" ]; then
    PRETTIER_CMD="prettier"
    [ -f "node_modules/.bin/prettier" ] && PRETTIER_CMD="npx prettier"
    if ! $PRETTIER_CMD --check "**/*.{ts,tsx,js,jsx,json,css,scss}"; then
        echo -e "${RED}⚠️  Formatting issues found${NC}"
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
else
    echo -e "${YELLOW}⚠️  prettier not installed, skipping...${NC}"
fi
echo ""

# 5. NPM Audit
echo -e "${BLUE}[5/8] Running npm audit...${NC}"
if [ -f "package.json" ]; then
    if ! npm audit --audit-level=high; then
        echo -e "${RED}⚠️  Vulnerabilities found${NC}"
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
else
    echo -e "${YELLOW}⚠️  package.json not found, skipping...${NC}"
fi
echo ""

# 6. Build Docker images and scan with Trivy
echo -e "${BLUE}[6/8] Building Docker images and scanning with Trivy...${NC}"
if command -v docker &> /dev/null && command -v trivy &> /dev/null; then
    for dockerfile in dev prod; do
        echo "  Building frontend:$dockerfile..."
        if ! docker build -f Dockerfile.$dockerfile -t frontend:$dockerfile .; then
            echo -e "${RED}⚠️  Build failed for $dockerfile${NC}"
            TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
            continue
        fi

        echo "  Scanning frontend:$dockerfile with Trivy..."
        if ! trivy image \
            --severity CRITICAL,HIGH,MEDIUM,LOW \
            --scanners vuln,secret \
            --ignore-unfixed \
            --timeout 15m \
            frontend:$dockerfile; then
            echo -e "${RED}⚠️  Trivy found vulnerabilities in $dockerfile${NC}"
            TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
        fi
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
        if ! grype sbom:./security-reports/sbom/frontend-sbom.json --fail-on medium; then
            echo -e "${RED}⚠️  Grype found vulnerabilities${NC}"
            TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
        fi
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
    if ! gitleaks detect --no-git --verbose; then
        echo -e "${RED}⚠️  Gitleaks found secrets${NC}"
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
else
    echo -e "${YELLOW}⚠️  gitleaks not installed, skipping...${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}=====================================${NC}"
if [ $TOTAL_ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All security checks passed!${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo ""
    echo -e "Reports saved in: ${YELLOW}./security-reports/${NC}"
    echo ""
    echo -e "${YELLOW}Note: This is a local scan. Full CI/CD scan will run on push.${NC}"
    echo -e "${YELLOW}Install missing tools with: scripts/install-security-tools.sh${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Security scan completed with $TOTAL_ERRORS errors/warnings${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo ""
    echo -e "Reports saved in: ${YELLOW}./security-reports/${NC}"
    echo ""
    echo -e "${RED}Fix issues before pushing to repository!${NC}"
    echo -e "${YELLOW}Install missing tools with: scripts/install-security-tools.sh${NC}"
    echo ""
    exit 1
fi
