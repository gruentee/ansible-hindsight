# Testing the role with Molecule

Scenarios live in `molecule/`. All but `validation` and `image` use the `docker` driver with a
privileged systemd container that runs the role's own rootful Podman (see
`docs/adr/0001-molecule-with-nested-podman.md`). `spike` is the ADR's reference scenario, not a test.

Run one with `molecule test -s <scenario>`; on a multi-platform scenario add
`--platform-name <distro>-<scenario>` to run a single distribution.

| Scenario | What it proves | Platforms |
|---|---|---|
| `default` | converge, idempotence, check mode, verify | debian12, ubuntu2204, ubuntu2604, rocky9 |
| `host-path` | host-path data volume, `:Z`, ownership | same four |
| `network` | bind address, ports, access key, `hindsight_extra_env` | ubuntu2604 |
| `external-db` | External Database against a pgvector container | ubuntu2604 + pgvector |
| `upgrade` | backup, prune, downgrade refusal, failed-readiness rerun | ubuntu2604 |
| `preflight` | disk check fails before the pull | ubuntu2604 |
| `validation`, `image` | up-front validation, tag composition (no container, no pull) | localhost |

## Conventions

`scripts/check-conventions.sh` enforces these in the pre-commit hook:

- Platform names are `<distro>-<scenario>` (`ubuntu2604-upgrade`). Docker container names are global
  on the host, so a reused name collides with any other Molecule run in progress.
- Test playbooks never register under `hindsight_`; that prefix is the role's public contract.
- Every variable in `defaults/main.yml` has a comment, and the README mirrors it.

## Verification limits on a developer machine

- **Disk:** the full image is about 9 GB and nested Podman stores a copy per platform; budget about
  3 GB of Podman storage per platform on top of the Docker layers. The first pull took about two
  hours when several agents pulled in parallel.
- **SELinux:** the Docker host shares its kernel with the containers, so enforcing SELinux and the `:Z`
  relabel cannot be exercised in Molecule on a host without SELinux. Check it on a Rocky or RHEL VM.
- **GitHub Actions:** `.github/workflows/` cannot run locally. They are checked only by yamllint.
- **Host Podman is not needed.** Docker runs the outer containers; the role installs Podman inside them.

## Linter false positive: `key-order[task]`

`ansible-rust-lint` (the pinned `ansible-lint-but-fast`) reports `key-order[task]` on a task that
already starts with `name`, at the wrong line, and ignores some `# noqa` comments. The hook skips the
rule. Minimal repro: a task with `register` and `failed_when: false`, followed by a task with a list `when`:

```yaml
- name: S
  ansible.builtin.slurp:
    src: x
  register: y
  failed_when: false

- name: A
  ansible.builtin.set_fact:
    z: true
  when:
    - a
    - b
```

Remove the `--skip-list "key-order[task]"` argument in `.pre-commit-config.yaml` once the tool is fixed.
