#!/bin/bash
# Exit immediately on error
set -e

echo "=== Installing Flutter (stable) ==="
# Shallow clone for speed
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:$(pwd)/flutter/bin"

echo "=== Flutter version ==="
flutter --version

echo "=== Enabling web support ==="
flutter config --enable-web

echo "=== Cleaning build cache ==="
flutter clean

echo "=== Getting dependencies ==="
flutter pub get

echo "=== Building Flutter web app ==="
# Pass the backend API URL baked into the build
flutter build web --release --dart-define=API_URL=${API_URL:-https://alumni-backend-9qt9.onrender.com/api}

echo "=== Build complete! Output in build/web ==="
