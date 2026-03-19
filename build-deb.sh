#!/bin/bash

# test if repository was correctly initialized, if no initialize
if [ ! -e etc/czertainly-ansible/roles/czertainly/tasks/main.yml ]
then
    git submodule update --init --recursive
fi

install='debian/ilm-appliance-tools.install'
echo -n "Creating $install: "
(find ./etc -type f; find ./usr \( -type f -o -type l \)) |\
    grep -v \~\$| grep -v \.git | grep -v \.travis > $install
echo "done."

cp -f LICENSE debian/copyright

dpkg-buildpackage -b -us -uc

# https://pmhahn.github.io/debian-oot-build/
for name in `cat debian/files | grep \.deb | sed 's/ .*$//'`; do
    echo "moving package file $name to current directory"
    mv -f "../$name" .
done
ls -l *deb

