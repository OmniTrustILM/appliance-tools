#!/bin/bash
# Verify that no submodule points at a personal fork, and that every commit a
# submodule is pinned to really exists in the repository the submodule names.
#
# Run it before opening a pull request:
#
#     ./.github/verify-submodules.sh
#
# The rules, in the order they are reported:
#
#   1. the URL is https - git@github.com: cannot be cloned by the CI runner,
#      which has no ssh key, nor by anyone without a github account,
#   2. the host is github.com,
#   3. the owner is OmniTrustILM or the owner of this repository. The second
#      one is what lets a fork develop against its own roles; a pull request
#      is checked in the context of the repository it targets, so a request
#      into OmniTrustILM is judged by OmniTrustILM's rules,
#   4. the pinned commit exists in that repository. A URL can name the right
#      repository while the commit lives only in a fork, and then every clone
#      of the release is broken - this is the case the URL alone cannot see.
#
# Only the last rule needs the network, and it reads the role repositories
# anonymously - no token, no ssh key.
#
# $REPO_OWNER overrides the owner of this repository (the workflow passes
# github.repository_owner), $GITMODULES the file to read.

set -u

UPSTREAM_OWNER=OmniTrustILM
GITMODULES=${GITMODULES:-.gitmodules}

cd "$(git rev-parse --show-toplevel)" || exit 2

# A github URL in either form, to "host owner repo":
#
#   https://github.com/OmniTrustILM/ansible-role-rke2.git
#   git@github.com:semik/ansible-role-rke2.git
#
# The scheme goes first, so the only colon left is the one of the scp-like
# ssh form and can be turned into a slash.
splitUrl() {
	printf '%s\n' "$1" |
		sed -E 's,^[a-z][a-z0-9+.-]*://,,; s,^[^/@]+@,,; s,:,/,; s,\.git$,,; s,/+$,,' |
		tr '/' ' '
}

urlScheme() {
	printf '%s\n' "$1" | sed -nE 's,^([a-z][a-z0-9+.-]*)://.*,\1,p'
}

if [ -z "${REPO_OWNER:-}" ]
then
	# shellcheck disable=SC2046  # the three fields are wanted separately
	set -- $(splitUrl "$(git config --get remote.origin.url)")
	REPO_OWNER=${2:-}
fi

if [ -z "$REPO_OWNER" ]
then
	echo "cannot tell who owns this repository, set \$REPO_OWNER" >&2
	exit 2
fi

if [ ! -f "$GITMODULES" ]
then
	echo "no $GITMODULES, nothing to verify"
	exit 0
fi

# Throwaway repositories for the lookups, so that neither a developer's object
# store nor the CI checkout gets objects it did not ask for.
probe=$(mktemp -d) || exit 2
trap 'rm -rf "$probe"' EXIT

# Can $2 be reached from a branch or a tag of the repository at $1?
# 0 yes, 1 no, 2 the repository could not be read.
#
# Not "git fetch <url> <sha>", which looks like the obvious way to ask: github
# serves a whole fork network out of one object store, so fetching a bare sha
# from the upstream URL succeeds even for a commit that only ever existed in a
# fork - which is exactly the case this rule is here to catch. Fetching the
# refs transfers only what they reach, so the object arrives if and only if the
# commit really is published in that repository.
#
# Each repository gets its own directory as well, or objects pulled from a fork
# would answer for the upstream one.
commitReachable() {
	local dir
	dir=$(mktemp -d -p "$probe") || return 2
	git init --quiet --bare "$dir" || return 2

	GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes' \
		git -C "$dir" fetch --quiet "$1" \
			'+refs/heads/*:refs/heads/*' '+refs/tags/*:refs/tags/*' 2>/dev/null ||
		return 2

	git -C "$dir" cat-file -e "$2^{commit}" 2>/dev/null
}

# On the official repository the two are the same, and saying so twice reads
# like a bug.
if [ "$REPO_OWNER" = "$UPSTREAM_OWNER" ]
then
	allowed=$UPSTREAM_OWNER
else
	allowed="$UPSTREAM_OWNER or $REPO_OWNER"
fi

echo "allowed owner: $allowed"
echo

failed=0

while read -r key path
do
	name=${key#submodule.}
	name=${name%.path}
	url=$(git config --file "$GITMODULES" --get "submodule.$name.url")

	# shellcheck disable=SC2046  # the three fields are wanted separately
	set -- $(splitUrl "$url")
	host=${1:-}
	owner=${2:-}
	repo=${3:-}

	sha=$(git rev-parse --verify --quiet "HEAD:$path" 2>/dev/null)

	reason=''
	if [ "$(urlScheme "$url")" != 'https' ]
	then
		reason="not an https URL, the CI runner and anonymous clones cannot use it"
	elif [ "$host" != 'github.com' ]
	then
		reason="unexpected host '$host'"
	elif [ "$owner" != "$UPSTREAM_OWNER" ] && [ "$owner" != "$REPO_OWNER" ]
	then
		reason="owned by '$owner', not by $allowed"
	elif [ -z "$sha" ]
	then
		reason="no commit recorded for this path in HEAD"
	else
		commitReachable "$url" "$sha"
		case $? in
		0) ;;
		2) reason="cannot read $owner/$repo, is it private or misspelled?" ;;
		*) reason="commit $sha is on no branch or tag of $owner/$repo" ;;
		esac
	fi

	if [ "$reason" = '' ]
	then
		printf 'ok    %-40s %s %s\n' "$path" "${sha:0:7}" "$owner/$repo"
	else
		printf 'FAIL  %-40s %s %s\n      %s\n' \
			"$path" "${sha:0:7}" "$url" "$reason"
		failed=$((failed + 1))
	fi
done < <(git config --file "$GITMODULES" --get-regexp '^submodule\..*\.path$')

echo
if [ $failed -eq 0 ]
then
	echo "All submodules come from an allowed repository and are pinned to a commit that is there."
	exit 0
fi

echo "$failed submodule(s) above would break a clone of this branch.

Point them back at the official repositories with

    ./switch-submodule-fork.sh upstream

A commit that is 'not in' its repository is a role change that has not been
pushed there yet - push it, or leave the submodule pointing at the fork that
does have it until it is merged."
exit 1
