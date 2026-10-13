#!/usr/bin/env bash
# usage: scripts/check-seeds.sh [yaml]
y="${1:-agents/#1Prisma-Cortex-Product-Hub.yaml}"; bad=0
for u in $(grep -oE 'https://[^ )"<>]+\.md' "$y" | grep -v '/readme\.md$' | sort -u); do
  body=$(curl -sL --max-time 25 -w '\n%{http_code}' "$u") || { echo "FAIL (curl) $u"; bad=1; continue; }
  code=${body##*$'\n'}
  if [ "$code" != 200 ]; then echo "FAIL $code $u"; bad=1
  elif printf '%s' "$body" | grep -q '^# Page Not Found'; then echo "FAIL soft-404 $u"; bad=1
  else echo "ok   $u"; fi
done
exit $bad
