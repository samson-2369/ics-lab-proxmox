#!/bin/bash
# OT zone firewall rules (ics-lab-server, 192.168.200.10)
#
# Policy:
#   IT → OT: TCP/502 (Modbus) ALLOWED inbound
#   OT → IT: TCP/514 (syslog) ALLOWED outbound
#   SSH: only from the OT gateway (Proxmox management)
#   All other OT ↔ IT traffic: DROPPED and logged
#   OT → external internet: DROPPED (OT is air-gapped)
#
# Replace <IT_SUBNET>, <OT_SUBNET>, <OT_GATEWAY> with your values:
#   IT_SUBNET   default: 192.168.100.0/24
#   OT_SUBNET   default: 192.168.200.0/24
#   OT_GATEWAY  default: 192.168.200.1  (Proxmox host on vmbr200)
#
# Usage: bash ot-zone-iptables.sh
# To persist: netfilter-persistent save  (requires iptables-persistent)

IT_SUBNET="<IT_SUBNET>"    # e.g. 192.168.100.0/24
OT_SUBNET="<OT_SUBNET>"    # e.g. 192.168.200.0/24
OT_GATEWAY="<OT_GATEWAY>"  # e.g. 192.168.200.1

set -e

# Flush existing rules
iptables -F
iptables -X

# Default policies: ACCEPT (specific DROPs below)
iptables -P INPUT   ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT  ACCEPT

# Loopback
iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established/related sessions
iptables -A INPUT  -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# SSH from OT gateway only (Proxmox management access)
iptables -A INPUT -s "$OT_GATEWAY" -p tcp --dport 22 -j ACCEPT

# Modbus TCP inbound from IT zone
iptables -A INPUT -s "$IT_SUBNET" -p tcp --dport 502 -j ACCEPT

# Syslog outbound to IT zone
iptables -A OUTPUT -d "$IT_SUBNET" -p tcp --dport 514 -j ACCEPT

# Log and drop all other traffic to/from IT zone
iptables -A INPUT  -s "$IT_SUBNET" -j LOG --log-prefix "[FW-OT-DROP-IN] "
iptables -A INPUT  -s "$IT_SUBNET" -j DROP
iptables -A OUTPUT -d "$IT_SUBNET" -j LOG --log-prefix "[FW-OT-DROP-OUT] "
iptables -A OUTPUT -d "$IT_SUBNET" -j DROP

# Drop all external traffic (OT zone is air-gapped)
iptables -A OUTPUT ! -d "$OT_SUBNET" -j DROP

echo "OT zone firewall rules applied."
iptables -L -n -v
