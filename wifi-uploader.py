# First arg is identity.h, second arg is program.bin

#!/usr/bin/env python3
import sys
import uuid
from pathlib import Path
from urllib.request import urlopen, Request
from urllib.error import HTTPError, URLError

# Some Pythons (notably source-built ones on macOS) lack the ssl module,
# so urllib cannot open https URLs. Fall back to curl in that case.
try:
    import ssl
    HAVE_SSL = True
except ImportError:
    HAVE_SSL = False

# ─── Configuration ────────────────────────────────────────────────────────────

API_BASE_URL_LOCAL = "http://localhost:3000/api/upload-program"
API_BASE_URL_ONLINE = "https://issresearchlab.com/api/upload-program"

# ──────────────────────────────────────────────────────────────────────────────

import re
import sys
from pathlib import Path

def get_identity(file_path):
    path = Path(file_path)

    if not path.exists():
        print(f"Error: Identity not found. Please create an identity.h in your sketch folder, and add these lines:")
        print(f"#define HARDWARE_ID <your hardware id>")
        print(f"#define UPLOAD_PASSWORD <upload password found in your dashboard>")
        sys.exit(1)

    # utf-8 is the standard; errors='ignore' prevents the crash if weird bytes exist
    try:
        content = path.read_text(encoding='utf-8', errors='ignore')
    except Exception:
        # Fallback for some Windows-created files
        content = path.read_text(encoding='cp1252', errors='ignore')

    # This regex finds #define, then the key, then the value
    # ^#define  -> looks for the macro at the start of a line
    # (\w+)     -> captures the name (e.g., HARDWARE_ID)
    # \s+       -> handles any amount of whitespace
    # (\S+)     -> captures the value (non-whitespace characters)
    pattern = r"^#define\s+(\w+)\s+(\S+)"
   
    matches = re.findall(pattern, content, re.MULTILINE)
   
    # Create dictionary: {'HARDWARE_ID': '123456', ...}
    return {key: value for key, value in matches}

def upload_with_curl(identity, path, url, server_location):
    # curl ships with macOS and Windows 10+, and handles the multipart
    # body itself via -F.
    import subprocess

    print(f"Uploading {path.name} to {identity['HARDWARE_ID']} using {server_location} server...")
    try:
        result = subprocess.run(
            [
                "curl", "--silent", "--show-error",
                "--write-out", "\n%{http_code}",
                "-H", f"x-upload-password: {identity['UPLOAD_PASSWORD']}",
                "-F", f"file=@{path}",
                url,
            ],
            capture_output=True, text=True,
        )
    except FileNotFoundError:
        print("Connection error: this Python has no SSL support and curl was not found.")
        print("Install Python 3 from python.org (or Homebrew) and try again.")
        sys.exit(1)

    if result.returncode != 0:
        print(f"Connection error: {result.stderr.strip()}")
        return

    body, _, status = result.stdout.rpartition("\n")
    if status.startswith("2"):
        print("Upload to server successful! Watch simulator screen to confirm upload to MicroLab.")
        print(body)
    else:
        print(f"Server returned an error: {status}")
        print(f"Response body: {body}")

def upload_firmware(identity, file_path, server_location):
   
    # Print Arguments (for debugging)
    # args = sys.argv[1:]
    # if args:
    #     print(f"Received {len(args)} arguments:")
    #     for i, arg in enumerate(args, start=1):
    #         print(f"Argument {i}: {arg}")
   
    path = Path(file_path)

    if not path.exists():
        print(f"Error: File '{file_path}' not found.")
        sys.exit(1)
       
    if "HARDWARE_ID" not in identity:
        print("Cannot upload. Missing #define HARDWARE_ID <your hardware id> in identity.h")
        sys.exit(1)
       
    if "UPLOAD_PASSWORD" not in identity:
        print("Cannot upload. Missing #define UPLOAD_PASSWORD <your hardware id> in identity.h")
        sys.exit(1)

    if server_location == "online":
        url = API_BASE_URL_ONLINE
    else:
        url = API_BASE_URL_LOCAL
       
    url = f"{url.rstrip('/')}/{identity['HARDWARE_ID']}"

    if url.startswith("https") and not HAVE_SSL:
        upload_with_curl(identity, path, url, server_location)
        return

    # Build multipart/form-data manually
    boundary = uuid.uuid4().hex
    file_data = path.read_bytes()

    body = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="file"; filename="{path.name}"\r\n'
        f"Content-Type: application/octet-stream\r\n\r\n"
    ).encode() + file_data + f"\r\n--{boundary}--\r\n".encode()

    req = Request(url, data=body)
    req.add_header("x-upload-password", identity['UPLOAD_PASSWORD'])
    req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")

    try:
        print(f"Uploading {path.name} to {identity['HARDWARE_ID']} using {server_location} server...")
        with urlopen(req) as response:
            print("Upload to server successful! Watch simulator screen to confirm upload to MicroLab.")
            print(response.read().decode())

    except HTTPError as e:
        print(f"Server returned an error: {e.code} {e.reason}")
        print(f"Response body: {e.read().decode()}")
    except URLError as e:
        print(f"Connection error: {e.reason}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Not enough arguments, should be identity path, .bin path, location (online/local)")
        sys.exit(1)
       
    identity_file_path = sys.argv[1]
    file_arg = sys.argv[2]
    server_location = sys.argv[3]
       
    identity = get_identity(identity_file_path)
    upload_firmware(identity, file_arg, server_location)