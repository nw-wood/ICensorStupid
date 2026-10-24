#!/usr/bin/env bash
# Copyright (C) 2026 NATHANYEL WOOD <nathanyelw@gmail.com>
# Licensed under the GNU General Public License v3.0 or later (GPL-3.0-or-later).
#
# ONE-COMMAND PUBLISHER FOR GITHUB (REPO + PUSH + RELEASE ZIP)
# Modeled after advanced-meditation/publish-all.sh with keyring/REST fallback.

set -euo pipefail

chmod +x "$0" 2>/dev/null || true
cd "$(dirname "$0")"

MOD_NAME=$(python3 -c 'import json; print(json.load(open("info.json"))["name"])')
VERSION=$(python3 -c 'import json; print(json.load(open("info.json"))["version"])')
GH_USER="nw-wood"
REPO_NAME="${1:-${MOD_NAME}}"
DESCRIPTION="Factorio 2.0 Mod: Removes random backer names from newly built and existing Labs, Roboports, Radars, Train stops, and Locomotives across all surfaces."
PACKAGE_FULL="${MOD_NAME}_${VERSION}"
ZIP_PATH="dist/releases/${PACKAGE_FULL}.zip"

echo "======================================================================"
echo " Publishing ${PACKAGE_FULL} (GPL-3.0-or-later) to GitHub (${GH_USER}/${REPO_NAME})"
echo "======================================================================"

# 1. Package Factorio Mod Release Asset (.zip with top-level No_Lab_Names_2.0.0/ folder)
echo ":: Creating Factorio mod release zip: ${ZIP_PATH}..."
mkdir -p dist/releases
rm -f "${ZIP_PATH}"

STAGE_DIR=$(mktemp -d)
trap 'rm -rf "${STAGE_DIR}"' EXIT
mkdir -p "${STAGE_DIR}/${PACKAGE_FULL}"

cp -r info.json changelog.txt control.lua LICENSE.md README.md thumbnail.png locale "${STAGE_DIR}/${PACKAGE_FULL}/"
(
    cd "${STAGE_DIR}"
    zip -rq "${OLDPWD}/${ZIP_PATH}" "${PACKAGE_FULL}"
)

# 2. Initialize Git Repo & Commit any changes
if [ ! -d .git ]; then
    git init -b main
fi

git config user.name "Nathanyel Wood"
git config user.email "nathanyelw@gmail.com"

if [ -n "$(git status --porcelain)" ]; then
    git add -A
    git commit -m "chore(release): package ${PACKAGE_FULL} release"
fi

# 3. Retrieve GitHub Token from environment or system keyring
TOKEN="${GITHUB_TOKEN:-}"
if [ -z "${TOKEN}" ] && command -v secret-tool >/dev/null 2>&1; then
    TOKEN="$(secret-tool lookup service gh:github.com 2>/dev/null || true)"
fi

if [ -z "${TOKEN}" ]; then
    echo "Error: Could not find GitHub token in keyring (service gh:github.com) or GITHUB_TOKEN." >&2
    exit 1
fi

# 4. Create public repository on GitHub via REST API (idempotent if already exists)
echo ":: Ensuring public GitHub repository ${GH_USER}/${REPO_NAME} exists..."
HTTP_CODE=$(curl -sS -o /tmp/nolabnames_gh_repo.json -w "%{http_code}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    https://api.github.com/user/repos \
    -d "{\"name\":\"${REPO_NAME}\",\"description\":\"${DESCRIPTION}\",\"private\":false}")

if [ "${HTTP_CODE}" = "201" ]; then
    echo ":: Created repository https://github.com/${GH_USER}/${REPO_NAME}"
elif [ "${HTTP_CODE}" = "422" ]; then
    echo ":: Repository https://github.com/${GH_USER}/${REPO_NAME} already exists."
else
    echo ":: GitHub API returned HTTP ${HTTP_CODE}:"
    cat /tmp/nolabnames_gh_repo.json
fi
rm -f /tmp/nolabnames_gh_repo.json

# 5. Set clean remote URL and push main + tag using ephemeral Basic Auth header
REMOTE_URL="https://github.com/${GH_USER}/${REPO_NAME}.git"
if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "${REMOTE_URL}"
else
    git remote add origin "${REMOTE_URL}"
fi

git tag -f "v${VERSION}"

echo ":: Pushing main branch and tag v${VERSION} to ${REMOTE_URL}..."
AUTH_B64=$(printf "%s:%s" "${GH_USER}" "${TOKEN}" | base64 -w0)
git -c "http.https://github.com/.extraheader=AUTHORIZATION: basic ${AUTH_B64}" push -u origin main --force
git -c "http.https://github.com/.extraheader=AUTHORIZATION: basic ${AUTH_B64}" push origin "v${VERSION}" --force

# 6. Create or Update GitHub Release for v${VERSION} and upload mod zip asset
echo ":: Publishing GitHub Release v${VERSION}..."
REL_NOTES="Factorio 2.0 release of No Lab Names (v${VERSION}). Removes random backer names from newly built and existing Labs, Roboports, Radars, Train stops, and Locomotives across all surfaces."

REL_Payload=$(python3 -c 'import json, sys; print(json.dumps({
    "tag_name": sys.argv[1],
    "name": f"{sys.argv[1]} — No Lab Names (Factorio 2.0)",
    "body": sys.argv[2],
    "draft": False,
    "prerelease": False
}))' "v${VERSION}" "${REL_NOTES}")

REL_CODE=$(curl -sS -o /tmp/nolabnames_gh_rel.json -w "%{http_code}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${GH_USER}/${REPO_NAME}/releases" \
    -d "${REL_Payload}")

if [ "${REL_CODE}" != "201" ]; then
    # Fetch existing release by tag
    curl -sS -o /tmp/nolabnames_gh_rel.json \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${GH_USER}/${REPO_NAME}/releases/tags/v${VERSION}"
fi

RELEASE_ID=$(python3 -c 'import json; print(json.load(open("/tmp/nolabnames_gh_rel.json")).get("id", ""))')
rm -f /tmp/nolabnames_gh_rel.json

if [ -n "${RELEASE_ID}" ]; then
    echo ":: Uploading ${ZIP_PATH} to GitHub Release v${VERSION} (ID: ${RELEASE_ID})..."
    curl -sS -o /dev/null \
        -X POST \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        -H "Content-Type: application/zip" \
        --data-binary @"${ZIP_PATH}" \
        "https://uploads.github.com/repos/${GH_USER}/${REPO_NAME}/releases/${RELEASE_ID}/assets?name=${PACKAGE_FULL}.zip" || true
fi

echo "======================================================================"
echo " ★ PUBLISHED ${PACKAGE_FULL} SUCCESSFULLY!"
echo "   - GitHub Repo:    https://github.com/${GH_USER}/${REPO_NAME}"
echo "   - GitHub Release: https://github.com/${GH_USER}/${REPO_NAME}/releases/tag/v${VERSION}"
echo "   - Mod Zip Asset:  ${ZIP_PATH}"
echo "======================================================================"
