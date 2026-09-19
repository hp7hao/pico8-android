#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
godot_bin=${GODOT_BIN:-godot}
output=${1:-"$repo_root/pico8-frontend-debug.apk"}

if [[ ! -s "$repo_root/frontend/package.dat" ]]; then
  cat >&2 <<EOF
Missing frontend/package.dat.
Obtain it from the matching upstream release APK, for example:
  unzip -p /path/to/pico8-frontend.apk assets/package.dat > "$repo_root/frontend/package.dat"
EOF
  exit 1
fi

version=$($godot_bin --version | awk -F. '{ print $1 "." $2 "." $3 "." $4 }')
template_dir=${GODOT_TEMPLATE_DIR:-"$HOME/.local/share/godot/export_templates/$version"}
android_source="$template_dir/android_source.zip"

if [[ ! -f "$android_source" ]]; then
  cat >&2 <<EOF
Missing Godot Android export template: $android_source
Install the export templates matching Godot $version first.
EOF
  exit 1
fi

work_root=$(mktemp -d "${TMPDIR:-/data/devtmp}/pico8-android-build.XXXXXX")
trap 'rm -rf "$work_root"' EXIT
mkdir -p "$work_root/frontend/android/build"
rsync -a --exclude='.godot/' --exclude='android/' --exclude='*.apk' \
  "$repo_root/frontend/" "$work_root/frontend/"

# package.dat is recovered from an upstream APK, but first-party bootstrap
# fixes live in this repository. Overlay them in the isolated build tree so a
# stale recovered archive cannot silently discard the current shim/runtime.
bootstrap_tree="$work_root/bootstrap"
mkdir -p "$bootstrap_tree"
tar --no-same-owner -xzf "$work_root/frontend/package.dat" -C "$bootstrap_tree"
install -m 755 "$repo_root/shim/picoshim.so" \
  "$bootstrap_tree/package/rootfs/home/pico/picoshim.so"
install -m 755 "$repo_root/shim/package/start_pico_proot.sh" \
  "$bootstrap_tree/package/start_pico_proot.sh"
tar -C "$bootstrap_tree" -czf "$work_root/frontend/package.dat" package

unzip -q "$android_source" -d "$work_root/frontend/android/build"
printf '%s\n' "$version" > "$work_root/frontend/android/.build_version"

mkdir -p "$(dirname "$output")"
JAVA_HOME=${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk} \
ANDROID_HOME=${ANDROID_HOME:-/opt/android-sdk} \
ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/opt/android-sdk}} \
  "$godot_bin" --headless --path "$work_root/frontend" \
  --export-debug Android "$output"

printf 'Built %s\n' "$output"
