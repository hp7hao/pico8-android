#!/usr/bin/env bash
set -euo pipefail

addon_root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
android_home=${ANDROID_HOME:-/opt/android-sdk}
android_jar=${ANDROID_JAR:-"$android_home/platforms/android-31/android.jar"}
build_dir=$(mktemp -d "${TMPDIR:-/data/devtmp}/pico8-manual-aar.XXXXXX")
trap 'rm -rf "$build_dir"' EXIT

if [[ ! -f "$android_jar" ]]; then
  echo "Android API jar not found: $android_jar" >&2
  exit 1
fi

mkdir -p "$build_dir/classes" "$addon_root/bin"
javac -source 8 -target 8 -classpath "$android_jar" -d "$build_dir/classes" \
  "$addon_root/src/io/wip/pico8/manual/ManualLayoutFactory.java"
jar --create --file "$build_dir/classes.jar" -C "$build_dir/classes" .
cat > "$build_dir/AndroidManifest.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="io.wip.pico8.manual">
    <uses-sdk android:minSdkVersion="28" />
</manifest>
EOF
: > "$build_dir/R.txt"
(
  cd "$build_dir"
  zip -q "$addon_root/bin/manual-browser.aar" AndroidManifest.xml classes.jar R.txt
)

echo "Built $addon_root/bin/manual-browser.aar"
