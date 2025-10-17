# PrediGroweeV2-UI - Frontend

Frontend for Predigrowee 2.0 application - engineering thesis project.
Application available at `predigrowee.agh.edu.pl`.

## Quick Start

### Local Development

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Frontend available at: http://localhost:3000
```

### Security Tools Installation

After cloning the repository, install security tools and git hooks:

```bash
# Install all security tools (Trivy, Syft, Grype, Hadolint, Dockle)
./scripts/install-security-tools.sh

# Load new environment variables
source ~/.bashrc
```

**What will be installed:**

- Trivy - CVE scanning in Docker images
- Syft - SBOM generation
- Grype - Vulnerability scanning
- Hadolint - Dockerfile linting
- Dockle - Dockerfile security linting
- Pre-commit hook - Automatic checks before commit

**Pre-commit hook will automatically check:**

- Hardcoded secrets
- File sizes (1MB limit)
- Trailing whitespace
- Merge conflict markers
- Dockerfile best practices
- ESLint errors
- TypeScript type errors
- Prettier formatting
- npm audit vulnerabilities

## Tech Stack

- Next.js 14.2.7
- React 18
- TypeScript
- Material-UI
- Docker (multi-stage builds)

## Documentation

- Backend API: [PrediGroweeV2](../PrediGroweeV2)
- Security Pipeline: See `.github/workflows/security-scan.yml`
