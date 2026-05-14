# Lightweight ICS Cybersecurity Lab — 4-Core Proxmox Edition

A minimal but complete Industrial Control Systems (ICS) security lab built on a single 4-core Proxmox host. Demonstrates SCADA protocol analysis, IT/OT network segmentation, Modbus traffic inspection, and threat detection using only two VMs.

Built as a hands-on portfolio project for ICS/OT security roles.

---

## Architecture

```
┌──────────────────────────────┐
│  VLAN 100 — IT Zone          │
│  192.168.100.0/24            │
│                              │
│  ics-workstation (VM 100)    │
│  ● Wireshark / tshark        │
│  ● tcpdump                   │
│  ● nmap                      │
│  ● pymodbus client           │
│  ● rsyslog (receives OT logs)│
└──────────────┬───────────────┘
               │  Firewall enforced:
               │  IT→OT: TCP/502 only
               │  OT→IT: TCP/514 only
               │  All else: DROPPED
┌──────────────┴───────────────┐
│  VLAN 200 — OT Zone          │
│  192.168.200.0/24            │
│                              │
│  ics-lab-server (VM 200)     │
│  ● Modbus TCP server (:502)  │
│  ● Sensor data simulator     │
│  ● syslog-ng (forwards logs) │
│  ● Air-gapped (no internet)  │
└──────────────────────────────┘
```

### Firewall Rules (enforced via iptables)

| Direction | Protocol | Port | Action |
|-----------|----------|------|--------|
| IT → OT   | TCP      | 502  | ALLOW  |
| OT → IT   | TCP      | 514  | ALLOW  |
| IT → OT   | any      | any  | DROP + LOG |
| OT → IT   | any      | any  | DROP + LOG |
| OT → internet | any  | any  | DROP   |

---

## Requirements

- Proxmox VE 7+ (tested on 6.17.2)
- 4 CPU cores, 4 GB RAM available for VMs, 40 GB thin-provisioned storage
- Ubuntu 22.04 Server cloud image (`jammy-server-cloudimg-amd64.img`)
- Two isolated Linux bridges (`vmbr100`, `vmbr200`)

---

## Setup

### 1. Network Bridges (Proxmox host)

Add to `/etc/network/interfaces`:

```
auto vmbr100
iface vmbr100 inet static
    address 192.168.100.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0

auto vmbr200
iface vmbr200 inet static
    address 192.168.200.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
```

Then: `ifup vmbr100 && ifup vmbr200`

### 2. Create VMs from Cloud Image

```bash
# IT workstation (VM 100)
qm create 100 --name ics-workstation --memory 2048 --cores 2 --cpu host \
  --net0 virtio,bridge=vmbr100 --ostype l26 --serial0 socket --vga serial0
qm importdisk 100 jammy-server-cloudimg-amd64.img local-lvm --format raw
qm set 100 --scsi0 local-lvm:vm-100-disk-0,discard=on \
  --ide2 local-lvm:cloudinit --boot order=scsi0 --scsihw virtio-scsi-pci \
  --ciuser root --cipassword <YOUR_PASSWORD> \
  --ipconfig0 ip=192.168.100.10/24,gw=192.168.100.1
qm resize 100 scsi0 20G
qm start 100

# OT lab server (VM 200)
qm create 200 --name ics-lab-server --memory 2048 --cores 2 --cpu host \
  --net0 virtio,bridge=vmbr200 --ostype l26 --serial0 socket --vga serial0
qm importdisk 200 jammy-server-cloudimg-amd64.img local-lvm --format raw
qm set 200 --scsi0 local-lvm:vm-200-disk-0,discard=on \
  --ide2 local-lvm:cloudinit --boot order=scsi0 --scsihw virtio-scsi-pci \
  --ciuser root --cipassword <YOUR_PASSWORD> \
  --ipconfig0 ip=192.168.200.10/24,gw=192.168.200.1
qm resize 200 scsi0 20G
qm start 200
```

### 3. Install Tools

**IT workstation:**
```bash
add-apt-repository universe
apt install -y wireshark-common tshark tcpdump nmap curl wget git \
  python3 python3-pip iptables-persistent netfilter-persistent
pip3 install pymodbus==2.5.3
```

**OT lab server:**
```bash
add-apt-repository universe
apt install -y build-essential python3 python3-pip syslog-ng \
  iptables-persistent netfilter-persistent
pip3 install pymodbus==2.5.3
```

### 4. Deploy Lab Scripts

**OT zone:**
```bash
mkdir -p /opt/ics-lab
cp ot-zone/modbus-server.py /opt/ics-lab/
cp ot-zone/modbus-server.service /etc/systemd/system/
systemctl daemon-reload && systemctl enable --now modbus-server
```

**IT zone:**
```bash
mkdir -p /opt/ics-lab
cp it-zone/modbus-client.py /opt/ics-lab/
cp it-zone/capture-traffic.sh /opt/ics-lab/
chmod +x /opt/ics-lab/capture-traffic.sh
```

### 5. Configure Syslog Forwarding

**OT zone** — edit `config/syslog-ng-ot.conf`, replace `<IT_WORKSTATION_IP>`:
```bash
cp config/syslog-ng-ot.conf /etc/syslog-ng/conf.d/ics-lab.conf
systemctl restart syslog-ng
```

**IT zone** — uncomment TCP lines in `/etc/rsyslog.conf` (see `config/rsyslog-it-receive.conf`):
```bash
systemctl restart rsyslog
```

### 6. Apply Firewall Rules

Edit the placeholder values in both firewall scripts, then:

```bash
# On IT workstation
bash firewall/it-zone-iptables.sh
netfilter-persistent save

# On OT lab server
bash firewall/ot-zone-iptables.sh
netfilter-persistent save
```

---

## Usage

### Read live sensor data (from IT zone)
```bash
OT_SERVER_IP=192.168.200.10 python3 /opt/ics-lab/modbus-client.py
```

Output example:
```
Connected to OT Lab Server (192.168.200.10:502)
  Temp:     49.4 C
  Pressure: 91.2 PSI
  Flow:     74.3 units/s
  Pump:     ON
  Alarm:    OK
  Coils 0-9: [True, False, True, True, False, False, True, False, True, True]
```

### Capture and analyze Modbus traffic
```bash
bash /opt/ics-lab/capture-traffic.sh          # captures to .pcap file
tshark -r modbus-capture-*.pcap -Y modbus     # filter Modbus frames
```

### Monitor OT logs on IT zone
```bash
tail -f /var/log/syslog | grep ics-lab-server
```

### Verify firewall segmentation
```bash
# From IT zone — should succeed
bash -c "echo > /dev/tcp/<OT_SERVER_IP>/502" && echo "Port 502: OPEN"

# From IT zone — should fail (firewall blocks)
bash -c "echo > /dev/tcp/<OT_SERVER_IP>/22"  && echo "Port 22: OPEN" || echo "Port 22: BLOCKED"
```

---

## Validation Checklist

- [ ] Both VMs boot with correct static IPs
- [ ] IT gateway (192.168.100.1) pingable from Proxmox host
- [ ] OT gateway (192.168.200.1) pingable from Proxmox host
- [ ] `modbus-client.py` returns live sensor readings
- [ ] Port 502 open from IT zone to OT zone
- [ ] Port 22, 80, 443 blocked from IT zone to OT zone
- [ ] OT syslog events appear in IT `/var/log/syslog`
- [ ] `modbus-server` systemd service survives reboot
- [ ] No internet reachable from OT zone

---

## Security Concepts Demonstrated

| Concept | Implementation |
|---------|---------------|
| IT/OT network segmentation | Separate VLANs (vmbr100/vmbr200), no shared bridge |
| Defense-in-depth | Application firewall + network isolation |
| Least-privilege network access | Only required ports open (502, 514) |
| OT air-gap enforcement | All external outbound traffic dropped on OT zone |
| Centralized OT logging | syslog-ng → rsyslog forwarding over TCP/514 |
| SCADA protocol analysis | Modbus TCP traffic capture with tshark/Wireshark |
| Anomaly detection baseline | Live register polling enables behavioral baselining |

---

## File Structure

```
ics-lab/
├── README.md
├── it-zone/
│   ├── modbus-client.py        # Reads sensor data from OT server
│   └── capture-traffic.sh      # Captures Modbus traffic to .pcap
├── ot-zone/
│   ├── modbus-server.py        # Simulated PLC with live sensor data
│   └── modbus-server.service   # systemd unit for persistence
├── config/
│   ├── syslog-ng-ot.conf       # OT syslog forwarding config
│   └── rsyslog-it-receive.conf # IT syslog reception config
└── firewall/
    ├── it-zone-iptables.sh     # IT zone iptables rules
    └── ot-zone-iptables.sh     # OT zone iptables rules
```

---

## License

MIT
