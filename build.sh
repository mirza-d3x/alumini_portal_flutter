#!/bin/bash
# Exit on error
set -e

# Clone the flutter repository
git clone https://github.com/flutter/flutter.git -b stable

# Add flutter to PATH
export PATH="$PATH:`pwd`/flutter/bin"

# Enable web support (just to be safe)
flutter config --enable-web

# Get dependencies
flutter pub get

# Build the web app, passing the API_URL so the frontend knows where to request
flutter build web --release --dart-define=API_URL=$API_URL
