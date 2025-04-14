#!/bin/bash
set -e

echo "Installing the latest version of crane..."

# Get the latest release version
VERSION=$(curl -s "https://api.github.com/repos/google/go-containerregistry/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')
echo "Latest version: $VERSION"

# Determine OS and architecture
OS=$(uname -s)
ARCH=$(uname -m)

# Map architecture names
if [ "$ARCH" = "x86_64" ]; then
    ARCH="x86_64"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    ARCH="arm64"
elif [ "$ARCH" = "armv7l" ]; then
    ARCH="armv6"
fi

# Map OS names
if [ "$OS" = "Darwin" ]; then
    OS="Darwin"
elif [ "$OS" = "Linux" ]; then
    OS="Linux"
elif [[ "$OS" == MINGW* ]] || [[ "$OS" == "MSYS"* ]]; then
    OS="Windows"
fi

echo "Detected OS: $OS, Architecture: $ARCH"

# Download crane
DOWNLOAD_URL="https://github.com/google/go-containerregistry/releases/download/${VERSION}/go-containerregistry_${OS}_${ARCH}.tar.gz"
echo "Downloading from: $DOWNLOAD_URL"
curl -sL "$DOWNLOAD_URL" > go-containerregistry.tar.gz

# Download provenance for verification
PROVENANCE_URL="https://github.com/google/go-containerregistry/releases/download/${VERSION}/multiple.intoto.jsonl"
echo "Downloading provenance from: $PROVENANCE_URL"
curl -sL "$PROVENANCE_URL" > provenance.intoto.jsonl

# Check if slsa-verifier is installed
if command -v slsa-verifier >/dev/null 2>&1 || command -v slsa-verifier-linux-amd64 >/dev/null 2>&1; then
    echo "Verifying SLSA provenance..."
    VERIFIER_CMD="slsa-verifier"
    if command -v slsa-verifier-linux-amd64 >/dev/null 2>&1; then
        VERIFIER_CMD="slsa-verifier-linux-amd64"
    fi
    $VERIFIER_CMD verify-artifact go-containerregistry.tar.gz --provenance-path provenance.intoto.jsonl --source-uri github.com/google/go-containerregistry --source-tag "${VERSION}"
    echo "SLSA provenance verification passed"
else
    echo "Warning: slsa-verifier not found. Skipping provenance verification."
    echo "For security, consider installing slsa-verifier from https://github.com/slsa-framework/slsa-verifier"
fi

# Extract crane to a bin directory
echo "Extracting crane..."
tar -zxvf go-containerregistry.tar.gz -C /usr/local/bin crane
echo "Installed crane to /usr/local/bin/"

# Cleanup
rm go-containerregistry.tar.gz provenance.intoto.jsonl

# Verify installation
echo ""
echo "crane installed successfully!"
echo "Version info:"
crane version

echo ""
echo "You can now use crane from anywhere as it's installed in /usr/local/bin/ which should be in your PATH"
