#!/bin/sh

# Author:     Héctor Molinero Fernández <hector@molinero.dev>
# Repository: https://github.com/hectorm/hmirror
# License:    MIT, https://opensource.org/licenses/MIT

set -eu
export LC_ALL=C

scriptDir=$(dirname "$(readlink -f "$0")")

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
	curl -fsSL -A 'Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/60.0' -- "$@"
}

removeCRLF() { tr -d '\r'; }
toLowercase() { tr '[:upper:]' '[:lower:]'; }
removeComments() { sed -e 's/#.*//'; }
trimWhitespace() { sed -e 's/^[[:blank:]]*//' -e 's/[[:blank:]]*$//'; }

hostsToDomains() {
	content="$1"
	shift 1

	ipRegex='\(0\.0\.0\.0\)\{0,1\}\(127\.0\.0\.1\)\{0,1\}'
	domainRegex='\([0-9a-z_-]\{1,63\}\.\)\{1,\}[a-z][0-9a-z_-]\{1,62\}'
	printf -- '%s' "${content}" \
		| removeCRLF | toLowercase | removeComments | trimWhitespace \
		| sed -n -e "/^\\(${ipRegex}[[:blank:]]\\{1,\\}\\)\\{0,1\\}${domainRegex}$/p" \
		| sed -e 's/^.\{1,\}[[:blank:]]\{1,\}//' \
		| sort | uniq
}

adblockToDomains() {
	content="$1"
	shift 1

	content=$(printf -- '%s' "${content}" | removeCRLF | toLowercase)

	domainsPipe=$(mktemp -u); mkfifo -m 600 "${domainsPipe}"
	exceptionsPipe=$(mktemp -u); mkfifo -m 600 "${exceptionsPipe}"

	domainRegex='\([0-9a-z_-]\{1,63\}\.\)\{1,\}[a-z][0-9a-z_-]\{1,62\}'

	printf -- '%s' "${content}" \
		| sed -n "s/^||\(${domainRegex}\)\^$/\1/p" \
		| sort | uniq \
	> "${domainsPipe}" &

	printf -- '%s' "${content}" \
		| sed -n "s/^@@||\(${domainRegex}\).*/\1/p" \
		| sort | uniq \
	> "${exceptionsPipe}" &

	comm -23 "${domainsPipe}" "${exceptionsPipe}"
	rm -f "${domainsPipe}" "${exceptionsPipe}"
}

main() {
	sourceList=$(jq -r '.sources|map(select(.enabled))' "${scriptDir}/sources.json")
	sourceCount=$(printf -- '%s' "${sourceList}" | jq -r '.|length-1')

	logAction 'Downloading lists...'

	for i in $(seq 0 "${sourceCount}"); do
		entry=$(printf -- '%s' "${sourceList}" | jq -r --arg i "${i}" '.[$i|tonumber]')
		name=$(printf -- '%s' "${entry}" | jq -r '.name')
		format=$(printf -- '%s' "${entry}" | jq -r '.format')
		url=$(printf -- '%s' "${entry}" | jq -r '.url')

		logInfo "${url}"
		content=$(fetchUrl "${url}") || true

		if [ -n "${content}" ]; then
			mkdir -p -- "${scriptDir}/data/${name}"
			cd -- "${scriptDir}/data/${name}"

			if [ "${format}" = 'hosts' ]; then
				content=$(hostsToDomains "${content}")
			elif [ "${format}" = 'adblock' ]; then
				content=$(adblockToDomains "${content}")
			fi

			printf -- '%s\n' "${content}" > list.txt
			sha256sum list.txt > list.txt.sha256
		else
			logError 'Download failed'
		fi

		unset content
	done
}

main "$@"
