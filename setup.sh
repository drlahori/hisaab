#!/bin/bash
# One-time setup for Hisaab on a Mac. Run:  bash setup.sh
set -e
cd "$(dirname "$0")"

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is missing. Install it first from https://brew.sh" ; exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "==> Installing Flutter (one time, takes a few minutes)"
  brew install --cask flutter
fi

if ! command -v pod >/dev/null 2>&1; then
  echo "==> Installing CocoaPods (needed for iPhone builds)"
  brew install cocoapods
fi

echo "==> Creating the iPhone and Android project files"
flutter create --org com.gillani --project-name hisaab --platforms ios,android .

echo "==> Adding packages"
flutter pub add path_provider intl share_plus file_picker
flutter pub get

echo ""
echo "Done. Next:"
echo "  Android phone (USB debugging on):  flutter run"
echo "  iPhone simulator:                  open -a Simulator && flutter run"
echo "  Your iPhone:                       see README.md, 'Run on your iPhone'"
