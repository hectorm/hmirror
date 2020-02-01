#!/bin/sh

# Author:     Héctor Molinero Fernández <hector@molinero.dev>
# Repository: https://github.com/hectorm/hmirror
# License:    MIT, https://opensource.org/licenses/MIT

set -eu
export LC_ALL=C

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

main() {
	username=${1:?}
	password=${2:?}
	shift 2

	updatedSources=$(git ls-files --modified --other "${SCRIPT_DIR:?}"/data/ | sed -n 's|.*/\(.*\)/list\.txt$|* \1|p')
	commitMsg=$(printf -- '%s\n%s' 'Updated sources:' "${updatedSources:?}")

	git add "${SCRIPT_DIR:?}"/data/
	git commit -m "${commitMsg:?}"
	git push "https://${username:?}:${password:?}@github.com/hectorm/hmirror.git" master
}

main "$@"
