#!/bin/bash
# OpenAssistant Developer Setup Script
# Last updated: 2026-05-29

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0;35m' # No Color
CLEAR='\033[0m'

echo -e "${BLUE}=== OpenAssistant iOS App Developer Setup ===${CLEAR}"

# 1. Check prerequisites
echo -e "\n${BLUE}[1/4] Checking prerequisites...${CLEAR}"
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ Xcode command line tools are not installed. Please install Xcode.${CLEAR}"
    exit 1
else
    echo -e "${GREEN}✓ Xcode CommandLineTools detected: $(xcodebuild -version | head -1)${CLEAR}"
fi

if ! command -v pod &> /dev/null; then
    echo -e "${YELLOW}⚠ CocoaPods is not installed. Attempting to install CocoaPods...${CLEAR}"
    sudo gem install cocoapods || {
        echo -e "${RED}❌ Failed to install CocoaPods automatically. Please run: brew install cocoapods${CLEAR}"
        exit 1
    }
else
    echo -e "${GREEN}✓ CocoaPods detected: $(pod --version)${CLEAR}"
fi

# 2. Install CocoaPods dependencies
echo -e "\n${BLUE}[2/4] Installing CocoaPods dependencies...${CLEAR}"
if [ -f "Podfile" ]; then
    pod install --repo-update
    echo -e "${GREEN}✓ CocoaPods dependencies installed successfully.${CLEAR}"
else
    echo -e "${RED}❌ Podfile not found. Make sure you are running setup.sh from the project root.${CLEAR}"
    exit 1
fi

# 3. Setup local secrets safeguard (Git Pre-Commit Hook)
echo -e "\n${BLUE}[3/4] Installing git security hooks...${CLEAR}"
HOOK_FILE=".git/hooks/pre-commit"
if [ -d ".git" ]; then
    mkdir -p .git/hooks
    cat > "$HOOK_FILE" << 'EOF'
#!/bin/bash
# Pre-commit hook to prevent committing raw OpenAI API Keys

KEY_PATTERN="sk-[a-zA-Z0-9]{32,}"
PROJ_FILES=$(git diff --cached --name-only)

for FILE in $PROJ_FILES; do
    if [ -f "$FILE" ]; then
        # Exclude checking this hook itself or config documentation
        if [[ "$FILE" == *"SECURITY.md"* || "$FILE" == *"pre-commit"* ]]; then
            continue
        fi
        
        # Search for potential OpenAI keys
        if grep -qE "$KEY_PATTERN" "$FILE"; then
            echo -e "\033[0;31m❌ ERROR: Potential hardcoded OpenAI API Key detected in: $FILE\033[0m"
            echo -e "\033[0;31mPlease remove the credential before committing.\033[0m"
            exit 1
        fi
    fi
done
exit 0
EOF
    chmod +x "$HOOK_FILE"
    echo -e "${GREEN}✓ Pre-commit hook installed to prevent raw API key exposure.${CLEAR}"
else
    echo -e "${YELLOW}⚠ Git repository not initialized. Skipping git hook installation.${CLEAR}"
fi

# 4. Final guidance
echo -e "\n${GREEN}=== Setup Completed Successfully! ===${CLEAR}"
echo -e "To open the project in Xcode, run:"
echo -e "  ${BLUE}open OpenAssistant.xcworkspace${CLEAR}\n"
echo -e "Make sure to configure your signing identity and team in Xcode."
echo -e "When the app launches, enter your OpenAI API key in the Settings tab."
EOF
