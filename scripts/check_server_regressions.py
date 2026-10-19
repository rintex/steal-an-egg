#!/usr/bin/env python3
"""Inject controlled clocks/services into the real server sources for race regressions."""
from pathlib import Path
import os
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
BUILD = ROOT / "build"
BUILD.mkdir(exist_ok=True)
luau = os.environ.get("LUAU") or shutil.which("luau") or "/workspace/tools/luau/luau"

def wrap(name, source, arguments):
    return f"local function {name}({arguments})\n{(ROOT / source).read_text()}\nend\n"

harness = wrap("makeData", "src/server/Services/DataService.lua", "game, workspace, task, require, warn")
harness += wrap("makeGame", "src/server/Services/GameService.lua", "game, script, require, task")
harness += wrap("makeMovement", "src/server/Services/MovementService.lua", "game, require, Vector3, CFrame, RaycastParams, Enum, workspace, os")
harness += (ROOT / "tests/server-regressions.spec.luau").read_text()
path = BUILD / "server-regressions.generated.luau"
path.write_text(harness)
subprocess.run([luau, str(path.relative_to(ROOT))], check=True)
