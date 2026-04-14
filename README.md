# ILM-Appliance-Tools
Debian package with ILM appliance tools.

## Content of etc/ilm-ansible

Is created as [git submodule](https://www.vogella.com/tutorials/GitSubmodules/article.html).

### First time initialization
```sh
cd appliance-tools
git submodule add -b develop https://github.com/OmniTrustILM/ansible-role-czertainly-branding.git etc/czertainly-ansible/roles/branding
git submodule add -b develop https://github.com/OmniTrustILM/ansible-role-http-proxy.git etc/czertainly-ansible/roles/http-proxy
git submodule add -b develop https://github.com/OmniTrustILM/ansible-role-postgres.git etc/czertainly-ansible/roles/postgres
git submodule add -b develop https://github.com/OmniTrustILM/ansible-role-helm.git etc/czertainly-ansible/roles/helm
git submodule add -b develop https://github.com/OmniTrustILM/ansible-role-rke2.git etc/czertainly-ansible/roles/rke2
git submodule add -b develop https://github.com/OmniTrustILM/ansible-role-czertainly.git etc/czertainly-ansible/roles/ilm
```

### Update after checkout
```sh
cd appliance-tools
git submodule update --init --recursive
```

### Update after changes in submodules
```sh
cd appliance-tools
git submodule foreach 'git pull origin; \
  git checkout develop; \
  git reset --hard origin/develop; \
  git submodule update --recursive; \
  git clean -dfx'
```

### Change to your fork of submodule repository:
```sh
git submodule set-url -- etc/ilm-ansible/roles/rke2 git@github.com:semik/ansible-role-rke2.git
```
Type exactly `etc/ilm-ansible/roles/rke2`, not `etc/ilm-ansible/roles/rke2/` &#128540;

### Check which files in `/etc/ilm-ansible/` have changed:
```sh
$ debsums -as ilm-appliance-tools 2>&1 |grep -v '\/etc\/ilm-ansible\/vars'
debsums: changed file /usr/bin/ilm-tui (from ilm-appliance-tools package)
debsums: changed file /etc/ilm-ansible/roles/ilm/tasks/main.yml (from ilm-appliance-tools package)
```

The directory `/etc/ilm-ansible/vars` is excluded because it is modified by user of the appliance.


## Building package

```sh
./build-deb.sh
```

Final deb file is moved to current directory to be accessible in
GitHub actions.

## GitHub action configuration

### Secrets

`DEB_REPO_KEY` - private key of the user on `DEB_REPO_HOST`

### Repository Variables

`DEB_REPO_HOST` - hostname of host where repository is installed

`DEB_REPO_USER` - username of user used for publishing Debian package on `DEB_REPO_HOST`

`DEB_REPO_DIRECTORY` - directory where to put a new package (`/var/www/deb.czertainly.com/incoming`)

`DEB_REPO_MANAGER` - script used for managing debian repositoy (`/var/www/deb.czertainly.com/manage-repository`)
