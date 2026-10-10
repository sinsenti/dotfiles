#!/usr/bin/env python3
"""Install the optional local spoken-stop detector without system packages."""

from pathlib import Path
import shutil
import stat
import subprocess
import tempfile
from urllib.request import urlretrieve
import zipfile

from stop_commands import MODELS, data_directory


def main():
    directory = data_directory()
    directory.mkdir(parents=True, exist_ok=True)
    python = directory / ".venv/bin/python"
    uv = shutil.which("uv")
    if not uv:
        raise SystemExit("Install uv before setting up the stop listener")
    if not python.exists():
        subprocess.run([uv, "venv", "--python", "/usr/bin/python3", str(directory / ".venv")], check=True)
    subprocess.run([uv, "pip", "install", "--python", str(python), "vosk==0.3.45"], check=True)
    for name in MODELS:
        if (directory / name / "am/final.mdl").exists():
            continue
        print(f"Downloading {name} from the official Vosk model site", flush=True)
        with tempfile.TemporaryDirectory(dir=directory) as temporary:
            archive = Path(temporary) / "model.zip"
            urlretrieve(f"https://alphacephei.com/vosk/models/{name}.zip", archive)
            with zipfile.ZipFile(archive) as model:
                for member in model.infolist():
                    path = Path(member.filename)
                    if (path.is_absolute() or ".." in path.parts or not path.parts
                            or path.parts[0] != name or stat.S_ISLNK(member.external_attr >> 16)):
                        raise ValueError("Unexpected path in model archive")
                model.extractall(temporary)
            extracted = Path(temporary) / name
            if not (extracted / "am/final.mdl").exists():
                raise ValueError("Incomplete model archive")
            extracted.rename(directory / name)
    print("English and Russian stop-command models installed", flush=True)


if __name__ == "__main__":
    main()
