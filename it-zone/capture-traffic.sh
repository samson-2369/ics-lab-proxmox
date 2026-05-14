#!/bin/bash
# Capture Modbus TCP traffic on the IT zone interface.
# Usage: ./capture-traffic.sh [interface]
#   Default interface: ens18 (Ubuntu cloud image default)

IFACE=${1:-ens18}
OUTFILE=/opt/ics-lab/modbus-capture-$(date +%Y%m%d-%H%M%S).pcap

echo "Capturing Modbus (TCP/502) on $IFACE → $OUTFILE"
echo "Press Ctrl+C to stop."
tcpdump -i "$IFACE" 'tcp port 502' -w "$OUTFILE" -v
echo "Capture saved: $OUTFILE"
