# sftp-scratch

A tiny, throwaway **SFTP server** image for CI testing. It spins up an
SSH/SFTP daemon with chrooted users defined entirely through environment
variables or a mounted config file — no persistent state, no setup scripts in
your test harness.

The environment-variable and user-spec interface is intentionally compatible
with [`atmoz/sftp`](https://github.com/atmoz/sftp), so existing examples and CI
config translate directly. The image is built on `almalinux:9-minimal` — a
RHEL 9 userland that stays reasonably small for CI pulls (~40 MB compressed).

## Published image

CI builds multi-arch (`linux/amd64` + `linux/arm64`) images and publishes them
to GitHub Container Registry on every push to the default branch and on tags:

```bash
docker pull ghcr.io/sonicate/sftp-scratch:latest
```

## Quick start

```bash
docker build -t sftp-scratch .

# One user "ci" with password "test", writable upload dir, on port 2222.
docker run --rm -p 2222:22 sftp-scratch ci:test:::upload

# Connect:
sftp -P 2222 ci@localhost     # password: test
```

## Defining users

A user spec is a single colon-delimited string:

```
user:pass[:e][:uid[:gid[:dir1[,dir2]...]]]
```

| Field   | Meaning |
| ------- | ------- |
| `user`  | Username (required). |
| `pass`  | Password. Leave empty (`user::`) to disable password login and use keys. |
| `:e`    | Marks `pass` as already-encrypted (handed to `chpasswd -e`). |
| `uid`   | Optional numeric user id. |
| `gid`   | Optional numeric group id (a group is created if it does not exist). |
| `dirN`  | Comma-separated directories created **writable** under the user's home. |

Users are **chrooted to their home directory** (`/home/<user>`), which is owned
by root. Users can only write inside the `dirN` directories you declare or into
volumes you mount under their home.

### Three ways to supply users

All three sources are merged on first start.

**1. Command arguments**

```bash
docker run -p 2222:22 sftp-scratch foo:pass:::upload bar:pass:1001
```

**2. `SFTP_USERS` environment variable** (space-separated specs)

```bash
docker run -p 2222:22 -e SFTP_USERS="foo:pass:::upload bar:pass:1001" sftp-scratch
```

**3. Mounted config file** at `/etc/sftp/users.conf` (one spec per line, `#` comments)

```bash
docker run -p 2222:22 -v "$PWD/users.conf:/etc/sftp/users.conf:ro" sftp-scratch
```

## Common recipes

**Public-key auth** — mount keys into `/home/<user>/.ssh/keys/`; they are
appended to `authorized_keys` at startup:

```bash
docker run -p 2222:22 \
  -v "$PWD/id_ed25519.pub:/home/ci/.ssh/keys/id_ed25519.pub:ro" \
  sftp-scratch ci::
```

**Persist / inspect uploaded files** — mount a host dir into the user's home:

```bash
docker run -p 2222:22 \
  -v "$PWD/data:/home/ci/upload" \
  sftp-scratch ci:test:::upload
```

**Stable host fingerprint across runs** — mount your own host keys:

```bash
docker run -p 2222:22 \
  -v "$PWD/ssh_host_ed25519_key:/etc/ssh/ssh_host_ed25519_key" \
  sftp-scratch ci:test
```

**Startup hooks** — executables placed in `/etc/sftp.d/` run before sshd starts
(useful for custom bind mounts; requires `--cap-add SYS_ADMIN`).

## CI example (GitHub Actions service container)

```yaml
services:
  sftp:
    image: sftp-scratch
    ports:
      - 2222:22
    env:
      SFTP_USERS: "ci:test:::upload"
```

## Notes

- Host keys are generated on first start unless mounted, so each container has a
  unique fingerprint by default — fine for ephemeral CI.
- There is no persistence: users and uploads live only for the container's
  lifetime unless you mount volumes.
