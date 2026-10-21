#!/usr/bin/env bash
# Mechanical repo conventions (see docs/molecule.md):
#  - every public variable in defaults/main.yml sits under a comment (a comment may cover
#    adjacent variables with no blank line between them);
#  - the hindsight_ prefix belongs to the role's public variables, so Molecule playbooks
#    must not register results under it;
#  - Molecule platform names follow <distro>-<scenario> (spike and the delegated localhost excepted).
set -euo pipefail
cd "$(dirname "$0")/.."

status=0

awk '
  /^hindsight_[a-z0-9_]+:/ { if (!covered) { printf "defaults/main.yml:%d: %s has no comment above it\n", NR, $1; bad = 1 } }
  /^#/                     { covered = 1; next }
  /^hindsight_[a-z0-9_]+:/ { next }
  { covered = 0 }
  END { exit bad }
' defaults/main.yml >&2 || status=1

if grep -rnE '^\s*register:\s*hindsight_' molecule --include='*.yml' >&2; then
  echo "molecule: register under a non-hindsight_ name; the prefix is reserved for role variables" >&2
  status=1
fi

for f in molecule/*/molecule.yml; do
  scenario=$(basename "$(dirname "$f")")
  [ "$scenario" = spike ] && continue
  while read -r name; do
    case "$name" in
      localhost | *-"$scenario") ;;
      *) echo "$f: platform '$name' should end in -$scenario" >&2; status=1 ;;
    esac
  done < <(awk '/^platforms:/{p=1;next} /^[a-z]/{p=0} p && /^  - name:/{print $3}' "$f")
done

exit "$status"
