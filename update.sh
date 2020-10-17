#!/bin/sh

# Author:     Héctor Molinero Fernández <hector@molinero.dev>
# License:    MIT, https://opensource.org/licenses/MIT
# Repository: https://github.com/hectorm/hmirror

set -eu
export LC_ALL='C'

SCRIPT_DIR="$(dirname "$(readlink -f "${0:?}")")"

printInfo() { [ -t 1 ] && printf -- '\033[0m[\033[1;32mINFO\033[0m] %s\n' "${@}" || printf -- '[INFO] %s\n' "${@}"; }
printWarn() { [ -t 1 ] && printf -- '\033[0m[\033[1;33mWARN\033[0m] %s\n' "${@}" >&2 || printf -- '[WARN] %s\n' "${@}" >&2; }
printError() { [ -t 1 ] && printf -- '\033[0m[\033[1;31mERROR\033[0m] %s\n' "${@}" >&2 || printf -- '[ERROR] %s\n' "${@}" >&2; }
printList() { [ -t 1 ] && printf -- '\033[0m \033[1;36m*\033[0m %s\n' "${@}" || printf -- ' * %s\n' "${@}" >&2; }

fetchUrl() { curl -fsSL -A 'Mozilla/5.0 (X11; Linux x86_64; rv:78.0) Gecko/20100101 Firefox/78.0' -- "${1:?}"; }

removeCRLF() { tr -d '\r'; }
toLowercase() { tr '[:upper:]' '[:lower:]'; }
removeComments() { sed -e "s/${1:?}.*//"; }
trimWhitespace() { sed -e 's/^[[:blank:]]*//' -e 's/[[:blank:]]*$//'; }

hostsToDomains() {
	ipv4Regex='\(0\.0\.0\.0\)\{0,1\}\(127\.0\.0\.1\)\{0,1\}'
	ipv6Regex='\(::\)\{0,1\}\(::1\)\{0,1\}'
	ipRegex="${ipv4Regex:?}${ipv6Regex:?}"
	domainRegex='\([0-9a-z_-]\{1,63\}\.\)\{1,\}[a-z][0-9a-z_-]\{1,62\}'

	removeCRLF | toLowercase | removeComments '#' | trimWhitespace \
		| sed -ne "/^\\(${ipRegex:?}[[:blank:]]\\{1,\\}\\)\\{0,1\\}${domainRegex:?}$/p" \
		| sed -e 's/^.\{1,\}[[:blank:]]\{1,\}//' \
		| sort | uniq
}

adblockToDomains() {
	domainRegex='\([0-9a-z_-]\{1,63\}\.\)\{1,\}[a-z][0-9a-z_-]\{1,62\}'

	contentFile="$(mktemp)"
	removeCRLF | toLowercase > "${contentFile:?}"

	domainsPipe="$(mktemp -u)"
	mkfifo -m 600 "${domainsPipe:?}" >/dev/null
	sed -ne "s/^||\(${domainRegex:?}\)\^$/\1/p" "${contentFile:?}" | sort | uniq > "${domainsPipe:?}" &

	exceptionsPipe="$(mktemp -u)"
	mkfifo -m 600 "${exceptionsPipe:?}" >/dev/null
	sed -ne "s/^@@||\(${domainRegex:?}\).*/\1/p" "${contentFile:?}" | sort | uniq > "${exceptionsPipe:?}" &

	comm -23 "${domainsPipe:?}" "${exceptionsPipe:?}"
	rm -f "${contentFile:?}" "${domainsPipe:?}" "${exceptionsPipe:?}" >/dev/null
}

main() {
	sourceList="$(jq -r '.sources|map(select(.enabled))' "${SCRIPT_DIR:?}/sources.json")"
	sourceCount="$(printf -- '%s' "${sourceList:?}" | jq -r '.|length-1')"

	tmpWorkDir="$(mktemp -d)"
	trap 'rm -rf -- "${tmpWorkDir:?}"; trap - EXIT; exit 0' EXIT TERM INT HUP

	printInfo 'Downloading lists...'

	for i in $(seq 0 "${sourceCount:?}"); do
		entry="$(printf -- '%s' "${sourceList:?}" | jq -r --arg i "${i:?}" '.[$i|tonumber]')"
		name="$(printf -- '%s' "${entry:?}" | jq -r '.name')"
		format="$(printf -- '%s' "${entry:?}" | jq -r '.format')"
		url="$(printf -- '%s' "${entry:?}" | jq -r '.url')"

		printList "${url:?}"

		tmpFile="${tmpWorkDir:?}/${name:?}.txt"
		outFile="${SCRIPT_DIR:?}/data/${name:?}/list.txt"
	
		if fetchUrl "${url:?}" > "${tmpFile:?}"; then
			mkdir -p "${outFile%/*}"

			if [ "${format:?}" = 'hosts' ]; then
				hostsToDomains < "${tmpFile:?}" > "${outFile:?}"
			elif [ "${format:?}" = 'adblock' ]; then
				adblockToDomains < "${tmpFile:?}" > "${outFile:?}"
			fi

			checksum="$(sha256sum "${outFile:?}" | cut -c 1-64)"
			printf '%s  %s\n' "${checksum:?}" "${outFile##*/}" > "${outFile:?}.sha256"
		else
			printError 'Download failed'
		fi
	done
}

main "${@}"
