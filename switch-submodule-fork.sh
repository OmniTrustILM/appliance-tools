#!/bin/bash
# Switch the ansible-role git submodules between the official OmniTrustILM
# repositories and a personal fork.
#
#   ./switch-submodule-fork.sh fork          # -> https://github.com/semik/ansible-role-*.git
#   ./switch-submodule-fork.sh upstream      # -> https://github.com/OmniTrustILM/ansible-role-*.git
#   ./switch-submodule-fork.sh status        # show what is configured right now
#
# Both are https, because that is what the CI runner and anyone without a
# github account can clone, and .github/verify-submodules.sh refuses anything
# else. To push to your fork over ssh anyway, put this in ~/.gitconfig once:
#
#   [url "git@github.com:"]
#           pushInsteadOf = https://github.com/
#
# Fetching then uses the https URL as recorded here, while every push is
# rewritten to ssh and goes out over your key. It changes the transport only,
# not the owner - pushing to your fork still means switching to 'fork' first.
#
# Optional: restrict to some submodules, use a different fork owner, dry run:
#   ./switch-submodule-fork.sh fork rke2 helm
#   ./switch-submodule-fork.sh -u someuser fork
#   ./switch-submodule-fork.sh -n fork
#
# Note: the URLs live in .gitmodules, which is tracked by git, so switching to
# your fork shows up as a local modification. Don't commit it - run
# "./switch-submodule-fork.sh upstream" (or "git checkout -- .gitmodules") first.

set -euo pipefail

UPSTREAM_OWNER=OmniTrustILM
FORK_OWNER=${FORK_OWNER:-semik}
DRY_RUN=no

usage() {
	awk 'NR > 1 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "$0"
	exit "${1:-0}"
}

while getopts ':u:nh' opt; do
	case $opt in
	u) FORK_OWNER=$OPTARG ;;
	n) DRY_RUN=yes ;;
	h) usage 0 ;;
	*) echo "unknown option -$OPTARG" >&2; usage 1 ;;
	esac
done
shift $((OPTIND - 1))

[ $# -ge 1 ] || usage 1
MODE=$1
shift

cd "$(git rev-parse --show-toplevel)"

# All submodule paths, optionally filtered by the names given on the command
# line (matched against the last path component, e.g. "rke2").
list_paths() {
	local path want
	while read -r path; do
		if [ $# -eq 0 ]; then
			echo "$path"
		else
			for want in "$@"; do
				if [ "${path##*/}" = "$want" ]; then
					echo "$path"
				fi
			done
		fi
	done < <(git config --file .gitmodules --get-regexp '^submodule\..*\.path$' | cut -d' ' -f2-)
	return 0
}

run() {
	if [ "$DRY_RUN" = yes ]; then
		echo "  would run: $*"
	else
		"$@"
	fi
}

paths=$(list_paths "$@")
if [ -z "$paths" ]; then
	echo "no matching submodules found" >&2
	exit 1
fi

changed=no

while read -r path; do
	url=$(git config --file .gitmodules --get "submodule.$path.url")
	repo=${url##*/}       # ansible-role-rke2.git
	repo=${repo%.git}     # ansible-role-rke2

	case $MODE in
	status)
		printf '%-40s %s\n' "$path" "$url"
		continue
		;;
	fork)
		new="https://github.com/$FORK_OWNER/$repo.git"
		;;
	upstream)
		new="https://github.com/$UPSTREAM_OWNER/$repo.git"
		;;
	*)
		echo "unknown mode '$MODE' (expected fork, upstream or status)" >&2
		exit 1
		;;
	esac

	if [ "$url" = "$new" ]; then
		echo "$path: already $new"
		continue
	fi

	echo "$path: $url -> $new"
	run git submodule set-url -- "$path" "$new"
	changed=yes
done <<<"$paths"

if [ "$changed" = yes ]; then
	# set-url only rewrites .gitmodules; sync pushes the new URL into
	# .git/config and into each submodule's "origin" remote.
	run git submodule sync -- $paths
	echo
	if [ "$MODE" = fork ]; then
		echo "done - .gitmodules is now modified locally, do not commit it"
	else
		echo "done - check 'git diff .gitmodules' is empty before committing"
	fi
	echo "
Run ./.github/verify-submodules.sh now: a fork does not necessarily carry the
commit a submodule is pinned to, and pointing at one that does not break
every clone."
fi
