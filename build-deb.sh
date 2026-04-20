#!/bin/bash

# test if repository was correctly initialized, if no initialize
if [ ! -e etc/czertainly-ansible/roles/czertainly/tasks/main.yml ]
then
    git submodule update --init --recursive
fi

install='debian/install'
echo -n "Creating $install: "
(find ./etc -type f; find ./usr -type f) |\
    grep -v \~\$| grep -v \.git | grep -v \.travis > $install
echo "done."

cp -f LICENSE debian/copyright

dpkg-buildpackage -b -us -uc

name=`cat debian/files |grep \.deb | sed 's/ .*$//'`

# https://pmhahn.github.io/debian-oot-build/
echo "moving package file $name to current directory"
mv -f "../$name" .
ls -l *deb

