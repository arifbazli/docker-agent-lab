#!/usr/bin/env bash
# usage: scripts/run.sh "question"   (run from repo root)
#   CFG=path/to.yaml  override the config
#   YOLO=1            skip fetch approval prompts (needed when stdin is not a TTY)
set -uo pipefail
q="${1:?usage: $0 \"question\"}"
DEFAULT_CFG='agents/#1Prisma-Cortex-Product-Hub.yaml'
cfg="${CFG:-$DEFAULT_CFG}"
mkdir -p outputs logs
slug=$(printf '%s' "$q" | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9' '-' | sed 's/^-//; s/-$//' | cut -c1-50)
ts=$(date +%Y-%m-%d-%H%M%S)
log="logs/$ts-$slug.log"; out="outputs/$ts-$slug.md"
start=$(date +%s)

flags=(--exec); [ "${YOLO:-0}" = 1 ] && flags=(--yolo --exec)
docker-agent run "${flags[@]}" "$cfg" "$q" 2>&1 | tee "$log"

norm() { sed "s/‑/-/g; s/’/'/g; s/‘/'/g; s/“/\"/g; s/”/\"/g; s/–/-/g; s/—/-/g"; }
if grep -q '^# PANW Briefing' "$log"; then
  awk '/^# PANW Briefing/{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' "$log" \
    | grep -v '^> *$' | norm > "$out"
else
  grep -E '^(OUT OF SCOPE|NO FACTS FOUND|NO SUPPORTED FACTS|BRIEFING FAILED)' "$log" | tail -1 | norm > "$out"
fi

echo; echo "=== checks ==="
scripts/check-briefing.sh "$out" "$log"; rc=$?
echo "elapsed: $(( $(date +%s) - start ))s   output: $out"
echo "$out" > outputs/.last
exit $rc
