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
[ -n "$VERSION" ] || { echo "usage: $0 <version>   e.g. $0 0.1.0"; exit 1; }
TAG="v$VERSION"
REPO="polgarp/ration"

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

# GitHub generates this tarball from the tag, so the checksum only exists once
# the tag is pushed. Computing it locally from git-archive gives the same bytes.
echo "==> Checksum for the source tarball"
SHA=$(git archive --format=tar.gz --prefix="ration-$VERSION/" "$TAG" | shasum -a 256 | cut -d' ' -f1)
echo "    $SHA"

sed -i '' \
    -e "s|/archive/refs/tags/v[0-9.]*\.tar\.gz|/archive/refs/tags/$TAG.tar.gz|" \
    -e "s|sha256 \".*\"|sha256 \"$SHA\"|" \
    packaging/ration.rb
echo "==> Stamped packaging/ration.rb"

cat <<EOS

Nothing has been pushed. To finish:

  git push origin main "$TAG"
  cp packaging/ration.rb ../homebrew-tap/Formula/ration.rb   # then commit and push that

Verify the published tarball matches before anyone installs:

  curl -sL https://github.com/$REPO/archive/refs/tags/$TAG.tar.gz | shasum -a 256
  # expect $SHA

Then a user installs with:

  brew tap polgarp/tap
  brew install ration
EOS
