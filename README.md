# ILM-Appliance-Tools
Debian package with ILM appliance tools.

## Content of etc/ilm-ansible

Is created as [git submodule](https://www.vogella.com/tutorials/GitSubmodules/article.html).

### First time initialization
```sh
cd appliance-tools
git submodule add -b develop https://github.com/OmniTrustILM/ansible-role-ilm-branding.git etc/ilm-ansible/roles/branding
git submodule add -b develop https://github.com/OmniTrustILM/ansible-role-http-proxy.git etc/ilm-ansible/roles/http-proxy
git submodule add -b develop https://github.com/OmniTrustILM/ansible-role-postgres.git etc/ilm-ansible/roles/postgres
git submodule add -b develop https://github.com/OmniTrustILM/ansible-role-helm.git etc/ilm-ansible/roles/helm
git submodule add -b develop https://github.com/OmniTrustILM/ansible-role-rke2.git etc/ilm-ansible/roles/rke2
git submodule add -b develop https://github.com/OmniTrustILM/ansible-role-ilm.git etc/ilm-ansible/roles/ilm
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
./switch-submodule-fork.sh fork rke2       # -> https://github.com/semik/ansible-role-rke2.git
./switch-submodule-fork.sh upstream        # all of them back to OmniTrustILM
./switch-submodule-fork.sh status          # what is configured right now
```
Under the hood that is `git submodule set-url`, where the path has to be typed
exactly as `etc/ilm-ansible/roles/rke2`, not `etc/ilm-ansible/roles/rke2/` &#128540;

The URL has to stay `https://`: that is what the CI runner and anyone without a
github account can clone. To push to your fork over ssh anyway, put this in
`~/.gitconfig` once:
```ini
[url "git@github.com:"]
	pushInsteadOf = https://github.com/
```
Fetching then uses the `https` URL as recorded in `.gitmodules`, while every
push is rewritten to ssh and goes out over your key. It changes the transport
only, not the owner, so pushing to your fork still means switching to it first.

### Check the submodules before opening a pull request:
```sh
./.github/verify-submodules.sh
```
This is what the `verify-pr` workflow runs. It reports any submodule that is
not on `https://github.com/`, that belongs to neither OmniTrustILM nor the
owner of this repository, or whose pinned commit is on no branch or tag of the
repository it names - the last one being how a fork leaks into a release
without the URL showing it.

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
