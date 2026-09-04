#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

remote=0
big=0
for arg in "$@"; do
  case "$arg" in
    --remote) remote=1 ;;
    --big) big=1 ;;
    *) echo "usage: $0 [--remote] [--big]" >&2; exit 2 ;;
  esac
done

mkdir -p .data
migrate=(npx wrangler d1 migrations apply tshop-counts-proto)
put=(npx wrangler r2 object put)
if [[ "$remote" -eq 0 ]]; then
  migrate+=(--local)
  put+=(--local)
else
  migrate+=(--remote)
  put+=(--remote)
fi
CI=1 "${migrate[@]}"

if [[ ! -f .data/dummy-1m.bin ]]; then
  dd if=/dev/urandom of=.data/dummy-1m.bin bs=1M count=1 status=none
fi
"${put[@]}" tshop-apk-proto/dummy-1m.bin --file .data/dummy-1m.bin \
  --content-type application/vnd.android.package-archive

if [[ "$big" -eq 1 ]]; then
  if [[ ! -f .data/dummy-200m.bin ]]; then
    dd if=/dev/urandom of=.data/dummy-200m.bin bs=1M count=200 status=progress
  fi
  "${put[@]}" tshop-apk-proto/dummy-200m.bin --file .data/dummy-200m.bin \
    --content-type application/vnd.android.package-archive
fi
