#!/usr/bin/env python3
"""
Modbus TCP client — reads live sensor registers from the OT Lab Server.

Usage:
    python3 modbus-client.py
    OT_SERVER_IP=192.168.200.10 python3 modbus-client.py

Register map (holding registers, 0-based):
    0 = Temperature  (value / 10 = °C)
    1 = Pressure     (value / 10 = PSI)
    2 = Flow rate    (value / 10 = units/s)
    3 = Pump status  (1 = ON, 0 = OFF)
    4 = Alarm        (1 = ACTIVE, 0 = OK)

Requirements: pymodbus==2.5.3
"""
import os, sys
from pymodbus.client.sync import ModbusTcpClient

OT_IP   = os.environ.get("OT_SERVER_IP", "<OT_SERVER_IP>")
OT_PORT = int(os.environ.get("OT_SERVER_PORT", "502"))


def main():
    client = ModbusTcpClient(OT_IP, port=OT_PORT)
    if not client.connect():
        print(f"Failed to connect to {OT_IP}:{OT_PORT}")
        sys.exit(1)
    print(f"Connected to OT Lab Server ({OT_IP}:{OT_PORT})")

    result = client.read_holding_registers(0, 5, unit=1)
    if not result.isError():
        r = result.registers
        print(f"  Temp:     {r[0]/10:.1f} C")
        print(f"  Pressure: {r[1]/10:.1f} PSI")
        print(f"  Flow:     {r[2]/10:.1f} units/s")
        print(f"  Pump:     {'ON' if r[3] else 'OFF'}")
        print(f"  Alarm:    {'ACTIVE' if r[4] else 'OK'}")
    else:
        print(f"  Register read error: {result}")

    result = client.read_coils(0, 10, unit=1)
    if not result.isError():
        print(f"  Coils 0-9: {result.bits[:10]}")
    else:
        print(f"  Coil read error: {result}")

    client.close()
    print("Disconnected")


if __name__ == "__main__":
    main()
