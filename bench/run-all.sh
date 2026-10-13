#!/usr/bin/env bash
# usage: bench/run-all.sh [id ...]   (from repo root; no ids = all; CFG=... for a variant)
# Runs non-interactively with --yolo (safe here: write/exec denied, fetch limited to PANW domains).
cfg="${CFG:-agents/#1Prisma-Cortex-Product-Hub.yaml}"
res=bench/results.tsv
[ -f "$res" ] || printf 'date\tconfig\tid\tseconds\tresult\tnote\n' > "$res"
while IFS='|' read -r id expect q; do
  case "$id" in ''|\#*) continue;; esac
  if [ $# -gt 0 ]; then printf '%s\n' "$@" | grep -qxF "$id" || continue; fi
  start=$(date +%s)
  CFG="$cfg" YOLO=1 scripts/run.sh "$q" </dev/null >/dev/null 2>&1; rc=$?
  secs=$(( $(date +%s) - start ))
  out=$(cat outputs/.last 2>/dev/null); first=$(head -1 "$out" 2>/dev/null); note=""
  case "$expect" in
    oos)      [[ "$first" == "OUT OF SCOPE"* ]] || { rc=1; note="expected OUT OF SCOPE"; } ;;
    briefing) [[ "$first" == "# PANW Briefing"* ]] || { rc=1; note="no briefing: ${first:0:40}"; }
              grep -q 'No claims could be verified' "$out" 2>/dev/null && { rc=1; note="all claims rejected"; } ;;
  esac
  [ $rc -eq 0 ] && r=PASS || r=FAIL
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date +%F)" "$(basename "$cfg")" "$id" "$secs" "$r" "$note" | tee -a "$res"
done < bench/questions.txt
