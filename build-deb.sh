#!/bin/bash

# test if repository was correctly initialized, if no initialize
if [ ! -e etc/ilm-ansible/roles/ilm/tasks/main.yml ]
then
    git submodule update --init --recursive
fi

# Debian trixie ships kubernetes.core 6.1.0 (inside ansible 12.0.0) and a
# stable release never gets a newer collection. That version predates Helm 4:
# it passes the Helm 3 only "--all" flag to "helm list", so every helm task
# fails with "unknown flag: --all" as soon as Helm 4 is installed. Helm 3 gets
# its final feature release on 2026-09-09 and security fixes only until
# 2026-02-10, so the appliance carries its own collection instead.
# /etc/ilm-ansible/ansible.cfg puts this directory first on collections_path.
#
# Plain tar on purpose: the GitHub builder installs only debhelper, dpkg-dev
# and build-essential, there is no ansible-galaxy there. Refresh the tarball
# with the command in vendor/README.md.
kubernetes_core_version='6.5.0'
collections='usr/share/ilm-ansible/collections'
tarball="vendor/kubernetes-core-${kubernetes_core_version}.tar.gz"
target="$collections/ansible_collections/kubernetes/core"

echo -n "Vendoring kubernetes.core $kubernetes_core_version: "
if [ ! -f "$tarball" ]
then
    echo "FAILED"
    echo "$tarball is missing, fetch it once with:"
    echo "  ansible-galaxy collection download kubernetes.core:${kubernetes_core_version} -p vendor/"
    exit 1
fi
rm -rf "$collections"
mkdir -p "$target"
tar -xzf "$tarball" -C "$target"
# Of no use on an appliance, and it is the bulk of the tarball.
rm -rf "$target/tests" "$target/docs" "$target/changelogs"
echo "done."

install='debian/ilm-appliance-tools.install'
echo -n "Creating $install: "
# Editor backups, __pycache__ left behind by running one of the scripts, and
# anything in a dot directory or dot file are development leftovers of the role
# submodules (.git, .github, .travis.yml, .ansible, .claude, .yamllint, ...),
# they have no business in the package - and every file under /etc becomes a
# conffile, so shipping one means carrying it forever.
(find ./etc -type f; find ./usr \( -type f -o -type l \)) |\
    grep -vE '~$|/\.|/__pycache__/' > $install
echo "done."

cp -f LICENSE debian/copyright

dpkg-buildpackage -b -us -uc

# https://pmhahn.github.io/debian-oot-build/
for name in `cat debian/files | grep \.deb | sed 's/ .*$//'`; do
    echo "moving package file $name to current directory"
    mv -f "../$name" .
done
ls -l *deb
