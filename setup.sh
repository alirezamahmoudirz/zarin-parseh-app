#!/usr/bin/env bash
set -e
flutter create .
flutter pub get
flutter analyze
flutter build apk --release
