#!/usr/bin/env bash
set -euo pipefail

# Interactive dispatcher for common AWS tasks in this repo.

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

declare -A CATS
CATS=(
  [identity]="$ROOT_DIR/identity"
  [networking]="$ROOT_DIR/networking"
  [compute]="$ROOT_DIR/compute"
  [containers]="$ROOT_DIR/containers"
  [storage]="$ROOT_DIR/storage"
  [cdn]="$ROOT_DIR/cdn"
  [observability]="$ROOT_DIR/observability"
  [security]="$ROOT_DIR/security"
  [data]="$ROOT_DIR/data"
  [ops]="$ROOT_DIR/ops"
)

echo "AWS helper launcher"
read -rp "Default AWS profile [default]: " PROFILE
PROFILE="${PROFILE:-default}"
read -rp "Default AWS region (blank = script default): " REGION

echo
echo "Select a category:"
cat_names=("${!CATS[@]}")
IFS=$'\n' cat_names=($(sort <<<"${cat_names[*]}")); unset IFS
select cat in "${cat_names[@]}"; do
  [[ -n "${cat:-}" ]] || { echo "Invalid selection"; continue; }
  DIR="${CATS[$cat]}"
  if [[ ! -d "$DIR" ]]; then echo "No directory for $cat"; exit 1; fi
  echo
  echo "Select a script in $cat:"
  mapfile -t files < <(find "$DIR" -maxdepth 1 -type f -name "*.sh" -exec basename {} \; | sort)
  if [[ ${#files[@]} -eq 0 ]]; then echo "No scripts found in $cat"; exit 1; fi
  select file in "${files[@]}"; do
    [[ -n "${file:-}" ]] || { echo "Invalid selection"; continue; }
    TARGET="$DIR/$file"
    echo
    echo "Running: $TARGET"
    args=()
    [[ -n "${PROFILE:-}" ]] && args+=("-p" "$PROFILE")
    [[ -n "${REGION:-}" ]] && args+=("-r" "$REGION")
    exec "$TARGET" "${args[@]}"
  done
done

