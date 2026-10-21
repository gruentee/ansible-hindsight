# Test the role with Molecule and nested rootful Podman

Status: accepted (spike #10)

## Decision

**Go.** Molecule's `docker` driver boots a privileged systemd container per distribution, and the role runs rootful Podman inside it. The delegated-driver fallback (CI runner, Ubuntu only) is not needed.

## Evidence

`molecule test -s spike` passes on Ubuntu 26.04 (create, converge, idempotence, verify, destroy). The scenario lives in `molecule/spike/`.

- **Outer container**: `privileged: true`, `cgroupns_mode: host`, `/sys/fs/cgroup` mounted rw, `/run` and `/tmp` as tmpfs, command `/lib/systemd/systemd`. The stock `ubuntu:26.04` image has no systemd, so `Dockerfile.j2` installs `systemd`, `systemd-sysv` and `python3`.
- **Storage driver**: nested Podman 5.7.0 picks `overlay` by itself, with no `storage.conf` changes and no `fuse-overlayfs`. This relied on the outer Docker using the overlayfs snapshotter (Docker 29.9, cgroup v2). Podman reports "Native Overlay Diff: false", so layer diffs are slower than on bare metal, but pulls and runs work.
- **Disk**: `ghcr.io/vectorize-io/hindsight:latest` is 2.63 GB under nested Podman (`du` of `/var/lib/containers/storage`: 2.6 GB). Budget about 3 GB per Target Host for the image, plus Hindsight data. The outer container gets that from its writable layer, so a heavy CI job running several distributions in parallel needs several GB each.

## Consequences

- Later scenarios copy the `platforms` block of `molecule/spike/molecule.yml` and swap the image.
- Not yet checked: Debian 12 and EL 9 as the outer container (ticket #16), and an outer Docker that does not use the overlayfs snapshotter (the Podman storage driver may differ there).
- Molecule is installed with `uv tool install molecule --with "molecule-plugins[docker]"`.
- The 2.63 GB figure is for the `latest` tag (assumed to be the full variant). The pinned tag and the `slim` variant were not measured, so the role's `hindsight_min_free_disk_mb` defaults are not yet backed by this spike (ticket #18).
- The scenario pulls `alpine:3` from Docker Hub, so a run needs network access and can hit rate limits.
