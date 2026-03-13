#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

export ZEPHYR_TOOLCHAIN_VARIANT="zephyr"
export ZEPHYR_SDK_INSTALL_DIR="/home/phatbh/zephyr-sdk-0.17.4"
VENV_DIR="$ROOT/.venv"
FIX_CONF="$ROOT/config/teo-build-fix.conf"
OUT_ROOT="/home/phatbh/Documents/Pilar"
SHARE_ROOT="/mnt/hgfs/Temp"

mkdir -p "$OUT_ROOT"

if [ ! -d "$VENV_DIR" ]; then
  python3 -m venv "$VENV_DIR"
fi

# shellcheck disable=SC1091
. "$VENV_DIR/bin/activate"

python -m pip install -U pip setuptools wheel
python -m pip install west pyelftools
python -m pip install -r zephyr/scripts/requirements-base.txt -r zephyr/scripts/requirements-build-test.txt

if [ ! -f "$FIX_CONF" ]; then
  cat > "$FIX_CONF" <<'EOF'
CONFIG_PICOLIBC_USE_MODULE=y
EOF
fi

west update
west zephyr-export

west build -p always -d build/settings_reset -b nice_nano_v2 -s zmk/app -- \
  -DZMK_CONFIG="$ROOT/config" \
  -DSHIELD=settings_reset \
  -DEXTRA_CONF_FILE="$FIX_CONF"

west build -p always -d build/flake -b nice_nano_v2 -s zmk/app -- \
  -DZMK_CONFIG="$ROOT/config" \
  -DSHIELD=pipar_flake \
  -DEXTRA_CONF_FILE="$FIX_CONF"

next_version_dir() {
  local max=0 d base n
  shopt -s nullglob
  for d in "$OUT_ROOT"/Versio_*; do
    base="${d##*/Versio_}"
    if [[ "$base" =~ ^[0-9]+$ ]] && (( base > max )); then
      max="$base"
    fi
  done
  shopt -u nullglob
  n=$((max + 1))
  echo "$OUT_ROOT/Versio_$n"
}

DEST="$(next_version_dir)"
mkdir -p "$DEST"

cp -f build/settings_reset/zephyr/zmk.uf2 "$DEST/settings_reset.uf2"
cp -f build/settings_reset/zephyr/zmk.elf "$DEST/settings_reset.elf"
cp -f build/flake/zephyr/zmk.uf2 "$DEST/pipar_flake.uf2"
cp -f build/flake/zephyr/zmk.elf "$DEST/pipar_flake.elf"

if [ -d "$SHARE_ROOT" ]; then
  SHARE_DEST="$SHARE_ROOT/$(basename "$DEST")"
  mkdir -p "$SHARE_DEST"
  cp -f "$DEST"/* "$SHARE_DEST"/
  printf 'Copied artifacts to share: %s\n' "$SHARE_DEST"
fi

printf 'Copied artifacts to: %s\n' "$DEST"
ls -lh "$DEST"
