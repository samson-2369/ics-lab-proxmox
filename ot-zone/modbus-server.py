#!/usr/bin/env python3
"""
Modbus TCP server simulating an OT PLC with live sensor data.

Listens on 0.0.0.0:502. A background thread updates holding registers
every 5 seconds with sine/cosine-varying sensor values.

Register map (holding registers, 0-based):
    0 = Temperature  (value / 10 = °C,   range ~40–60)
    1 = Pressure     (value / 10 = PSI,  range ~80–120)
    2 = Flow rate    (value / 10 = u/s,  range ~70–80)
    3 = Pump status  (1 = ON, 0 = OFF)
    4 = Alarm        (1 = ACTIVE, 0 = OK)

Coil map (0-based): 10 digital I/O signals, static demo pattern.

Requirements: pymodbus==2.5.3
"""
import math, time, threading, logging
from pymodbus.server.sync import StartTcpServer
from pymodbus.datastore import (
    ModbusSequentialDataBlock,
    ModbusSlaveContext,
    ModbusServerContext,
)

logging.basicConfig(level=logging.WARNING)

store = ModbusSlaveContext(
    di=ModbusSequentialDataBlock(0, [0] * 100),
    co=ModbusSequentialDataBlock(0, [0] * 100),
    hr=ModbusSequentialDataBlock(0, [0] * 100),
    ir=ModbusSequentialDataBlock(0, [0] * 100),
)
context = ModbusServerContext(slaves=store, single=True)


def update_sensors():
    while True:
        t = time.time()
        temp     = int(500 + 100 * math.sin(t / 60))
        pressure = int(1000 + 200 * math.cos(t / 45))
        flow     = int(750 + 50 * math.sin(t / 30 + 1))
        context[0x00].setValues(3, 0, [temp, pressure, flow, 1, 0])
        context[0x00].setValues(
            1, 0, [True, False, True, True, False, False, True, False, True, True]
        )
        time.sleep(5)


threading.Thread(target=update_sensors, daemon=True).start()
print("Modbus TCP server listening on 0.0.0.0:502", flush=True)
StartTcpServer(context, address=("0.0.0.0", 502))
