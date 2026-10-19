#!/usr/bin/env python3
"""Reuse the native UI boundary fixture to run the actual packaged client entry point."""
from pathlib import Path
import os
import shutil
import subprocess
ROOT=Path(__file__).resolve().parents[1]
os.chdir(ROOT)
lune=os.environ.get('LUNE') or shutil.which('lune') or '/workspace/tools/lune/lune'
fixture=(ROOT/'tests/ui-native.spec.luau').read_text().split('local sent={}\n',1)[0]
assert 'local function module(name)' in fixture
harness=fixture+(ROOT/'tests/client-startup-native.spec.luau').read_text()
output=ROOT/'build/client-startup-native.generated.luau'
output.write_text(harness)
subprocess.run([lune,'run',str(output.relative_to(ROOT))],check=True)
