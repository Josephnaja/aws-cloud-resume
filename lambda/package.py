"""Package visitor_counter.py into a zip for Lambda deployment."""
import zipfile
import os

script_dir = os.path.dirname(os.path.abspath(__file__))
source = os.path.join(script_dir, "visitor_counter.py")
output = os.path.join(script_dir, "visitor_counter.zip")

with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as z:
    z.write(source, "visitor_counter.py")

print(f"Created: {output}")
