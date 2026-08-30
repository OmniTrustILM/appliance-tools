# Vendored Ansible collections

`build-deb.sh` unpacks the tarballs from this directory into
`usr/share/ilm-ansible/collections`, which
`etc/ilm-ansible/ansible.cfg` puts first on `collections_path`.

Only this README is committed. The tarballs are downloaded straight from
galaxy by `build-deb.sh` and this directory is the cache, so the first build of
a checkout needs the network and the ones after it do not. What makes that
safe is the `kubernetes_core_sha256` pin in `build-deb.sh`, checked on every
build - a cached tarball is verified exactly like a freshly downloaded one.

`ansible-galaxy` is deliberately not used: the GitHub builder installs only
`debhelper`, `dpkg-dev` and `build-essential`, so the download is a plain
`curl` of the published artifact.

## kubernetes.core

Debian trixie ships `kubernetes.core` 6.1.0 as part of `ansible` 12.0.0, and a
stable release never receives a newer collection. 6.1.0 speaks Helm 3 only -
it appends `--all` to `helm list`, a flag Helm 4 removed, so every task using
`kubernetes.core.helm` fails with `unknown flag: --all` on an appliance that
has Helm 4 installed. Helm 3 reaches its final feature release on 2026-09-09
and stops receiving security fixes on 2027-02-10, so the appliance cannot stay
on it.

Helm 4 support arrived upstream in two steps:

| version | change |
|---|---|
| 6.3.0 | refuses Helm >= 4.0.0 outright |
| 6.4.0 | Helm v4 compatibility across the helm_* modules |
| 6.5.0 | `helm` module itself: `--force` becomes `--server-side=false --force-replace`, `--atomic` becomes `--rollback-on-failure`, new `server_side` and `force_conflicts` options |

6.5.0 requires `ansible-core >= 2.16.0`, trixie has 2.19.4.

### Moving to a newer version

Set `kubernetes_core_version` in `build-deb.sh`, then get the checksum of the
new artifact:

```
v=6.6.0
curl -fsSL https://galaxy.ansible.com/api/v3/plugin/ansible/content/published/collections/artifacts/kubernetes-core-$v.tar.gz |
    sha256sum
```

and put it in `kubernetes_core_sha256` next to it. Running `./build-deb.sh`
without that second step is harmless - it downloads the new tarball, refuses
it, and prints both the expected and the found checksum. Nothing is added to
git; the old tarball can be deleted from `vendor/` or left there, as it is
ignored either way.

### Verifying on an appliance

```
cd /etc/ilm-ansible
ansible-galaxy collection list kubernetes.core
```

The vendored path must be listed first, with the version from
`build-deb.sh`. Python side: the collection needs `kubernetes >= 24.2.0`,
provided by the `python3-kubernetes` package which the rke2 role installs.
