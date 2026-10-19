#!/usr/bin/env bash
set -euo pipefail
# Linux x86_64 cloud setup. Sources are pinned GitHub releases fetched with TLS verification.
tools_root="${EGG_TOOLS_DIR:-/workspace/tools}"
mkdir -p "$tools_root/rojo" "$tools_root/luau" "$tools_root/lune"
tool_tmp="$(mktemp -d)"
trap 'rm -rf "$tool_tmp"' EXIT
curl --fail --location --silent --show-error --retry 2 \
  https://github.com/rojo-rbx/rojo/releases/download/v7.6.1/rojo-7.6.1-linux-x86_64.zip \
  --output "$tool_tmp/rojo.zip"
curl --fail --location --silent --show-error --retry 2 \
  https://github.com/luau-lang/luau/releases/download/0.695/luau-ubuntu.zip \
  --output "$tool_tmp/luau.zip"
curl --fail --location --silent --show-error --retry 2 \
  https://github.com/lune-org/lune/releases/download/v0.11.0/lune-0.11.0-linux-x86_64.zip \
  --output "$tool_tmp/lune.zip"
(
  cd "$tool_tmp"
  sha256sum --check <<'HASHES'
a9542a713036897fdbd0173e7a105ea409658333133c949025fcb6f1a7ca909d  rojo.zip
0176e2672481829a5e30ade4a81536088ed465ef6dbd729f5e77092289e399b1  luau.zip
5a0ea32c3e13e5e3b1dc415c2056bcfe44258b3a811dcd473c50e3b437d10f72  lune.zip
HASHES
)
unzip -o -q "$tool_tmp/rojo.zip" -d "$tools_root/rojo"
unzip -o -q "$tool_tmp/luau.zip" -d "$tools_root/luau"
unzip -o -q "$tool_tmp/lune.zip" -d "$tools_root/lune"
"$tools_root/lune/lune" --version
"$tools_root/rojo/rojo" --version
"$tools_root/luau/luau" --help > /dev/null
