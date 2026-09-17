#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$PROJECT_DIR/ABG"
PBXPROJ="$PROJECT_DIR/ABG.xcodeproj/project.pbxproj"
PLIST="$APP_DIR/GoogleService-Info.plist"

echo "Project: $PROJECT_DIR"

if [[ -f "$PLIST" ]]; then
  echo "[OK] GoogleService-Info.plist presente"
else
  echo "[MISSING] GoogleService-Info.plist non trovato in $APP_DIR"
fi

if command -v xcodebuild >/dev/null 2>&1; then
  if XCODE_VERSION="$(xcodebuild -version 2>/dev/null | head -n 1)" && [[ -n "$XCODE_VERSION" ]]; then
    echo "[OK] xcodebuild disponibile: $XCODE_VERSION"
  else
    echo "[MISSING] Xcode non attivato per CLI. Apri Xcode e poi esegui:"
    echo "          sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  fi
else
  echo "[MISSING] xcodebuild non disponibile"
fi

if grep -q "paolo.ABG" "$PBXPROJ"; then
  echo "[INFO] Bundle ID attuale nel pbxproj: paolo.ABG"
fi

if grep -q "firebase-ios-sdk" "$PBXPROJ"; then
  echo "[OK] Package Firebase presente"
else
  echo "[MISSING] Package Firebase assente"
fi

if grep -q "GoogleSignIn" "$PBXPROJ"; then
  echo "[OK] Package GoogleSignIn presente"
else
  echo "[MISSING] Package GoogleSignIn non risulta nel pbxproj"
fi

echo "Checklist manuale rapida:"
echo "1) Add Files to ABG (Core/Models/Services/Features/AppContainer/RootView/AppDelegate)"
echo "2) Add Package Dependencies (Firebase + GoogleSignIn)"
echo "3) URL Types con REVERSED_CLIENT_ID"
echo "4) Capability NFC + Sign in with Apple"
