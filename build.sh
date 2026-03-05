#!/bin/bash
# Exit on error
set -e

# ---- Install Flutter (stable) ----
# Shallow clone to keep build fast
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:$(pwd)/flutter/bin"

# Verify installation (optional, helps debugging)
flutter --version

# Enable web support
flutter config --enable-web

# Get Dart/Flutter dependencies
flutter pub get

# Build the web app, using the API_URL environment variable set in Vercel
flutter build web --release --dart-define=API_URL=$API_URL
