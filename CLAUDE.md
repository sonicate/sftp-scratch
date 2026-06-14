# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

`sftp-scratch` is a small Docker image providing a **throwaway SFTP server for
CI testing**. It is a clean reimplementation of the
[`atmoz/sftp`](https://github.com/atmoz/sftp) environment-variable / user-spec
interface, built on Alpine for fast CI pulls. There is no application code — the
whole project is a Dockerfile plus three shell scripts.

## Layout

| Path                       | Purpose |
| -------------------------- | ------- |
| `Dockerfile`               | Alpine base; installs `bash`, `openssh-server`, `shadow`. |
| `files/sshd_config`        | SFTP-only, chrooted, hardened sshd config. |
| `files/entrypoint`         | Merges user sources, ensures host keys, runs `/etc/sftp.d/` hooks, execs sshd. |
| `files/create-sftp-user`   | Parses one `user:pass[:e][:uid[:gid[:dir,...]]]` spec and provisions the account. |

## User-spec format (keep compatible with atmoz/sftp)

```
user:pass[:e][:uid[:gid[:dir1[,dir2]...]]]
```

Users come from three merged sources, resolved once on first container start:
1. Mounted file `/etc/sftp/users.conf` (legacy `/etc/sftp-users.conf` also read).
2. `SFTP_USERS` env var (space-separated specs).
3. Command-line args that contain a `:` (otherwise args are run as a command).

## Design constraints — don't break these

- **Chroot correctness:** `/home/<user>` must stay `root:root` and `0755`. Users
  write only into declared `dirN` subdirs or mounted volumes. `sshd` refuses to
  chroot into a directory the user can write to.
- **Alpine needs `shadow` + `bash`:** BusyBox's `useradd`/`usermod` and `ash`
  lack the options and bash regex/arrays the scripts depend on. Keep both
  packages if staying on Alpine.
- **Host keys are removed at build time** and (re)generated at runtime, so images
  never ship identical keys. Don't bake keys into the image.
- Scripts use `set -Eeo pipefail` with an `ERR` trap — preserve strict mode.

## Switching to a Debian base

If glibc/PAM compatibility is ever needed, swap `FROM alpine:3.21` for
`FROM debian:bookworm-slim`, replace `apk add --no-cache bash openssh-server
shadow` with an `apt-get install` of `openssh-server` (bash and the shadow tools
are already present), and keep everything else. The scripts are portable as-is.

## Testing changes locally

```bash
docker build -t sftp-scratch .
docker run --rm -p 2222:22 sftp-scratch ci:test:::upload
sftp -P 2222 ci@localhost     # password: test, then `put`/`get` in the upload dir
```

There is no automated test suite yet; verify by building and doing a real SFTP
round-trip (login, `put` into a writable dir, `get` it back).
