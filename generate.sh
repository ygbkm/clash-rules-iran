#!/bin/bash
set -euE -o pipefail
trap 'echo "${0##*/}: failed @ line $LINENO: $BASH_COMMAND"' ERR

get_domains()
{
	fetch 'https://github.com/bootmortis/iran-hosted-domains/releases/latest/download/domains.txt' | grep -v '\.ir$'
}

get_ips()
{
	fetch 'https://raw.githubusercontent.com/bootmortis/ito-gov-mirror/main/out/domains.csv' | sed 1d | cut -d, -f2
	fetch 'https://www.arvancloud.ir/en/ips.txt'
	fetch 'https://api.derak.cloud/public/ipv4'
	fetch 'https://api.derak.cloud/public/ipv6'
	fetch 'https://parspack.com/cdnips.txt'
	fetch 'https://ips.f95.com'
}

fetch()
{
	echo "fetching '$1'..." >&2
	curl --write-out '\n' --connect-timeout 20 -fsSL -- "$1"
}

main()
{
	readarray -t domains < <(get_domains)

	readarray -t ips < <(get_ips)

	ip4=()
	ip6=()

	echo 'generating rules...' >&2

	for ip in "${ips[@]}"; do
		case $ip in
			'') continue ;;
			*:*) # IPv6
				case $ip in
					*/[0-9]*) ;;
					*) ip=$ip/128 ;;
				esac
				ip6+=("${ip@L}")
			;;
			*) # IPv4
				case $ip in
					*/[0-9]*) ;;
					*) ip=$ip/32 ;;
				esac
				ip4+=("$ip")
			;;
		esac
	done

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

	rules_yaml=('payload:')

	for x in "${rules[@]}"; do
		rules_yaml+=("- '$x'")
	done

	mkdir -p output
	rm -rf -- output/*
	cd output

	printf '%s\n' "${rules[@]}" > rules.txt
	printf '%s\n' "${rules_yaml[@]}" > rules.yaml

	echo 'generating checksum...' >&2

	for f in *; do
		sha256sum "$f" > "$f.sha256"
	done

	echo 'done.' >&2
}

main "$@"
