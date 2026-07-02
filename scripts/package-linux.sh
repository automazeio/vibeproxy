#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

version="${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)}"
version="${version:-0.0.0}"
release="${RELEASE:-1}"
arch="${ARCH:-$(uname -m)}"
dist_dir="${DIST_DIR:-$project_dir/dist}"
cache_dir="${CACHE_DIR:-$project_dir/.cache/linux-packaging}"
host_arch="$(uname -m)"
nfpm_version="${NFPM_VERSION:-2.47.0}"

case "$host_arch" in
  x86_64 | amd64)
    nfpm_host_arch=x86_64
    ;;
  aarch64 | arm64)
    nfpm_host_arch=arm64
    ;;
  *)
    echo "Unsupported nFPM host architecture: $host_arch" >&2
    exit 1
    ;;
esac

case "$arch" in
  x86_64 | amd64)
    nfpm_arch=amd64
    asset_arch=amd64
    ;;
  aarch64 | arm64)
    nfpm_arch=arm64
    asset_arch=aarch64
    ;;
  *)
    echo "Unsupported Linux architecture: $arch" >&2
    exit 1
    ;;
esac

package_root="$project_dir/build/linux/$nfpm_arch/package-root"

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

need curl
need jq
need tar
need sha256sum

mkdir -p "$dist_dir" "$cache_dir" "$package_root/usr/bin" "$package_root/usr/lib/vibeproxy"

if [[ -n "${CLIPROXY_VERSION:-}" ]]; then
  cliproxy_tag="v${CLIPROXY_VERSION#v}"
elif [[ -n "${CLIPROXY_TAG:-}" ]]; then
  cliproxy_tag="$CLIPROXY_TAG"
else
  latest_json="$(curl -fsSL https://api.github.com/repos/router-for-me/CLIProxyAPI/releases/latest)"
  cliproxy_tag="$(jq -r '.tag_name' <<< "$latest_json")"
fi

if [[ -z "$cliproxy_tag" || "$cliproxy_tag" == "null" ]]; then
  echo "Could not resolve CLIProxyAPI release tag" >&2
  exit 1
fi

release_json="$(curl -fsSL "https://api.github.com/repos/router-for-me/CLIProxyAPI/releases/tags/$cliproxy_tag")"

asset_regex="^CLIProxyAPI_.+_linux_${asset_arch}\\.tar\\.gz$"
asset_name="$(jq -r --arg regex "$asset_regex" '.assets[] | select(.name | test($regex)) | .name' <<< "$release_json" | head -n 1)"
asset_url="$(jq -r --arg regex "$asset_regex" '.assets[] | select(.name | test($regex)) | .browser_download_url' <<< "$release_json" | head -n 1)"
if [[ -z "$asset_name" || "$asset_name" == "null" || -z "$asset_url" || "$asset_url" == "null" ]]; then
  echo "Could not find CLIProxyAPI Linux asset for $asset_arch in $cliproxy_tag" >&2
  jq -r '.assets[].name' <<< "$release_json" >&2
  exit 1
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

echo "Downloading $asset_name"
curl -fL --retry 3 --retry-delay 5 -o "$work_dir/$asset_name" "$asset_url"
curl -fsSL "https://github.com/router-for-me/CLIProxyAPI/releases/download/$cliproxy_tag/checksums.txt" -o "$work_dir/cliproxy-checksums.txt"
(cd "$work_dir" && awk -v name="$asset_name" '$2 == name { print }' cliproxy-checksums.txt | sha256sum -c -)
tar -xzf "$work_dir/$asset_name" -C "$work_dir"

binary_path="$(find "$work_dir" -type f \( -name CLIProxyAPI -o -name cli-proxy-api -o -name CLIProxyAPIPlus -o -name cli-proxy-api-plus \) | head -n 1)"
if [[ -z "$binary_path" ]]; then
  binary_path="$(find "$work_dir" -type f -perm /111 | head -n 1)"
fi
if [[ -z "$binary_path" ]]; then
  echo "Could not find CLIProxyAPI binary in $asset_name" >&2
  tar -tf "$work_dir/$asset_name" >&2
  exit 1
fi

cp packaging/linux/vibeproxy "$package_root/usr/bin/vibeproxy"
cp "$binary_path" "$package_root/usr/lib/vibeproxy/cli-proxy-api-plus"
chmod 0755 "$package_root/usr/bin/vibeproxy" "$package_root/usr/lib/vibeproxy/cli-proxy-api-plus"

nfpm_bin="${NFPM_BIN:-}"
if [[ -z "$nfpm_bin" ]]; then
  if command -v nfpm >/dev/null 2>&1; then
    nfpm_bin="$(command -v nfpm)"
  else
    nfpm_tag="v$nfpm_version"
    nfpm_json="$(curl -fsSL "https://api.github.com/repos/goreleaser/nfpm/releases/tags/$nfpm_tag")"
    nfpm_asset="nfpm_${nfpm_version}_Linux_${nfpm_host_arch}.tar.gz"
    nfpm_url="$(jq -r --arg name "$nfpm_asset" '.assets[] | select(.name == $name) | .browser_download_url' <<< "$nfpm_json")"
    if [[ -z "$nfpm_url" || "$nfpm_url" == "null" ]]; then
      echo "Could not find nFPM asset $nfpm_asset" >&2
      jq -r '.assets[].name' <<< "$nfpm_json" >&2
      exit 1
    fi
    mkdir -p "$cache_dir/nfpm-$nfpm_version"
    curl -fL --retry 3 --retry-delay 5 -o "$work_dir/$nfpm_asset" "$nfpm_url"
    curl -fsSL "https://github.com/goreleaser/nfpm/releases/download/$nfpm_tag/checksums.txt" -o "$work_dir/nfpm-checksums.txt"
    (cd "$work_dir" && awk -v name="$nfpm_asset" '$2 == name { print }' nfpm-checksums.txt | sha256sum -c -)
    tar -xzf "$work_dir/$nfpm_asset" -C "$cache_dir/nfpm-$nfpm_version"
    nfpm_bin="$cache_dir/nfpm-$nfpm_version/nfpm"
  fi
fi

export VERSION="$version"
export RELEASE="$release"
export NFPM_ARCH="$nfpm_arch"

deb_target="$dist_dir/VibeProxy-linux-$nfpm_arch.deb"
rpm_target="$dist_dir/VibeProxy-linux-$nfpm_arch.rpm"
nfpm_config="$work_dir/nfpm.yaml"
sed "s#__LINUX_PACKAGE_ROOT__#$package_root#g" packaging/linux/nfpm.yaml > "$nfpm_config"

"$nfpm_bin" pkg --config "$nfpm_config" --packager deb --target "$deb_target"
"$nfpm_bin" pkg --config "$nfpm_config" --packager rpm --target "$rpm_target"

(cd "$dist_dir" && sha256sum "$(basename "$deb_target")" "$(basename "$rpm_target")" > "VibeProxy-linux-$nfpm_arch.sha256")

echo "Created:"
ls -lh "$deb_target" "$rpm_target" "$dist_dir/VibeProxy-linux-$nfpm_arch.sha256"
