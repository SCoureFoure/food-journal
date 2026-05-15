#!/usr/bin/env bash
set -e

APP_DIR="$(cd "$(dirname "$0")/app" && pwd)"
IOS_DIR="$APP_DIR/ios"
PLIST="$IOS_DIR/Runner/Info.plist"
APPDELEGATE="$IOS_DIR/Runner/AppDelegate.swift"

echo "[food-journal iOS] Setup starting..."

# --- verify macOS ---
if [[ "$(uname)" != "Darwin" ]]; then
  echo "ERROR: iOS builds require macOS. This script must run on a Mac."
  exit 1
fi

# --- verify tools ---
if ! command -v flutter &>/dev/null; then
  echo "ERROR: flutter not found in PATH."
  exit 1
fi
if ! command -v pod &>/dev/null; then
  echo "ERROR: CocoaPods not found. Run: sudo gem install cocoapods"
  exit 1
fi

# --- verify .env ---
if [[ ! -f "$APP_DIR/.env" ]]; then
  echo "ERROR: app/.env not found. Create it with ANTHROPIC_API_KEY=sk-ant-..."
  exit 1
fi

cd "$APP_DIR"

# --- generate ios/ folder if missing ---
if [[ ! -d "$IOS_DIR" ]]; then
  echo ""
  echo "[1/5] Generating iOS platform folder..."
  flutter create --platforms=ios .
else
  echo "[1/5] ios/ folder already exists — skipping create."
fi

# --- patch Info.plist with required permissions ---
echo ""
echo "[2/5] Patching Info.plist permissions..."

add_plist_key() {
  local key="$1"
  local value="$2"
  if ! /usr/libexec/PlistBuddy -c "Print :$key" "$PLIST" &>/dev/null; then
    /usr/libexec/PlistBuddy -c "Add :$key string $value" "$PLIST"
    echo "  Added: $key"
  else
    echo "  Already set: $key"
  fi
}

add_plist_key "NSCameraUsageDescription" \
  "Used to photograph meals and medications for your journal."

add_plist_key "NSPhotoLibraryUsageDescription" \
  "Used to attach photos from your library to meal entries."

add_plist_key "NSPhotoLibraryAddUsageDescription" \
  "Used to save meal photos to your photo library."

# --- patch AppDelegate for flutter_local_notifications ---
echo ""
echo "[3/5] Patching AppDelegate.swift for notifications..."

cat > "$APPDELEGATE" << 'EOF'
import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
EOF
echo "  AppDelegate.swift written."

# --- enforce minimum iOS 13 in Podfile ---
echo ""
echo "[4/5] Checking Podfile iOS platform version..."

PODFILE="$IOS_DIR/Podfile"
if grep -q "platform :ios" "$PODFILE"; then
  # Replace whatever version is there with 13.0
  sed -i '' "s/platform :ios, '[^']*'/platform :ios, '13.0'/" "$PODFILE"
  echo "  Podfile platform set to iOS 13.0."
else
  echo "  WARNING: could not find 'platform :ios' line in Podfile — check manually."
fi

# --- pod install ---
echo ""
echo "[4/5] pod install..."
cd "$IOS_DIR"
pod install
cd "$APP_DIR"

# --- pub get + codegen ---
echo ""
echo "[5/5] flutter pub get + drift codegen..."
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# --- launch ---
echo ""
echo "Launching on iOS simulator..."
echo "Hot reload: r  |  Hot restart: R  |  Quit: q"
echo ""
flutter run
