#!/bin/zsh
# Regenerates the app icon, website icons, README icon, and site color tokens
# from Sources/LinefeedCore/Brand.
set -euo pipefail

project_dir=${0:A:h:h}
work_dir=$(mktemp -d /tmp/linefeed-brand.XXXXXX)
trap 'rm -rf "$work_dir"' EXIT

swiftc -parse-as-library -O \
  "$project_dir/scripts/brand/BrandAssets.swift" \
  "$project_dir/Sources/LinefeedCore/Brand/BrandMark.swift" \
  "$project_dir/Sources/LinefeedCore/Brand/BrandPalette.swift" \
  -o "$work_dir/brand-assets"
"$work_dir/brand-assets" "$project_dir"
