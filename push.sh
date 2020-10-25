#!/bin/sh

# Author:     Héctor Molinero Fernández <hector@molinero.dev>
# License:    MIT, https://opensource.org/licenses/MIT
# Repository: https://github.com/hectorm/hmirror

set -eu
export LC_ALL='C'

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${0:?}")" && pwd -P)"

main() {
	updatedSources="$(git ls-files --modified --other -- "${SCRIPT_DIR:?}/data/" | sed -ne 's|.*/\(.*\)/list\.txt$|* \1|p')"
	commitMsg="$(printf -- '%s\n%s' 'Updated sources:' "${updatedSources:?}")"

	git add "${SCRIPT_DIR:?}/data/"
	git commit -m "${commitMsg:?}"
	git push origin master
}

main "${@-}"
