#!/bin/sh

# Author:     Héctor Molinero Fernández <hector@molinero.xyz>
# Repository: https://github.com/hectorm/hmirror
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

adblockToHosts() {
	rules=$(printf -- '%s' "$1" \
		| tr -d '\r' \
		| tr '[:upper:]' '[:lower:]'
	)

	domainRegex='\([0-9a-z_-]\{1,63\}\.\)\{1,\}[a-z][0-9a-z_-]\{1,62\}'

	hostsPipe=$(mktemp -u)
	mkfifo -m 600 "$hostsPipe"
	printf -- '%s' "$rules" \
		| sed -n "s/^||\(${domainRegex}\)\^$/\1/p" \
		| sort | uniq \
	> "$hostsPipe" &

	exceptionsPipe=$(mktemp -u)
	mkfifo -m 600 "$exceptionsPipe"
	printf -- '%s' "$rules" \
		| sed -n "s/^@@||\(${domainRegex}\).*/\1/p" \
		| sort | uniq \
	> "$exceptionsPipe" &

	comm -23 "$hostsPipe" "$exceptionsPipe"
	rm -f "$hostsPipe" "$exceptionsPipe"
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
				content=$(adblockToHosts "$content")
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
