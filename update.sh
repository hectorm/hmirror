#!/bin/sh

# Author:     Héctor Molinero Fernández <hector@molinero.xyz>
# Repository: https://github.com/zant95/hMirror
# License:    MIT, https://opensource.org/licenses/MIT

set -eu
export LC_ALL=C

# Methods
printInfo() {
	printf -- '   - %s\n' "$@"
}

printAction() {
	printf -- '\033[1;33m + \033[1;32m%s \033[0m\n' "$@"
}

printError() {
	>&2 printf -- '\033[1;33m + \033[1;31m%s \033[0m\n' "$@"
}

fetchUrl() {
	curl -fsSL -A 'Mozilla/5.0 (X11; Linux x86_64; rv:45.0) Gecko/20100101 Firefox/45.0' -- "$@"
}

adblockToPlain() {
	domainRegex='([0-9a-z_-]{1,63}\.){1,}[a-z][0-9a-z_-]{1,62}'
	filterOptionsRegex='(third-party|popup|subdocument|websocket)'
	filterSkipRegex='(?!domain=)'
	printf -- '%s' "$1" | \
		grep -oP "(?<=^\\|\\|)${domainRegex}(?=\\^((?=\\\$(.+,)?${filterOptionsRegex}(,|$))${filterSkipRegex}|$))" | \
		sort -u
}

main() {
	sourceList=$(jq -c '.sources|map(select(.enabled))' sources.json)
	sourceCount=$(printf -- '%s' "$sourceList" | jq '.|length-1')

	printAction 'Downloading lists...'
	mkdir -p ./data && cd ./data

	for i in $(seq 0 "$sourceCount"); do
		entry=$(printf -- '%s' "$sourceList" | jq ".[$i]")
		name=$(printf -- '%s' "$entry" | jq -r '.name')
		format=$(printf -- '%s' "$entry" | jq -r '.format')
		url=$(printf -- '%s' "$entry" | jq -r '.url')

		printInfo "$url"
		content=$(fetchUrl "$url") || true

		if [ -n "$content" ]; then
			rm -rf "$name" && mkdir "$name" && cd "$name"

			if [ "$format" = 'adblock' ]; then
				content=$(adblockToPlain "$content")
			fi

			printf -- '%s\n' "$content" > list.txt
			sha256sum list.txt > list.txt.sha256

			cd ..
		else
			printError 'Download failed'
		fi

		unset entry name url content
	done
}

main
