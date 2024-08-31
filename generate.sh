#!/bin/bash

# catch errors
set -euE -o pipefail
trap 'echo "${0##*/}: failed @ line $LINENO: $BASH_COMMAND"' ERR

# domains source
domains()
{
	# non-dot-ir Iranian domains
	fetch 'https://github.com/bootmortis/iran-hosted-domains/releases/latest/download/domains.txt' | grep -v '\.ir$'
}

# IPv4 and IPv6 CIDRs source
ips()
{
	# Iranian messenger apps
	fetch 'https://raw.githubusercontent.com/bootmortis/ito-gov-mirror/main/out/domains.csv' | sed 1d | cut -d, -f2

	# Iranian datacenters
	fetch 'https://www.arvancloud.ir/en/ips.txt'
	fetch 'https://api.derak.cloud/public/ipv4'
	fetch 'https://api.derak.cloud/public/ipv6'
	fetch 'https://parspack.com/cdnips.txt'
	fetch 'https://ips.f95.com'
}

main()
{
	# ==================================================
	# = read domains and IPs to arrays
	# ==================================================

	# create an array of domains
	readarray -t domains < <(domains | despace)

	# create an array of IPs
	readarray -t ips < <(ips | despace)

	# ==================================================
	# = process domains
	# ==================================================

	echo 'generating rules' >&2

	# deduplicate domains
	readarray -t domains < <(printf '%s\n' "${domains[@]}" | sort --unique)

	# ==================================================
	# = process IPs
	# ==================================================

	ip4=()
	ip6=()

	# separate IPv4 and IPv6 CIDRs from each other and correct their formatting
	for ip in "${ips[@]}"; do
		case $ip in
			# IPv6
			*:*)
				case $ip in
					*/[0-9]*) ;;
					*) ip=$ip/128 ;;
				esac
				ip6+=("${ip@L}")
			;;
			# IPv4
			*[0-9].[0-9]*)
				case $ip in
					*/[0-9]*) ;;
					*) ip=$ip/32 ;;
				esac
				ip4+=("$ip")
			;;
		esac
	done

	# deduplicate IPs
	readarray -t ip4 < <(printf '%s\n' "${ip4[@]}" | sort --unique)
	readarray -t ip6 < <(printf '%s\n' "${ip6[@]}" | sort --unique)

	# ==================================================
	# = generate rules for the text format
	# ==================================================

	rules=(
		'GEOIP,ir'
		'DOMAIN-SUFFIX,ir'
	)

	for x in "${domains[@]}"; do
		rules+=("DOMAIN-SUFFIX,$x")
	done

	for x in "${ip4[@]}"; do
		rules+=("IP-CIDR,$x")
	done

	for x in "${ip6[@]}"; do
		rules+=("IP-CIDR6,$x")
	done

	# ==================================================
	# = generate rules for the yaml format
	# ==================================================

	rules_yaml=('payload:')

	for x in "${rules[@]}"; do
		rules_yaml+=("- '$x'")
	done

	# ==================================================
	# = write the rules to disk
	# ==================================================

	mkdir -p output
	cd output

	printf '%s\n' "${rules[@]}" > rules.txt
	printf '%s\n' "${rules_yaml[@]}" > rules.yaml

	echo 'generating checksum' >&2
	sha256sum -- * > SHA256SUMS

	echo 'done.' >&2
}

# download the given URL to stdout
fetch()
{
	echo "fetching $1 " >&2
	curl --write-out '\n' --connect-timeout 20 -fsSL -- "$1"
}

# remove empty lines and trailing spaces from stdin
despace()
{
	while IFS= read -r line; do
		set -- $line
		if [[ $# -ge 1 ]]; then
			printf '%s\n' "$1"
		fi
	done
}

main "$@"
