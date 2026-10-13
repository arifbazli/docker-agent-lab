#!/usr/bin/env bash
# usage: scripts/check-briefing.sh <briefing.md> [run.log]
f="${1:?usage: $0 briefing.md [run.log]}"; log="${2:-}"
fail=0
bad() { echo "FAIL: $*"; fail=1; }
ok()  { echo "ok:   $*"; }

[ -s "$f" ] || { echo "FAIL: briefing missing or empty"; exit 1; }

first=$(head -1 "$f")
case "$first" in
  "OUT OF SCOPE:"*|"NO FACTS FOUND:"*|"NO SUPPORTED FACTS AVAILABLE FOR BRIEFING"*)
    ok "valid sentinel: $first"; exit 0;;
  "BRIEFING FAILED:"*) bad "$first"; exit 1;;
esac

if grep -Eq 'https?://[^ )]*\?' "$f"; then bad "URL containing '?'"; else ok "no query-string URLs"; fi

if LC_ALL=C grep -nP '[^\x00-\x7F]' "$f" >/dev/null; then
  bad "non-ASCII characters"; LC_ALL=C grep -nP '[^\x00-\x7F]' "$f" | head -3
else ok "ASCII only"; fi

words=$(sed -E 's#https?://[^ )]+##g' "$f" | wc -w)
max=170
grep -qE '^\*\*(Mapping|Manual work)\*\*' "$f" && max=260
if [ "$words" -le "$max" ]; then ok "$words words (max $max)"; else bad "$words words (max $max)"; fi

for s in '# PANW Briefing' '**Bottom line:**' '**Sources**'; do
  grep -qF -- "$s" "$f" || bad "missing section: $s"
done
if ! grep -qF 'No claims could be verified' "$f"; then
  grep -qF '**Why move**' "$f" || bad "missing section: **Why move**"
fi

if [ -n "$log" ] && [ -s "$log" ]; then
  fetched=$(grep -A6 'Calling fetch(' "$log" | grep -oE 'https?://[^"\\ ]+' | sed -E 's/\.md$//' | sort -u)
  for u in $(grep -oE 'https?://[^ )]+' "$f" | sed -E 's/\.md$//' | sort -u); do
    printf '%s\n' "$fetched" | grep -qxF "$u" || bad "cited but never fetched: $u"
  done
  [ $fail -eq 0 ] && ok "all cited URLs were fetched"
fi

if grep -qF 'No claims could be verified' "$f"; then bad "all claims rejected by verifier"; fi

[ $fail -eq 0 ] && echo "PASS" || echo "FAILED"
exit $fail
