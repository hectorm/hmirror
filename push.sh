#!/bin/sh

# Author:     Héctor Molinero Fernández <hector@molinero.dev>
# License:    MIT, https://opensource.org/licenses/MIT
# Repository: https://github.com/hectorm/hmirror

set -eu
export LC_ALL='C'

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${0:?}")" && pwd -P)"

main() {
	updatedSources="$(git status --porcelain=v1 -- "${SCRIPT_DIR:?}/data/" | awk -F'/' '{printf("* %s\n",$2)}' | sort | uniq)"
	if [ -n "${updatedSources?}" ]; then
		commitMsg="$(printf '%s\n%s' 'Updated sources:' "${updatedSources:?}")"
		git add -- "${SCRIPT_DIR:?}/data/"
		git commit -m "${commitMsg:?}"
		git push origin HEAD
	fi
}

main "${@-}"
