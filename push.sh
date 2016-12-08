#!/bin/sh

# Author:     Héctor Molinero Fernández <hector@molinero.xyz>
# Repository: https://github.com/zant95/hMirror
# License:    MIT, https://opensource.org/licenses/MIT

# Exit on errors
set -eu

# Globals
export LC_ALL=C

# Process
main() {
	username="$1"
	password="$2"
	shift 2

	git add ./data
	git commit -m 'Update sources'
	git push "https://${username}:${password}@github.com/zant95/hMirror.git" master
}

main "$@"

