#!/usr/bin/env bash
# Package src/ plus pip dependencies into a Lambda zip (replaces sam build).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${1:-${ROOT}/terraform/.build/lambda.zip}"
STAGE="$(mktemp -d)"
cleanup() { rm -rf "${STAGE}"; }
trap cleanup EXIT

cp "${ROOT}/src/app.py" "${ROOT}/src/requirements.txt" "${ROOT}/src/run.sh" "${STAGE}/"
chmod +x "${STAGE}/run.sh"
python3 -m pip install -r "${ROOT}/src/requirements.txt" -t "${STAGE}" -q
find "${STAGE}" -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true

python3 - "${STAGE}" "${DEST}" <<'PY'
import pathlib
import sys
import zipfile

stage = pathlib.Path(sys.argv[1])
dest = pathlib.Path(sys.argv[2])
dest.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(dest, "w", compression=zipfile.ZIP_DEFLATED) as zf:
    for path in sorted(stage.rglob("*")):
        if path.is_file():
            zf.write(path, path.relative_to(stage).as_posix())
print(f"Wrote {dest} ({dest.stat().st_size} bytes)")
PY
