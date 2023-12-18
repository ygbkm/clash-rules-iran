#!/bin/bash
set -euE -o pipefail
trap 'echo "${0##*/}: failed @ line $LINENO: $BASH_COMMAND"' ERR

# print a list of domains
get_domains()
{
	fetch 'https://github.com/bootmortis/iran-hosted-domains/releases/latest/download/domains.txt' | grep -v '\.ir$'
}

# print a list of IPv4 and IPv6 CIDRs
get_ips()
{
	fetch 'https://raw.githubusercontent.com/bootmortis/ito-gov-mirror/main/out/domains.csv' | sed 1d | cut -d, -f2
	fetch 'https://www.arvancloud.ir/en/ips.txt'
	fetch 'https://api.derak.cloud/public/ipv4'
	fetch 'https://api.derak.cloud/public/ipv6'
	fetch 'https://parspack.com/cdnips.txt'
	fetch 'https://ips.f95.com'
}

# download the given URL to stdout
fetch()
{
	echo "fetching '$1'..." >&2
	curl --write-out '\n' --connect-timeout 20 -fsSL -- "$1"
}

main()
{
	# ==================================================
	# = read domains and IPs to arrays
	# ==================================================

	# create an array of domains
	readarray -t domains < <(get_domains | sort --unique)

	# create an array of IPs
	readarray -t ips < <(get_ips)

	# ==================================================
	# = process IPs
	# ==================================================

	echo 'generating rules...' >&2

	ip4=()
	ip6=()

	# separate IPv4 and IPv6 CIDRs from each other and correct their formatting
	for ip in "${ips[@]}"; do
		case $ip in
			*:*) # IPv6
				case $ip in
					*/[0-9]*) ;;
					*) ip=$ip/128 ;;
				esac
				ip6+=("${ip@L}")
			;;
			*[0-9].[0-9]*) # IPv4
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
	# = generate text rules
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
	# = generate yaml rules
	# ==================================================

	rules_yaml=('payload:')

	for x in "${rules[@]}"; do
		rules_yaml+=("- '$x'")
	done

	# ==================================================
	# = write rules to files
	# ==================================================

	mkdir -p output
	rm -rf -- output/*
	cd output

	printf '%s\n' "${rules[@]}"      > rules.txt
	printf '%s\n' "${rules_yaml[@]}" > rules.yaml

	echo 'generating checksum...' >&2

	for f in *; do
		sha256sum "$f" > "$f.sha256"
	done

	echo 'done.' >&2
}

main "$@"
