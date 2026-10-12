#!/usr/bin/env python3
"""Write a CPC tape image (.cdt, the TZX format) of binary files, as the CPC firmware
would have saved them.

  mkcdt.py OUT.cdt [--baud 1000|2000] NAME:FILE:LOAD[:ENTRY] ...

Each file is saved as a binary (type 2) with that tape name, load address and entry
address (default: the load address), in the order given. The first one is what RUN""
loads. Addresses take #hex, &hex, 0xhex or decimal.

Firmware tape format: a file is cut into 2K blocks; each block is a header record and a
data record. A record is a leader of 1-bits, a 0-bit, a sync byte (#2C header, #16 data),
the bytes in 256-byte segments each followed by its CRC (CCITT, inverted, high byte first)
and a trailer of 32 1-bits. A 0-bit is two short pulses, a 1-bit two pulses twice as long.
Each record becomes one TZX "turbo speed data" block (ID #11) with those timings, in
3.5 MHz T-states. 2000 baud is SPEED WRITE 1, which the firmware reads like any other.
"""
import struct
import sys

T_PER_US = 3.5
LEADER_PULSES = 4096        # 2048 1-bits
TRAILER = b'\xff' * 4
SEGMENT = 256
BLOCK = 2048
MOTOR_GAP = 2500            # ms of silence after each block: the motor stops and starts


def crc16(data):
    crc = 0xFFFF
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) if crc & 0x8000 else crc << 1
            crc &= 0xFFFF
    return crc ^ 0xFFFF


def record(sync, data):
    """Sync byte, 256-byte segments (zero-padded) each with its CRC, trailer."""
    out = bytearray([sync])
    for i in range(0, len(data), SEGMENT):
        seg = bytes(data[i:i + SEGMENT]).ljust(SEGMENT, b'\0')
        out += seg + struct.pack('>H', crc16(seg))
    return out + TRAILER


def turbo_block(payload, baud, pause_ms):
    zero = round(1e6 / baud / 3 * T_PER_US)      # 1000 baud: 333 us per 0-pulse
    one = 2 * zero
    return (b'\x11' + struct.pack('<HHHHHHBH', one, zero, zero, zero, one, LEADER_PULSES,
                                  8, pause_ms)
            + struct.pack('<I', len(payload))[:3] + payload)


def tape_file(name, data, load, entry, baud):
    out = bytearray()
    blocks = [data[i:i + BLOCK] for i in range(0, len(data), BLOCK)] or [b'']
    for n, chunk in enumerate(blocks):
        header = bytearray(64)
        nm = name.upper().encode('ascii')[:16]
        header[0:len(nm)] = nm
        header[16] = n + 1                                  # block number
        header[17] = 0xFF if n == len(blocks) - 1 else 0     # last block
        header[18] = 2                                      # binary
        struct.pack_into('<HH', header, 19, len(chunk), load + n * BLOCK)
        header[23] = 0xFF if n == 0 else 0                  # first block
        struct.pack_into('<HH', header, 24, len(data), entry)
        out += turbo_block(record(0x2C, header), baud, 20)
        # The firmware stops the motor after every block it reads; started again, it waits
        # ~2 s for the tape to reach speed before it listens, so the next leader must come
        # later than that or it is missed ("Rewind tape").
        out += turbo_block(record(0x16, chunk), baud, MOTOR_GAP)
    return out


def number(s):
    s = s.strip()
    if s[0] in '#&':
        return int(s[1:], 16)
    return int(s, 0)


def main(argv):
    args = argv[1:]
    baud = 2000
    if '--baud' in args:
        i = args.index('--baud')
        baud = int(args[i + 1])
        del args[i:i + 2]
    if len(args) < 2:
        sys.exit(__doc__)
    out = bytearray(b'ZXTape!\x1a\x01\x14')
    out += b'\x20' + struct.pack('<H', 1000)                 # a second of silence first
    for spec in args[1:]:
        parts = spec.split(':')
        if len(parts) not in (3, 4):
            sys.exit(f"bad file spec {spec!r}: NAME:FILE:LOAD[:ENTRY]")
        name, path, load = parts[0], parts[1], number(parts[2])
        entry = number(parts[3]) if len(parts) == 4 else load
        data = open(path, 'rb').read()
        if load + len(data) > 0x10000:
            sys.exit(f"{path}: doesn't fit at #{load:04X}")
        out += tape_file(name, data, load, entry, baud)
        print(f"{name}: {len(data)} bytes at #{load:04X}, entry #{entry:04X}")
    open(args[0], 'wb').write(out)
    records = out.count(b'\x11' + struct.pack('<H', round(2e6 / baud / 3 * T_PER_US)))
    secs = (len(out) * 8 / baud + records * (LEADER_PULSES / 2 / baud * 1.5)
            + records / 2 * MOTOR_GAP / 1000)
    print(f"{args[0]}: {len(out)} bytes, about {secs / 60:.1f} min to load at {baud} baud")


if __name__ == '__main__':
    main(sys.argv)
