#!/usr/bin/env python3
"""Compile real Luau sources, run domain tests and injected-service tests, then build both place formats."""
from pathlib import Path
import os
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
BUILD = ROOT / 'build'
BUILD.mkdir(exist_ok=True)

def tool(name, environment, fallback):
    candidate = os.environ.get(environment) or shutil.which(name) or fallback
    if not Path(candidate).is_file():
        sys.exit(f'{name} missing. Install the pinned tool; see README.md')
    return candidate

luau = tool('luau', 'LUAU', '/workspace/tools/luau/luau')
compiler = tool('luau-compile', 'LUAU_COMPILE', str(Path(luau).with_name('luau-compile')))
rojo = tool('rojo', 'ROJO', '/workspace/tools/rojo/rojo')
files = sorted((ROOT / 'src').rglob('*.lua'))
for path in files:
    result = subprocess.run([compiler, str(path)], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if result.returncode:
        sys.exit(result.stderr.decode(errors='replace'))
print(f'PASS Luau compilation: {len(files)} source files', flush=True)
analyzer = tool('luau-analyze', 'LUAU_ANALYZE', str(Path(luau).with_name('luau-analyze')))
shared = sorted((ROOT / 'src/shared').rglob('*.lua'))
subprocess.run([analyzer, *map(str, shared)], check=True)
print(f'PASS strict shared-module analysis: {len(shared)} modules', flush=True)
subprocess.run([luau, 'tests/domain.spec.luau'], check=True)

# Inject service boundaries without copying/reimplementing the service under test.
def wrap(name, source, arguments):
    return f'local function {name}({arguments})\n{(ROOT / source).read_text()}\nend\n'

harness = wrap('makeDataService', 'src/server/Services/DataService.lua', 'game, workspace, task, require, warn')
harness += wrap('makeEventService', 'src/server/Services/EventService.lua', 'game, require, script, Vector3, CFrame, Color3')
harness += wrap('makeGuardianService', 'src/server/Services/GuardianService.lua', 'game, require, script, Vector3, CFrame, Color3, Enum, task, RaycastParams, workspace')
harness += (ROOT / 'tests/services.spec.luau').read_text()
(BUILD / 'services.generated.luau').write_text(harness)
subprocess.run([luau, 'build/services.generated.luau'], check=True)
subprocess.run([sys.executable, 'scripts/check_server_regressions.py'], check=True)
subprocess.run([luau, 'tests/ui.spec.luau'], check=True)
client = wrap('makeMovement', 'src/client/Controllers/MovementController.lua', 'game, require, Enum, UDim2, Color3')
client += wrap('makeEffects', 'src/client/Controllers/EffectsController.lua', 'game, workspace, require, Color3, Enum, task, TweenInfo, CFrame')
client += (ROOT / 'tests/client.spec.luau').read_text()
(BUILD / 'client.generated.luau').write_text(client)
subprocess.run([luau, 'build/client.generated.luau'], check=True)
# Lune validates native Roblox instance construction without starting the engine.
lune = os.environ.get('LUNE') or shutil.which('lune') or '/workspace/tools/lune/lune'
if Path(lune).is_file():
    subprocess.run([lune, 'run', 'tests/world-native.spec.luau'], check=True)
    subprocess.run([lune, 'run', 'tests/ui-native.spec.luau'], check=True)
else:
    print('SKIP optional native-instance checks: install Lune 0.11.0 (Studio tests remain unrun).', flush=True)

subprocess.run([rojo, 'build', 'default.project.json', '-o', 'build/StealAnEgg.rbxlx'], check=True)
subprocess.run([rojo, 'build', 'default.project.json', '-o', 'build/StealAnEgg.rbxl'], check=True)
if Path(lune).is_file():
    subprocess.run([lune, 'run', 'scripts/package-place.luau'], check=True)
    subprocess.run([lune, 'run', 'tests/startup-native.spec.luau'], check=True)
    subprocess.run([sys.executable, 'scripts/check_client_startup.py'], check=True)
else:
    print('SKIP editor map packaging: Lune is not installed; raw Rojo output generates its map after Play.', flush=True)
tree = ET.parse(BUILD / 'StealAnEgg.rbxlx')
scripts = tree.findall('.//Item[@class="ModuleScript"]') + tree.findall('.//Item[@class="Script"]') + tree.findall('.//Item[@class="LocalScript"]')
assert len(scripts) == len(files), (len(scripts), len(files))
assert (BUILD / 'StealAnEgg.rbxl').read_bytes().startswith(b'<roblox!')
print(f'PASS place assembly: {len(scripts)} scripts; binary header and XML tree verified', flush=True)
print('Roblox engine, multiplayer, devices and live DataStore: NOT TESTED here.', flush=True)
