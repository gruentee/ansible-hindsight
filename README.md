# ansible-hindsight

An Ansible role that installs and configures [Hindsight](https://hindsight.vectorize.io), Vectorize's agent memory engine, on a Linux host. It runs the official image with Podman under systemd.

This role is under construction. The design is in the repository's issue tracker; vocabulary is in `GLOSSARY.md`. `defaults/main.yml` lists every public variable with its default and a short description.

## Contributing

Hooks are run with [prek](https://prek.j178.dev) and defined in `.pre-commit-config.yaml`:

```sh
scripts/install-lint-tool.sh   # builds the linter at the pinned commit (needs a Rust toolchain)
prek install                   # run the hooks on every commit
prek run --all-files           # run them once over the whole repository
```

The linter is [ansible-lint-but-fast](https://github.com/gruentee/ansible-lint-but-fast) at the `production` profile. It has no releases, so the commit to build is pinned in `.ansible-lint-but-fast-rev`. The installed binary is named `ansible-rust-lint`.
