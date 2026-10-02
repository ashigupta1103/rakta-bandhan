#!/usr/bin/env bash
# One command that runs every check CI runs (.github/workflows/ci.yml).
#
#   bash tool/preflight.sh
#
# Needs Flutter, Node 22+, Java 21+ (the rules emulator) and firebase-tools on
# PATH. Dependencies are installed only when node_modules is missing.
# `flutter pub get` can rewrite the tracked plugin-registrant files under
# macos/ and windows/ (line-ending noise): `git restore` them, don't commit them.
set -euo pipefail
cd "$(dirname "$0")/.."

step() { printf '\n== %s\n' "$1"; }
deps() { [ -d node_modules ] || npm ci --silent; }

step "flutter analyze"
flutter pub get >/dev/null
flutter analyze

step "flutter test"
flutter test
# The login form differs once the emailed-code sign-in is switched on.
flutter test --dart-define=EMAIL_CODE_LIVE=true test/release_features_test.dart

step "functions: unit tests"
(cd functions && deps && npm test)
step "functions: emulator smoke"
(cd functions && if [ ! -f .secret.local ]; then printf 'SMTP_URL=emulator-no-mail\nREVIEW_CODE=246810\n' > .secret.local; fi
  FUNCTIONS_DISCOVERY_TIMEOUT=120 npm run smoke)

step "edge Worker: tests and bundle"
(cd edge && deps && npm test && WRANGLER_SEND_METRICS=false npm run check >/dev/null)

step "rules tests (Firebase emulator)"
(cd backend/rules-test && deps && npm test)

step "admin console: types, build, lint"
(cd admin/frontend && deps && npx tsc --noEmit && npm run build && npm run lint)

printf '\npreflight OK\n'
