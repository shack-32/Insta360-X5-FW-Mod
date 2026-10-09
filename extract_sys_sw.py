import os
import subprocess
import sys

firmware_file = "Insta360X5FW.bin"
ubi_output = "sys_sw.ubi"

offset = 0x10481fdf + 256
length = 63176704

print(f"Carving UBI partition from offset 0x{offset:08x}, length {length} bytes...")
with open(firmware_file, "rb") as fin:
    fin.seek(offset)
    data = fin.read(length)
    if len(data) != length:
        print(f"Warning: read only {len(data)} bytes")

with open(ubi_output, "wb") as fout:
    fout.write(data)

print(f"Saved {ubi_output} ({os.path.getsize(ubi_output)} bytes)")

# Now extract using python ubireader
output_dir = "extracted_sys_sw"
os.makedirs(output_dir, exist_ok=True)

# Run ubireader_extract_files
python_dir = os.path.dirname(sys.executable)
scripts_dir = os.path.join(python_dir, "Scripts")
ubireader_extract_cmd = os.path.join(scripts_dir, "ubireader_extract_files.exe")

if not os.path.exists(ubireader_extract_cmd):
    # Fallback to python module execution
    cmd = [sys.executable, "-m", "ubireader.extract_files", "-o", output_dir, ubi_output]
else:
    cmd = [ubireader_extract_cmd, "-o", output_dir, ubi_output]

print(f"Running extraction: {' '.join(cmd)}")
res = subprocess.run(cmd, capture_output=True, text=True)
print("STDOUT:", res.stdout[:1000])
print("STDERR:", res.stderr[:1000])
print("Return code:", res.returncode)
