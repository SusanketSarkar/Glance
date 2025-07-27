#!/bin/bash

# Build script for Glance PDF Reader
# This script helps build the macOS app using xcodebuild

set -e

echo "🚀 Building Glance PDF Reader..."

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Error: Xcode is not installed or xcodebuild is not in PATH"
    echo "Please install Xcode from the App Store or Apple Developer Portal"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "GlanceApp.swift" ]; then
    echo "❌ Error: GlanceApp.swift not found. Are you in the right directory?"
    exit 1
fi

# Create Xcode project if it doesn't exist
if [ ! -f "Glance.xcodeproj/project.pbxproj" ]; then
    echo "📦 Creating Xcode project..."
    
    # Create basic Xcode project structure
    mkdir -p Glance.xcodeproj
    
    echo "⚠️  Note: You'll need to create an Xcode project manually for the first build."
    echo "   1. Open Xcode"
    echo "   2. Create new macOS App project named 'Glance'"
    echo "   3. Replace default files with the ones in this directory"
    echo "   4. Add Info.plist and entitlements file to project"
    echo "   5. Build and run with ⌘+R"
    echo ""
    echo "🔧 Alternatively, you can build and run with Swift Package Manager:"
    echo "   swift build && swift run"
    echo ""
    exit 0
fi

# Build the project
echo "🔨 Building project..."
xcodebuild -project Glance.xcodeproj -scheme Glance -configuration Release build

# If no Xcode project exists, try Swift Package Manager
echo "🔧 No Xcode project found. Trying Swift Package Manager..."
echo ""

swift build

if [ $? -eq 0 ]; then
    echo "✅ Build completed successfully!"
    echo ""
    echo "🎉 Your Glance PDF Reader is ready!"
    echo ""
    echo "🚀 To run the app:"
    echo "   swift run"
    echo ""
    echo "💡 Note: For a full macOS app bundle with file associations,"
    echo "   consider creating an Xcode project for distribution."
else
    echo "❌ Build failed. Please check the error messages above."
    exit 1
fi 