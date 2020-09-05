#!/bin/sh

# Author:     Héctor Molinero Fernández <hector@molinero.dev>
# Repository: https://github.com/hectorm/hmirror
# License:    MIT, https://opensource.org/licenses/MIT

set -eu
export LC_ALL=C

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

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
	curl -fsSL -A 'Mozilla/5.0 (X11; Linux x86_64; rv:78.0) Gecko/20100101 Firefox/78.0' -b 'geo_check=0' -- "${1:?}"
}

removeCRLF() { tr -d '\r'; }
toLowercase() { tr '[:upper:]' '[:lower:]'; }
removeComments() { sed -e "s/${1:?}.*//"; }
trimWhitespace() { sed -e 's/^[[:blank:]]*//' -e 's/[[:blank:]]*$//'; }

hostsToDomains() {
	ipRegex='\(0\.0\.0\.0\)\{0,1\}\(127\.0\.0\.1\)\{0,1\}'
	domainRegex='\([0-9a-z_-]\{1,63\}\.\)\{1,\}[a-z][0-9a-z_-]\{1,62\}'

	removeCRLF | toLowercase | removeComments '#' | trimWhitespace \
		| sed -n -e "/^\\(${ipRegex:?}[[:blank:]]\\{1,\\}\\)\\{0,1\\}${domainRegex:?}$/p" \
		| sed -e 's/^.\{1,\}[[:blank:]]\{1,\}//' \
		| sort | uniq
}

adblockToDomains() {
	domainRegex='\([0-9a-z_-]\{1,63\}\.\)\{1,\}[a-z][0-9a-z_-]\{1,62\}'

	contentFile=$(mktemp)
	removeCRLF | toLowercase > "${contentFile:?}"

	domainsPipe=$(mktemp -u)
	mkfifo -m 600 "${domainsPipe:?}" >/dev/null
	sed -n "s/^||\(${domainRegex:?}\)\^$/\1/p" "${contentFile:?}" | sort | uniq > "${domainsPipe:?}" &

	exceptionsPipe=$(mktemp -u)
	mkfifo -m 600 "${exceptionsPipe:?}" >/dev/null
	sed -n "s/^@@||\(${domainRegex:?}\).*/\1/p" "${contentFile:?}" | sort | uniq > "${exceptionsPipe:?}" &

	comm -23 "${domainsPipe:?}" "${exceptionsPipe:?}"
	rm -f "${contentFile:?}" "${domainsPipe:?}" "${exceptionsPipe:?}" >/dev/null
}

main() {
	sourceList=$(jq -r '.sources|map(select(.enabled))' "${SCRIPT_DIR:?}/sources.json")
	sourceCount=$(printf -- '%s' "${sourceList:?}" | jq -r '.|length-1')

	logAction 'Downloading lists...'

	for i in $(seq 0 "${sourceCount:?}"); do
		entry=$(printf -- '%s' "${sourceList:?}" | jq -r --arg i "${i:?}" '.[$i|tonumber]')
		name=$(printf -- '%s' "${entry:?}" | jq -r '.name')
		format=$(printf -- '%s' "${entry:?}" | jq -r '.format')
		url=$(printf -- '%s' "${entry:?}" | jq -r '.url')

		tmpFile=$(mktemp)
		listFile=${SCRIPT_DIR:?}/data/${name:?}/list.txt

		logInfo "${url:?}"
		fetchUrl "${url:?}" > "${tmpFile:?}" && exitCode=0 || exitCode=$?

		if [ "${exitCode:?}" -eq 0 ]; then
			mkdir -p "${listFile%/*}"

			if [ "${format:?}" = 'hosts' ]; then
				hostsToDomains < "${tmpFile:?}" > "${listFile:?}"
			elif [ "${format:?}" = 'adblock' ]; then
				adblockToDomains < "${tmpFile:?}" > "${listFile:?}"
			fi

			checksum=$(sha256sum "${listFile:?}" | cut -c 1-64)
			printf '%s  %s\n' "${checksum:?}" "${listFile##*/}" > "${listFile:?}.sha256"
		else
			logError 'Download failed'
		fi

		rm -f "${tmpFile:?}"
	done
}

main "$@"
