#!/bin/sh

# Author:     Héctor Molinero Fernández <hector@molinero.xyz>
# Repository: https://github.com/zant95/hMirror
# License:    MIT, https://opensource.org/licenses/MIT

# Exit on errors
set -eu

# Globals
export LC_ALL=C

# Sources
sources=$(cat <<-'EOF'
	adaway.org|https://adaway.org/hosts.txt
	disconnect.me-ad|https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt
	disconnect.me-malvertising|https://s3.amazonaws.com/lists.disconnect.me/simple_malvertising.txt
	disconnect.me-malware|https://s3.amazonaws.com/lists.disconnect.me/simple_malware.txt
	disconnect.me-tracking|https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt
	dshield.org-high|https://www.dshield.org/feeds/suspiciousdomains_High.txt
	dshield.org-low|https://www.dshield.org/feeds/suspiciousdomains_Low.txt
	dshield.org-medium|https://www.dshield.org/feeds/suspiciousdomains_Medium.txt
	fademind-add.2o7net|https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.2o7Net/hosts
	fademind-add.dead|https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Dead/hosts
	fademind-add.risk|https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Risk/hosts
	fademind-add.spam|https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts
	malwaredomainlist.com|https://www.malwaredomainlist.com/hostslist/hosts.txt
	malwaredomains.com-immortaldomains|http://mirror1.malwaredomains.com/files/immortal_domains.txt
	malwaredomains.com-justdomains|http://mirror1.malwaredomains.com/files/justdomains
	pgl.yoyo.org|https://pgl.yoyo.org/adservers/serverlist.php?hostformat=nohtml&mimetype=plaintext
	ransomwaretracker.abuse.ch|https://ransomwaretracker.abuse.ch/downloads/RW_DOMBL.txt
	someonewhocares.org|http://someonewhocares.org/hosts/hosts
	spam404.com|https://raw.githubusercontent.com/Dawsey21/Lists/master/main-blacklist.txt
	winhelp2002.mvps.org|http://winhelp2002.mvps.org/hosts.txt
	zeustracker.abuse.ch|https://zeustracker.abuse.ch/blocklist.php?download=domainblocklist
EOF
)

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
	curl -fsSL -A 'Mozilla/5.0' -- "$@"
}

# Process
main() {
	printAction 'Downloading lists...'
	mkdir -p ./data && cd ./data

	for list in $sources; do
		name="$(printf -- '%s\n' "$list" | cut -d\| -f1)"
		url=$(printf -- '%s\n' "$list" | cut -d\| -f2)

		printInfo "$url"
		content=$(fetchUrl "$url") || true

		if [ -n "$content" ]; then
			rm -rf "$name" && mkdir "$name" && cd "$name"

			printf -- '%s\n' "$content" > list.txt
			sha256sum list.txt > list.txt.sha256

			cd ..
		else
			printError 'Download failed'
		fi

		unset name url content
	done
}

main

