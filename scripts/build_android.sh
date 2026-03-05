#!/bin/bash
# Build script for Android AAR (Go backend)
# This script compiles the Go backend to an AAR library for Android
# Must be run on Linux or macOS with Go, Android SDK, and NDK installed

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
GO_BACKEND_DIR="$PROJECT_DIR/go_backend"
ANDROID_LIBS_DIR="$PROJECT_DIR/android/app/libs"

echo "=== SpotiFLAC Android Build Script ==="
echo "Project directory: $PROJECT_DIR"
echo "Go backend directory: $GO_BACKEND_DIR"
echo "Output directory: $ANDROID_LIBS_DIR"

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo "Error: Go is not installed. Please install Go 1.24+ first."
    echo "  https://go.dev/dl/"
    exit 1
fi

echo "Go version: $(go version)"

# Check if Android SDK / NDK are set up
if [ -z "$ANDROID_HOME" ] && [ -z "$ANDROID_SDK_ROOT" ]; then
    echo "Error: ANDROID_HOME or ANDROID_SDK_ROOT environment variable is not set."
    echo "  Please install Android Studio or the Android command-line tools."
    echo "  https://developer.android.com/studio"
    exit 1
fi

ANDROID_SDK="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
echo "Android SDK: $ANDROID_SDK"

# Find NDK
NDK_PATH=""
if [ -d "$ANDROID_SDK/ndk" ]; then
    # Pick the highest available NDK version
    NDK_PATH=$(ls -d "$ANDROID_SDK/ndk/"*/ 2>/dev/null | sort -V | tail -n 1)
fi
if [ -n "$ANDROID_NDK_HOME" ]; then
    NDK_PATH="$ANDROID_NDK_HOME"
fi
if [ -n "$NDK_HOME" ]; then
    NDK_PATH="$NDK_HOME"
fi

if [ -z "$NDK_PATH" ] || [ ! -d "$NDK_PATH" ]; then
    echo "Error: Android NDK not found."
    echo "  Install NDK r27 LTS via Android Studio or sdkmanager:"
    echo "    sdkmanager \"ndk;27.3.13750724\""
    echo "  Or set ANDROID_NDK_HOME to its path."
    exit 1
fi

echo "Android NDK: $NDK_PATH"
export ANDROID_NDK_HOME="$NDK_PATH"

# Check if gomobile is installed
if ! command -v gomobile &> /dev/null; then
    echo "gomobile not found — installing..."
    go install golang.org/x/mobile/cmd/gomobile@latest
    go install golang.org/x/mobile/cmd/gobind@latest

    # Ensure GOPATH/bin is in PATH
    GOPATH_BIN="$(go env GOPATH)/bin"
    export PATH="$PATH:$GOPATH_BIN"

    if ! command -v gomobile &> /dev/null; then
        echo "Error: gomobile install succeeded but binary not found in PATH."
        echo "  Add $(go env GOPATH)/bin to your PATH and re-run this script."
        exit 1
    fi
fi

echo "gomobile: $(gomobile version 2>&1 | head -1)"

# Initialize gomobile (required before first build)
echo ""
echo "Initializing gomobile..."
gomobile init

# Create output directory
mkdir -p "$ANDROID_LIBS_DIR"

# Navigate to Go backend directory
cd "$GO_BACKEND_DIR"

# Download / tidy dependencies
echo ""
echo "Downloading Go dependencies..."
go mod download
go mod tidy

# Build AAR for Android (arm64-v8a + armeabi-v7a, API 24+)
echo ""
echo "Building gobackend.aar for Android..."
gomobile bind \
    -target=android \
    -androidapi 24 \
    -o "$ANDROID_LIBS_DIR/gobackend.aar" \
    .

# Verify output
if [ -f "$ANDROID_LIBS_DIR/gobackend.aar" ]; then
    SIZE=$(du -sh "$ANDROID_LIBS_DIR/gobackend.aar" | cut -f1)
    echo ""
    echo "✅ Successfully built gobackend.aar ($SIZE)"
    echo "Output: $ANDROID_LIBS_DIR/gobackend.aar"
    ls -lh "$ANDROID_LIBS_DIR/"
else
    echo ""
    echo "❌ Failed to build gobackend.aar"
    exit 1
fi

echo ""
echo "=== Build Complete ==="
echo "Next steps:"
echo "1. Run 'flutter pub get' from the project root"
echo "2. Run 'flutter build apk --release' to build the APK"
echo "   or 'flutter run' to run on a connected device"
