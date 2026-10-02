#!/bin/sh
set -eu

# NAT gateway simulating a *symmetric* NAT (per the STUN/ICE NAT taxonomy —
# the hardest case for P2P traversal): the external port chosen for an
# outbound flow varies per destination (address, port), not just per
# internal (address, port). This is exactly the NAT type that breaks
# STUN-based hole punching and is the reason TURN relay exists at all — so
# it's the case this spike needs to prove TURN still works through.
#
# INTERNAL_SUBNET: the client-behind-nat side's subnet (masqueraded).
# Requires NET_ADMIN (set in docker-compose.yml) for sysctl + nft.

: "${INTERNAL_SUBNET:?INTERNAL_SUBNET env var is required}"

echo "[nat-gateway] IP forwarding (expected to be set via compose sysctls):"
cat /proc/sys/net/ipv4/ip_forward

echo "[nat-gateway] applying symmetric-NAT nftables rule for ${INTERNAL_SUBNET}"
nft add table ip nat
nft add chain ip nat postrouting '{ type nat hook postrouting priority 100 ; }'
# "random, fully-random" picks a new external port per connection tuple
# rather than trying to preserve the internal source port — the behavior
# that makes this symmetric rather than full-cone/restricted-cone NAT.
nft add rule ip nat postrouting ip saddr "${INTERNAL_SUBNET}" masquerade random,fully-random

echo "[nat-gateway] ready"
exec sleep infinity
