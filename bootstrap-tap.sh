#!/bin/bash
set -e

# Bootstrap script for Kamiwaza Homebrew tap repository
# This initializes the tap repository with the necessary structure

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if we're in the tap repository
if [ ! -d ".git" ]; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    echo "Please run this from the root of your homebrew-kamiwaza repository"
    exit 1
fi

echo -e "${YELLOW}Bootstrapping Kamiwaza Homebrew tap repository...${NC}"

# Create Formula directory
echo -e "${YELLOW}Creating Formula directory...${NC}"
mkdir -p Formula

# Copy README if not exists
if [ ! -f "README.md" ]; then
    echo -e "${YELLOW}Adding README.md...${NC}"
    cp "$(dirname "$0")/README.md" .
fi

# Copy .gitignore if not exists
if [ ! -f ".gitignore" ]; then
    echo -e "${YELLOW}Adding .gitignore...${NC}"
    cp "$(dirname "$0")/.gitignore" .
fi

# Check if formula exists
if [ ! -f "Formula/kamiwaza.rb" ]; then
    echo -e "${YELLOW}Formula/kamiwaza.rb not found${NC}"
    echo "You'll need to copy it from your main repository after building:"
    echo "  cp /path/to/kamiwaza/install-scripting/brew/dist/kamiwaza.rb Formula/"
fi

# Add all files
echo -e "${YELLOW}Adding files to git...${NC}"
git add .

# Create initial commit
echo -e "${YELLOW}Creating initial commit...${NC}"
git commit -m "Initial tap repository setup" || echo "Nothing to commit"

# Show status
echo -e "${GREEN}✓ Bootstrap complete!${NC}"
echo ""
echo "Repository structure:"
tree -a -I '.git' || ls -la

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Push to GitHub:"
echo "   git push origin main"
echo ""
echo "2. Copy your formula after building:"
echo "   cp /path/to/kamiwaza/install-scripting/brew/dist/kamiwaza.rb Formula/"
echo ""
echo "3. Create your first release:"
echo "   cd /path/to/kamiwaza"
echo "   make brew-create-release"