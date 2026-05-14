#!/bin/bash
# IT zone firewall rules (ics-workstation, 192.168.100.10)
#
# Policy:
#   IT → OT: TCP/502 (Modbus) ALLOWED
#   OT → IT: TCP/514 (syslog) ALLOWED inbound
#   All other IT ↔ OT traffic: DROPPED and logged
#
# Replace <OT_SUBNET> with your OT network (default: 192.168.200.0/24)
#
# Usage: bash it-zone-iptables.sh
# To persist: netfilter-persistent save  (requires iptables-persistent)

OT_SUBNET="<OT_SUBNET>"   # e.g. 192.168.200.0/24

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

# SSH inbound (management access)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Modbus TCP outbound to OT zone
iptables -A OUTPUT -d "$OT_SUBNET" -p tcp --dport 502 -j ACCEPT

# Syslog inbound from OT zone
iptables -A INPUT -s "$OT_SUBNET" -p tcp --dport 514 -j ACCEPT

# Log and drop all other traffic to/from OT zone
iptables -A OUTPUT -d "$OT_SUBNET" -j LOG --log-prefix "[FW-IT-DROP-OUT] "
iptables -A OUTPUT -d "$OT_SUBNET" -j DROP
iptables -A INPUT  -s "$OT_SUBNET" -j LOG --log-prefix "[FW-IT-DROP-IN] "
iptables -A INPUT  -s "$OT_SUBNET" -j DROP

echo "IT zone firewall rules applied."
iptables -L -n -v
