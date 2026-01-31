#!/bin/bash
# Exit immediately if a command exits with a non-zero status
set -e

# 1. Ensure Flutter is in the PATH (especially for Snap installs)
export PATH="$PATH:/snap/bin"

echo "🔵 [1/5] Updating System..."
sudo apt-get update

echo "🔵 [2/5] Installing Linux Build Prerequisites..."
# Added 'git' and 'curl' just in case, plus the required build tools
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libsecret-1-dev libjsoncpp-dev git curl

# 2. Verify Flutter installation
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter still not found. Attempting to initialize snap..."
    # This helps if the snap was just installed but not yet linked
    sudo ln -sf /usr/bin/snap /usr/bin/snap || true
fi

echo "🔵 [3/5] Configuring Flutter for Linux Desktop..."
# Force flutter to initialize if it's the first time
flutter doctor --android-licenses || true 
flutter config --enable-linux-desktop

echo "🔵 [4/5] Generating/Cleaning Project Configuration..."
# Clean old builds to prevent cache issues
flutter clean
flutter pub get

echo "🔵 [5/5] Building Project for Linux..."
# We run 'flutter create .' to ensure the /linux folder exists for this machine
flutter create --platforms=linux .
flutter build linux --release

echo "------------------------------------------"
echo "✅ Build Complete!"
echo "You can find your executable here:"
echo "$(pwd)/build/linux/x64/release/bundle/octra_wallet"
echo "------------------------------------------"
