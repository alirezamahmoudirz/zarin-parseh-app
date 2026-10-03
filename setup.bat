@echo off
flutter create .
flutter pub get
flutter analyze
flutter build apk --release
pause
