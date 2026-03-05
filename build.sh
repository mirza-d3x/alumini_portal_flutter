#!/bin/bash
# Exit on error
set -e

# Ensure web support is enabled
flutter config --enable-web

# Get dependencies
flutter pub get

# Build the web app, using the API_URL environment variable set in Vercel
flutter build web --release --dart-define=API_URL=$API_URL
