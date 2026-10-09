import struct

with open("Insta360X5FW.bin", "rb") as f:
    f.seek(0x10481fdf + 256)
    ubi = f.read(0x200000)

print("UBI magic:", ubi[:4])
pos = 0
while True:
    pos = ubi.find(b"UBI!", pos)
    if pos == -1:
        break
    rec = ubi[pos:pos+128]
    vol_id = struct.unpack(">I", rec[16:20])[0]
    print(f"Found UBI! at 0x{pos:x}, vol_id: 0x{vol_id:08x} ({vol_id})")
    pos += 4

# Look for volume names
# In UBI vtbl_record:
# reserved_pebs(4), alignment(4), data_pad(4), vol_type(1), upd_marker(1), name_len(2), name(128)
pos = 0
while True:
    pos = ubi.find(b"rootfs", pos)
    if pos == -1:
        break
    print(f"Found 'rootfs' at 0x{pos:x}")
    pos += 6

# Let's search for UBIFS magic (0x06101831 little-endian: 0x31, 0x18, 0x10, 0x06)
ubifs_magic = b"\x31\x18\x10\x06"
pos = ubi.find(ubifs_magic)
print("UBIFS magic found at:", hex(pos) if pos != -1 else "not found")
