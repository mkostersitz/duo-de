#!/bin/bash

# Checks (and optionally prepares) an Ubuntu machine for building DUO-DE.
#
#   bash setup-host.sh [build-dir]             # only check, change nothing
#   bash setup-host.sh --install [build-dir]   # also install packages and tools (uses sudo)
#
# build-dir is where the AOSP tree will live (default: ~/aosp).

INSTALL=false
if [ "$1" == "--install" ]; then
    INSTALL=true
    shift
fi
BUILD_DIR="${1:-$HOME/aosp}"

PACKAGES="aapt android-sdk-libsparse-utils bc bison build-essential curl dos2unix flex fontconfig \
g++-multilib gcc-multilib git git-lfs gnupg gperf imagemagick jq lib32z1-dev libc6-dev-i386 \
libelf-dev libgl1-mesa-dev libncurses-dev libssl-dev libstdc++6 libx11-dev libxml2-utils \
locales lunzip lzip lzop m4 make openjdk-17-jdk python-is-python3 python3-pip rsync \
squashfs-tools tree unzip wget x11proto-core-dev xattr xmlstarlet xsltproc xz-utils zip zlib1g-dev"

FAILS=0
WARNS=0
ok()   { echo "  [ OK ] $*"; }
warn() { echo "  [WARN] $*"; WARNS=$((WARNS+1)); }
fail() { echo "  [FAIL] $*"; FAILS=$((FAILS+1)); }

echo "--> Hardware"
arch="$(uname -m)"
[ "$arch" == "x86_64" ] && ok "CPU architecture: $arch" \
    || fail "CPU architecture: $arch (the AOSP build tools only run on x86_64)"

cores=$(nproc)
if [ $cores -ge 16 ]; then ok "CPU threads: $cores"
elif [ $cores -ge 8 ]; then warn "CPU threads: $cores (works, expect 8-12 hours for a first build)"
else fail "CPU threads: $cores (8 or more needed for a reasonable build time)"; fi

ram=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)
swap=$(awk '/SwapTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)
if [ $ram -ge 60 ]; then ok "RAM: ${ram} GB, swap: ${swap} GB"
elif [ $((ram+swap)) -ge 60 ]; then warn "RAM: ${ram} GB, swap: ${swap} GB (works with swap, but slowly)"
else fail "RAM: ${ram} GB, swap: ${swap} GB (need 64 GB, or 32 GB RAM plus 32 GB swap)"; fi

mkdir -p "$BUILD_DIR" 2>/dev/null
free_gb=$(df -BG --output=avail "$BUILD_DIR" 2>/dev/null | tail -1 | tr -dc 0-9)
fstype=$(df --output=fstype "$BUILD_DIR" 2>/dev/null | tail -1)
if [ -z "$free_gb" ]; then fail "Cannot check free space in $BUILD_DIR"
elif [ $free_gb -ge 400 ]; then ok "Free disk in $BUILD_DIR: ${free_gb} GB ($fstype)"
else fail "Free disk in $BUILD_DIR: ${free_gb} GB (need at least 400 GB)"; fi
case "$fstype" in
    ext4|xfs|btrfs) ;;
    *) warn "Filesystem $fstype: use ext4 (or xfs/btrfs), the tree needs a case-sensitive POSIX filesystem" ;;
esac
dev=$(df --output=source "$BUILD_DIR" 2>/dev/null | tail -1 | sed 's#/dev/##; s#p\?[0-9]*$##')
if [ -n "$dev" ] && [ -f /sys/block/$dev/queue/rotational ] && [ "$(cat /sys/block/$dev/queue/rotational)" == "1" ]; then
    warn "$BUILD_DIR is on a spinning disk, an SSD is several times faster"
fi

echo "--> Operating system"
. /etc/os-release
case "$VERSION_ID" in
    22.04|24.04) ok "$PRETTY_NAME" ;;
    *) warn "$PRETTY_NAME is not an LTS release. It may work, but 24.04 LTS is what the build is tested with" ;;
esac

# Ubuntu 24.04+ blocks unprivileged user namespaces through AppArmor, which breaks the
# nsjail sandbox used by parts of the AOSP build
userns=$(sysctl -n kernel.apparmor_restrict_unprivileged_userns 2>/dev/null)
if [ "$userns" == "1" ]; then
    if $INSTALL; then
        echo "kernel.apparmor_restrict_unprivileged_userns=0" | sudo tee /etc/sysctl.d/60-aosp-userns.conf >/dev/null
        sudo sysctl -q -p /etc/sysctl.d/60-aosp-userns.conf && ok "Allowed unprivileged user namespaces (needed by the build sandbox)"
    else
        warn "Unprivileged user namespaces are restricted, the build sandbox (nsjail) may fail. --install fixes it"
    fi
fi

if [ $(ulimit -n) -lt 4096 ]; then
    warn "Open files limit is $(ulimit -n), run 'ulimit -n 65536' before building"
fi

echo "--> Packages"
if $INSTALL; then
    sudo dpkg --add-architecture i386
    sudo apt-get update
    sudo apt-get install -y $PACKAGES
fi
missing=""
for p in $PACKAGES; do
    dpkg -s "$p" >/dev/null 2>&1 || missing="$missing $p"
done
[ -z "$missing" ] && ok "All build packages installed" || fail "Missing packages:$missing"

if ! command -v repo >/dev/null; then
    if $INSTALL; then
        mkdir -p "$HOME/bin"
        curl -sfL https://storage.googleapis.com/git-repo-downloads/repo -o "$HOME/bin/repo" && chmod +x "$HOME/bin/repo"
        grep -q 'HOME/bin' "$HOME/.profile" 2>/dev/null || echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.profile"
        export PATH="$HOME/bin:$PATH"
    fi
fi
command -v repo >/dev/null && ok "repo: $(command -v repo)" || fail "repo is not installed"

if $INSTALL; then
    git lfs install >/dev/null
fi
git lfs version >/dev/null 2>&1 && ok "git-lfs" || fail "git-lfs is not set up"

if [ -n "$(git config --global user.name)" ] && [ -n "$(git config --global user.email)" ]; then
    ok "git identity: $(git config --global user.name) <$(git config --global user.email)>"
else
    fail "git user.name/user.email not set, 'git am' needs them:
         git config --global user.name \"Your Name\"; git config --global user.email you@example.com"
fi

if ! timeout 20 git ls-remote https://android.googlesource.com/platform/manifest refs/heads/main >/dev/null 2>&1; then
    fail "Cannot reach android.googlesource.com"
else
    ok "android.googlesource.com is reachable"
fi

echo
echo "--> $FAILS problem(s), $WARNS warning(s)"
if [ $FAILS -eq 0 ]; then
    echo "Ready. Next:"
    echo "  cd $BUILD_DIR"
    echo "  git clone -b main-16 https://github.com/mkostersitz/duo-de treble_aosp"
    echo "  bash treble_aosp/build.sh"
fi
[ $FAILS -eq 0 ]
