#!/usr/bin/env bash
# Regenerate hash constraint files after bumping default tool versions in ci.yml / composites.
# Requires: Python 3.11 + pip-tools (pip install pip-tools).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="${TMPDIR:-/tmp}/constraints-venv-$$"
python3.11 -m venv "$VENV"
# shellcheck disable=SC1090
source "$VENV/bin/activate"
pip install -q pip-tools

mk() {
  local pkg_ver="$1" out="$2"
  echo "$pkg_ver" > /tmp/c.in
  pip-compile --generate-hashes /tmp/c.in -o "$out" --strip-extras
}

# Ruff (no deps; --no-deps install in action)
mk "ruff==0.15.9" "$ROOT/.github/actions/ruff/constraints/ruff-0.15.9.txt"

# pytest + runtime deps
mk "pytest==9.0.2" "$ROOT/.github/actions/pytest/constraints/pytest-9.0.2.txt"

# pip-tools lock enforcement (includes pip/setuptools via --allow-unsafe)
echo "pip-tools==7.5.3" > /tmp/pt.in
pip-compile --generate-hashes /tmp/pt.in -o "$ROOT/.github/actions/install-pip-tools-hashed/constraints.txt" --strip-extras --allow-unsafe

# PyYAML for actionlint YAML parse
mk "pyyaml==6.0.3" "$ROOT/.github/actions/install-pyyaml-hashed/constraints.txt"

rm -rf "$VENV"
echo "Done. Commit the updated constraints/*.txt files."
