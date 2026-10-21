# ansible-hindsight

An Ansible role that installs and configures [Hindsight](https://hindsight.vectorize.io), Vectorize's agent memory engine, on a Linux host. It runs the official image with rootful Podman under a systemd unit.

- Supported Target Hosts: Debian 12, Ubuntu 22.04, Ubuntu 26.04 and Enterprise Linux 9 (Rocky, Alma, RHEL), with systemd, on x86_64 and aarch64. Ansible 2.15 or newer on the controller.
- One all-in-one container runs the Hindsight Server (API) and the Control Plane (web UI). The optional separate worker is not deployed.
- Idempotent and `--check` safe. Vocabulary is in `GLOSSARY.md`; the design is in the repository's issue tracker.

## Requirements and security notes

- **Localhost by default.** The API and the Control Plane are published on `127.0.0.1` only (`hindsight_bind_address`). A fresh install is not reachable from the network. To reach it from other machines, use an SSH tunnel or your own reverse proxy, or set `hindsight_bind_address` deliberately.
- **Exposing it.** The role does not add TLS, a reverse proxy or a firewall rule. If you bind to a non-loopback address, the API is open to whoever can reach that port; set `hindsight_cp_access_key` to lock the Control Plane and restrict access with a firewall or proxy.
- **Secrets.** `hindsight_llm_api_key`, `hindsight_cp_access_key` and `hindsight_extra_env` end up in the env file (`hindsight_env_file`, default `/etc/hindsight/hindsight.env`), mode `0600` in a `0700` directory, owned by root. The task that writes it uses `no_log`. Keep the values in Ansible Vault, never in plaintext inventory.
- **Podman** is installed from the distribution repositories only when it is missing (`hindsight_manage_runtime`). The role never adds third-party repositories. Set it to `false` if you manage Podman yourself.
- **Embedded Database** is the default and needs nothing else, but upstream does not recommend it for production. For anything important, use an External Database. The role never installs or manages PostgreSQL.
- **SELinux** is never reconfigured. A host data path is mounted with `:Z`.
- **Disk.** The `full` image is about 9 GB on x86_64 (3.7 GB on aarch64). The role checks free space before a pull (`hindsight_min_free_disk_mb`).
- The first start can take several minutes while models initialise. The role waits for `/health/ready` for up to `hindsight_start_timeout` seconds.

## Variables

All public variables have the `hindsight_` prefix and live in `defaults/main.yml`. "Required" means the role fails up front, naming the variable, if it is not set. "Secret" means: supply it from Ansible Vault; the role keeps it out of task output.

| Variable | Default | Flags | Description |
| --- | --- | --- | --- |
| `hindsight_llm_provider` | `""` | required | LLM provider, for example `openai`, `anthropic`, `ollama`. There is no default: an empty value is rejected. Use `none` to run without an LLM. |
| `hindsight_llm_model` | `""` | | Model name. Empty means the upstream default applies. |
| `hindsight_llm_api_key` | `""` | secret; required unless the provider is `none`, `ollama` or `lmstudio` | API key for the provider. |
| `hindsight_llm_base_url` | `""` | | Custom endpoint, for example Ollama or an OpenAI-compatible server. Empty means omitted. |
| `hindsight_cp_access_key` | `""` | secret | Access key for the Control Plane web UI. Empty means no login gate. |
| `hindsight_bind_address` | `127.0.0.1` | | Host address the published ports bind to. |
| `hindsight_api_port` | `8888` | | Host port for the API. The container port is fixed. |
| `hindsight_cp_port` | `9999` | | Host port for the Control Plane. The container port is fixed. |
| `hindsight_database_url` | `""` | | External Database URL (`postgresql://` or `postgres://`). Empty means the Embedded Database is used. |
| `hindsight_data_volume` | `hindsight-data` | | Named container volume for the Embedded Database. |
| `hindsight_data_host_path` | `""` | | Absolute host directory used instead of the named volume. The role creates it and sets owner `1000:1000`. Empty means use the named volume. |
| `hindsight_env_file` | `/etc/hindsight/hindsight.env` | | Root-only environment file holding the settings and secrets. |
| `hindsight_worker_id` | `{{ inventory_hostname }}` | | Stable worker identity, so in-flight tasks survive container recreation. |
| `hindsight_manage_runtime` | `true` | | Install Podman from the distribution repositories when it is missing. |
| `hindsight_start_timeout` | `420` | | Seconds systemd and the readiness check wait for the first start. |
| `hindsight_stop_timeout` | `120` | | Seconds systemd waits for a graceful stop. |
| `hindsight_shm_size` | `1g` | | Shared memory size passed to the container. |
| `hindsight_service_enabled` | `true` | | Enable the service at boot. |
| `hindsight_service_state` | `started` | | Desired service state. The readiness check runs only for `started`. |
| `hindsight_extra_env` | `{}` | secret | Extra `HINDSIGHT_*` settings written to the env file. Role-managed variables win on conflict. |
| `hindsight_image` | `ghcr.io/vectorize-io/hindsight` | | Image repository. |
| `hindsight_image_tag` | `"1.0.0"` | | Bare version. The role appends the `-slim` suffix itself. Pin an exact `X.Y.Z`; anything else warns. |
| `hindsight_image_variant` | `full` | | `full` bundles the local embedding and reranker models; `slim` needs external providers. |
| `hindsight_min_free_disk_mb` | `2048` for `slim`, else `15360` | | Minimum free space (MB) where Podman stores images, checked before a pull. `0` disables the check. |
| `hindsight_allow_downgrade` | `false` | | Allow installing a lower version than the one running. Upstream documents no downgrade path. |
| `hindsight_backup_before_upgrade` | `true` | | Archive the Embedded Database before a tag change. No effect with an External Database. |
| `hindsight_backup_dir` | `/var/backups/hindsight` | | Directory for backup archives (mode `0700`). |
| `hindsight_backup_keep` | `3` | | Number of newest backup archives to keep. Must be at least 1. |
| `hindsight_prune_old_images` | `true` | | Remove the previous Hindsight image after a successful upgrade (Hindsight repository only). |

The role also validates these up front: ports are integers from 1 to 65535; the database URL starts with `postgresql://` or `postgres://`; the image tag is not empty; the host data path is absolute; with the `slim` variant, `HINDSIGHT_API_EMBEDDINGS_PROVIDER` must be set in `hindsight_extra_env` to a remote provider (not `local`).

`scripts/check-readme.sh` fails if a variable in `defaults/main.yml` is missing from this table, or if the example playbook below no longer passes `ansible-playbook --syntax-check`.

## Example playbook

Store the key in Ansible Vault. Create the encrypted value once:

```sh
ansible-vault encrypt_string --name vault_hindsight_llm_api_key 'sk-your-key'
ansible-vault encrypt_string --name vault_hindsight_cp_access_key 'a-long-random-string'
```

Put both outputs in `group_vars/memory/vault.yml`, then:

<!-- example-playbook -->
```yaml
---
- name: Install Hindsight
  hosts: memory
  become: true
  roles:
    - role: gruentee.hindsight
      vars:
        hindsight_llm_provider: openai
        hindsight_llm_model: gpt-4o-mini
        hindsight_llm_api_key: "{{ vault_hindsight_llm_api_key }}"
        hindsight_cp_access_key: "{{ vault_hindsight_cp_access_key }}"
        hindsight_image_tag: "1.0.0"
```
<!-- /example-playbook -->

Run it with `ansible-playbook -i inventory site.yml --ask-vault-pass`. With `hindsight_llm_provider: none` no key is needed. Check mode (`--check`) previews the changes and starts nothing.

## Upgrades

Change `hindsight_image_tag`. The role pulls the new image (only when it is absent locally; it never pulls "always"), stops the service, restarts it on the new image, and lets Hindsight run its database migrations at startup. With the Embedded Database it first archives the data to `hindsight_backup_dir` (see below). A downgrade fails unless `hindsight_allow_downgrade: true`. If the service is not ready after an upgrade, the play fails and names the backup path; there is no automatic rollback.

## Backups and manual restore

Before an upgrade (tag change) with the Embedded Database, the role stops the service and writes `hindsight-<UTC timestamp>-<old version>.tar` to `hindsight_backup_dir`, keeping the newest `hindsight_backup_keep` archives. The archive holds the contents of the data volume or of `hindsight_data_host_path`, with numeric owners. No backup is made with an External Database; back that up with your PostgreSQL tooling. Scheduled backups and automated restore are out of scope.

To restore on the Target Host as root (replace the archive name):

```sh
ls -l /var/backups/hindsight/                      # pick the archive
systemctl stop hindsight

# Named volume (default; hindsight_data_volume):
dir=$(podman volume mount hindsight-data)
find "$dir" -mindepth 1 -delete                    # clear the current data
tar --numeric-owner -C "$dir" -xpf /var/backups/hindsight/hindsight-20260101T000000Z-0.10.3.tar
podman volume unmount hindsight-data

# Host data path instead (hindsight_data_host_path):
dir=/srv/hindsight
find "$dir" -mindepth 1 -delete
tar --numeric-owner -C "$dir" -xpf /var/backups/hindsight/hindsight-20260101T000000Z-0.10.3.tar
```

The files must end up owned by `1000:1000`; `--numeric-owner` preserves that. Then run the old version again: set `hindsight_image_tag` to the version in the archive name, set `hindsight_allow_downgrade: true`, and run the role. Remove `hindsight_allow_downgrade` afterwards. Pinning the old tag matters: a newer image would migrate the restored data again.

## Warnings

- **Moving from local to external embeddings.** Switching `HINDSIGHT_API_EMBEDDINGS_PROVIDER` from `local` to an external provider may change the embedding model or its dimension and can leave stored vectors inconsistent. How Hindsight handles this is unverified. Test on a copy of the data first.
- **Switching image variants on a host with data.** Moving between `full` and `slim` is an ordinary tag change, but `slim` has no local embedding model and needs an external provider (see the warning above). Check what the new variant will do to the existing data, and take a backup, before switching a host that holds data.

## Contributing

Hooks are run with [prek](https://prek.j178.dev) and defined in `.pre-commit-config.yaml`:

```sh
scripts/install-lint-tool.sh   # builds the linter at the pinned commit (needs a Rust toolchain)
prek install                   # run the hooks on every commit
prek run --all-files           # run them once over the whole repository
```

The linter is [ansible-lint-but-fast](https://github.com/gruentee/ansible-lint-but-fast) at the `production` profile. It has no releases, so the commit to build is pinned in `.ansible-lint-but-fast-rev`. The installed binary is named `ansible-rust-lint`. The hooks also run `scripts/check-readme.sh`, which needs `ansible-playbook` on the PATH.
