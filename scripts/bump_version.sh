#!/usr/bin/env bash
# Naikin build number (angka setelah +) di pubspec.yaml. Jalanin sebelum tiap build release.
set -euo pipefail
cd "$(dirname "$0")/.."

current=$(grep -oP '^version: \K.*' pubspec.yaml)
name=${current%+*}
build=${current#*+}
next=$((build + 1))

sed -i "s/^version: .*/version: ${name}+${next}/" pubspec.yaml
echo "version: ${current} -> ${name}+${next}"
