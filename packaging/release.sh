#!/bin/bash
# Prepares a release: verifies, tags, and stamps the formula with the tarball's
# checksum.
#
#   ./packaging/release.sh 0.1.0
#
# Stops before anything irreversible. It does not push, and it does not touch
# the tap repo; it prints the two commands that do.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=${1:-}
REPO="polgarp/ration"

# --stamp runs after the tag is pushed: it takes the checksum from the tarball
# GitHub actually serves, which is the only one Homebrew will ever see.
if [ "$VERSION" = "--stamp" ]; then
    VERSION=${2:-}
    [ -n "$VERSION" ] || { echo "usage: $0 --stamp <version>"; exit 1; }
    TAG="v$VERSION"
    URL="https://github.com/$REPO/archive/refs/tags/$TAG.tar.gz"
    echo "==> Fetching $URL"
    SHA=$(curl -fsSL "$URL" | shasum -a 256 | awk '{print $1}')
    [ -n "$SHA" ] || { echo "could not fetch the tarball; is the tag pushed?"; exit 1; }
    echo "    $SHA"
    sed -i '' \
        -e "s|/archive/refs/tags/v[0-9.]*\.tar\.gz|/archive/refs/tags/$TAG.tar.gz|" \
        -e "s|sha256 \".*\"|sha256 \"$SHA\"|" \
        packaging/ration.rb
    echo "==> Stamped packaging/ration.rb"
    echo
    echo "Now copy it into the tap and push:"
    echo "  cp packaging/ration.rb ../homebrew-tap/Formula/ration.rb"
    exit 0
fi

[ -n "$VERSION" ] || { echo "usage: $0 <version>   e.g. $0 0.1.0"; exit 1; }
TAG="v$VERSION"

echo "==> Checking the tree is clean"
[ -z "$(git status --porcelain)" ] || { echo "working tree is dirty"; exit 1; }

echo "==> Version in build.sh matches $VERSION"
grep -q "VERSION=\"$VERSION\"" build.sh || {
    echo "build.sh says $(grep '^VERSION=' build.sh), not $VERSION"; exit 1; }

echo "==> Building"
./build.sh > /dev/null

echo "==> Testing"
./run-tests.sh > /dev/null
./Tests/test-installer.sh > /dev/null
echo "    all suites pass"

echo "==> Tagging $TAG"
git tag -a "$TAG" -m "Ration $VERSION"

cat <<EOS

Tagged, nothing pushed. Push the tag, then stamp the formula:

  git push origin main "$TAG"
  $0 --stamp $VERSION

The checksum cannot be computed before the push: git-archive and GitHub
produce identical tar content but compress it differently, so only the
published .tar.gz has the bytes Homebrew will verify.
EOS
