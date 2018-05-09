#!/bin/sh

# Author:     Héctor Molinero Fernández <hector@molinero.xyz>
# Repository: https://github.com/zant95/hMirror
# License:    MIT, https://opensource.org/licenses/MIT

set -eu
export LC_ALL=C

scriptDir=$(dirname "$(readlink -f "$0")")

# Methods
logInfo() {
	printf -- '   - %s\n' "$@"
}

logAction() {
	printf -- '\033[1;33m + \033[1;32m%s \033[0m\n' "$@"
}

logError() {
	>&2 printf -- '\033[1;33m + \033[1;31m%s \033[0m\n' "$@"
}

fetchUrl() {
	curl -fsSL -A 'Mozilla/5.0 (X11; Linux x86_64; rv:52.0) Gecko/20100101 Firefox/52.0' -- "$@"
}

adblockToPlain() {
	# shellcheck disable=SC2016
	printf -- '%s' "$1" | \
		tr -d '\r' | tr '[:upper:]' '[:lower:]' | \
		grep -oP '(?<=^\|\|)(?:[0-9a-z_-]{1,63}\.){1,}[a-z][0-9a-z_-]{1,62}(?=\^(?:$|\$(?:(?!domain=).)*$))' | \
		sort -u
}

main() {
	sourceList=$(jq -c '.sources|map(select(.enabled))' "$scriptDir/sources.json")
	sourceCount=$(printf -- '%s' "$sourceList" | jq '.|length-1')

	logAction 'Downloading lists...'

	for i in $(seq 0 "$sourceCount"); do
		entry=$(printf -- '%s' "$sourceList" | jq ".[$i]")
		name=$(printf -- '%s' "$entry" | jq -r '.name')
		format=$(printf -- '%s' "$entry" | jq -r '.format')
		url=$(printf -- '%s' "$entry" | jq -r '.url')

		logInfo "$url"
		content=$(fetchUrl "$url") || true

		if [ -n "$content" ]; then
			mkdir -p -- "$scriptDir/data/$name"
			cd -- "$scriptDir/data/$name"

			if [ "$format" = 'adblock' ]; then
				content=$(adblockToPlain "$content")
			fi

			printf -- '%s\n' "$content" > list.txt
			sha256sum list.txt > list.txt.sha256
		else
			logError 'Download failed'
		fi

		unset content
	done
}

main
