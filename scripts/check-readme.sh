#!/usr/bin/env bash
# Cheap README checks: every variable in defaults/main.yml is documented in the README variables
# table, and the example playbook passes ansible-playbook --syntax-check.
set -euo pipefail
cd "$(dirname "$0")/.."

status=0
for var in $(grep -oE '^hindsight_[a-z0-9_]+' defaults/main.yml); do
  if ! grep -qF "| \`$var\` |" README.md; then
    echo "README.md: variables table lacks $var" >&2
    status=1
  fi
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
awk '/<!-- example-playbook -->/{f=1;next} /<!-- \/example-playbook -->/{f=0} f' README.md \
  | sed '/^```/d' > "$work/site.yml"
if [ ! -s "$work/site.yml" ]; then
  echo "README.md: example playbook not found" >&2
  exit 1
fi
mkdir -p "$work/roles" "$work/inventory/group_vars/memory"
ln -s "$PWD" "$work/roles/gruentee.hindsight"
printf 'memory:\n  hosts:\n    host1:\n' > "$work/inventory/hosts.yml"
# Plain stand-ins for the vaulted values the example refers to.
printf 'vault_hindsight_llm_api_key: x\nvault_hindsight_cp_access_key: x\n' \
  > "$work/inventory/group_vars/memory/vault.yml"
if ! ANSIBLE_ROLES_PATH="$work/roles" ansible-playbook -i "$work/inventory/hosts.yml" \
  --syntax-check "$work/site.yml" > /dev/null; then
  echo "README.md: example playbook fails --syntax-check" >&2
  status=1
fi
exit "$status"
