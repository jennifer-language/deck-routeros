#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <jennifer@mplx.dev>
#
# routeros overrides the shared example runner.
#
# Every example opens a connection to a real MikroTik router - address,
# credentials and all - so running them in CI would either hang or fail on a
# refused connection. What CI can check is that each one still parses against
# the current language and the current module surface, which is what catches an
# example left behind by a rename. `jennifer lint` covers them too, in the
# test workflow, and that reaches undefined calls.
#
# Usage: tools/check-examples.sh
set -euo pipefail
cd "$(dirname "$0")/.."
exec env EXAMPLES_SKIP_RUN=1 tools/check-examples-shared.sh
