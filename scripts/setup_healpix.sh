#!/usr/bin/env bash
# -----------------------------------------------------------------------
# setup_healpix.sh
# Downloads healpix_cxx 3.83 from SourceForge and copies the C++ source
# files needed by the CHEALPix SPM target into Sources/CHEALPix/.
#
# Run once from the repository root before the first `swift build`:
#   bash scripts/setup_healpix.sh
# -----------------------------------------------------------------------
set -euo pipefail

HEALPIX_VERSION="3.83.0"
TARBALL="healpix_cxx-${HEALPIX_VERSION}.tar.gz"
DOWNLOAD_URL="https://sourceforge.net/projects/healpix/files/Healpix_3.83/${TARBALL}/download"
DEST="Sources/CHEALPix"
TMPDIR_LOCAL="$(mktemp -d)"

cd "$(dirname "$0")/.."   # run from repo root regardless of invocation dir

echo "→ Downloading healpix_cxx ${HEALPIX_VERSION}…"
curl -L --progress-bar -o "${TMPDIR_LOCAL}/${TARBALL}" "${DOWNLOAD_URL}"

echo "→ Extracting…"
tar -xzf "${TMPDIR_LOCAL}/${TARBALL}" -C "${TMPDIR_LOCAL}"

# Locate the Healpix_cxx source directory inside the tarball.
# The layout is healpix_cxx-3.83.0/src/cxx/Healpix_cxx/ (traditional)
# or healpix_cxx-3.83.0/Healpix_cxx/ (standalone tarball).
SRC=$(find "${TMPDIR_LOCAL}" -type d -name "Healpix_cxx" | head -1)
if [ -z "${SRC}" ]; then
    # Fallback: look one level up inside the extracted tree
    SRC=$(find "${TMPDIR_LOCAL}" -maxdepth 3 -type d | sort | tail -1)
fi

echo "→ Copying sources from ${SRC} → ${DEST}/"

# Headers and implementation files needed for pixel arithmetic.
# FITS-related files are intentionally excluded to avoid the cfitsio dependency.
NEEDED=(
    "healpix_base.h"
    "healpix_base.cc"
    "pointing.h"
    "vec3.h"
    "vec3.cc"
    "datatypes.h"
    "lsconstants.h"
    "trig_utils.h"
    "trig_utils.cc"
    "openmp_support.h"
)

for f in "${NEEDED[@]}"; do
    src_file="${SRC}/${f}"
    if [ -f "${src_file}" ]; then
        cp "${src_file}" "${DEST}/"
        echo "  copied ${f}"
    else
        echo "  WARNING: ${f} not found in tarball (may not be required)"
    fi
done

# Copy any remaining .h / .cc files that healpix_base.h might include,
# but skip FITS-related ones.
find "${SRC}" -maxdepth 1 \( -name "*.h" -o -name "*.cc" \) \
    ! -name "*fits*" ! -name "*fitsio*" ! -name "Healpix_Map*" \
    ! -name "alm*" ! -name "planck*" \
    | while read -r f; do
        base=$(basename "$f")
        if [ ! -f "${DEST}/${base}" ]; then
            cp "$f" "${DEST}/"
            echo "  also copied ${base}"
        fi
    done

rm -rf "${TMPDIR_LOCAL}"

echo ""
echo "✓ healpix_cxx ${HEALPIX_VERSION} ready in ${DEST}/"
echo "  Run 'swift build' to compile the package."
