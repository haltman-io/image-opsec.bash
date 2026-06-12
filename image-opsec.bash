#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: image-opsec <directory> --name <prefix>"
  echo "Example: image-opsec /tmp/images --name team-logo"
  exit 1
}

DIR="${1:-}"
[[ -z "$DIR" ]] && usage
shift || true

PREFIX=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      PREFIX="${2:-}"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

[[ -z "$PREFIX" ]] && usage
[[ ! -d "$DIR" ]] && echo "Directory not found: $DIR" && exit 1

# Normalize directory path
DIR="$(realpath "$DIR")"

# Supported image extensions
mapfile -d '' FILES < <(
  find "$DIR" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.tif' -o -iname '*.tiff' -o -iname '*.bmp' -o -iname '*.heic' -o -iname '*.avif' \) \
    -print0 | sort -z
)

COUNT="${#FILES[@]}"

if [[ "$COUNT" -eq 0 ]]; then
  echo "No image files found in: $DIR"
  exit 0
fi

TMPDIR="$DIR/.image-opsec-tmp-$$"
mkdir "$TMPDIR"

i=1

for FILE in "${FILES[@]}"; do
  BASENAME="$(basename "$FILE")"
  EXT="${BASENAME##*.}"
  EXT_LOWER="$(echo "$EXT" | tr '[:upper:]' '[:lower:]')"

  NEW_NAME="$(printf "%s-%03d.%s" "$PREFIX" "$i" "$EXT_LOWER")"
  TMP_FILE="$TMPDIR/$NEW_NAME"

  # Remove all embedded metadata.
  # -all= strips EXIF, XMP, IPTC, GPS, comments, software tags, etc.
  # -overwrite_original avoids backup files.
  exiftool -all= -overwrite_original "$FILE" >/dev/null

  # Move into temp dir first to avoid name collisions.
  mv -- "$FILE" "$TMP_FILE"

  echo "$BASENAME -> $NEW_NAME"
  ((i++))
done

# Move sanitized/renamed files back
find "$TMPDIR" -maxdepth 1 -type f -exec mv -t "$DIR" -- {} +

rmdir "$TMPDIR"

echo
echo "Done. Processed $COUNT image(s)."