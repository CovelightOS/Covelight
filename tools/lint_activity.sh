#!/usr/bin/env bash
# Static, best-effort scan for an activity that violates CLAUDE.md #1
# (textless) or #5/#10 (no network APIs reachable from activity code).
# Complements shell/sdk/text_audit.gd's *runtime* tree walk (which needs a
# live instance) with a *static* pass over an activity's own source, so a
# reviewer can run one command instead of eyeballing a diff.
# docs/guides/activity-review.md is what actually decides pass/fail; this
# script is one of the checks that checklist points at.
#
# Honest limitation (docs/design/activity-sdk.md §12): this is a grep over
# text, not a real parser. It cannot catch text drawn via draw_string() or
# baked into an image asset, and it can false-positive on an unrelated
# identifier that happens to contain a forbidden word (e.g. a script
# comment mentioning "Button"). It narrows what a human reviewer has to
# check by hand; it does not replace them.
#
# usage: tools/lint_activity.sh <path-to-activity-directory>

set -euo pipefail

usage() {
	echo "usage: $0 <path-to-activity-directory>" >&2
	exit 1
}

[ $# -eq 1 ] || usage
ACTIVITY_DIR="$1"
[ -d "$ACTIVITY_DIR" ] || { echo "error: not a directory: $ACTIVITY_DIR" >&2; exit 1; }

# Mirrors shell/sdk/text_audit.gd's TEXT-capable node list -- keep the two
# in sync if either changes.
TEXT_TYPES='Label|RichTextLabel|Button|LinkButton|MenuButton|LineEdit|TextEdit|CodeEdit|OptionButton|SpinBox|ItemList|Tree|AcceptDialog|ConfirmationDialog|FileDialog|PopupMenu|TabBar|TabContainer'

# Godot classes that can reach the network.
NETWORK_TYPES='HTTPRequest|HTTPClient|StreamPeerTCP|StreamPeerUDP|StreamPeerSSL|PacketPeerUDP|PacketPeerStream|WebSocketPeer|TCPServer|UDPServer|ENetMultiplayerPeer|ENetConnection|MultiplayerAPI'

# Portable word-boundary substitute -- BSD grep (macOS) and GNU grep
# (CI/Linux) don't agree on \b support in -E mode, so this brackets each
# match with "not an identifier character, or start/end of line" instead.
L='(^|[^A-Za-z0-9_])'
R='([^A-Za-z0-9_]|$)'

# Scan only the activity's own authored files. addons/ is the symlinked
# SDK, which legitimately names every one of these types in order to
# detect them (shell/sdk/text_audit.gd); tests/ may reference them the
# same way. Neither is "the activity" for review purposes.
FILES=$(find "$ACTIVITY_DIR" \( -name "*.gd" -o -name "*.tscn" \) \
	-not -path "*/addons/*" -not -path "*/tests/*" -not -path "*/.godot/*")

FOUND=0

if [ -n "$FILES" ]; then
	if TEXT_HITS=$(echo "$FILES" | xargs grep -nE "type=\"(${TEXT_TYPES})\"|${L}(${TEXT_TYPES})\\.new\\(|^extends (${TEXT_TYPES})${R}" 2>/dev/null); then
		echo "TEXT-CAPABLE NODE TYPES FOUND (constraint #1 -- textless):"
		echo "$TEXT_HITS"
		FOUND=1
	fi

	if NET_HITS=$(echo "$FILES" | xargs grep -nE "${L}(${NETWORK_TYPES})${R}" 2>/dev/null); then
		echo "NETWORK-CAPABLE CLASSES FOUND (constraint #5/#10 -- no network APIs):"
		echo "$NET_HITS"
		FOUND=1
	fi
fi

if [ "$FOUND" -eq 1 ]; then
	echo ""
	echo "lint_activity.sh: FAILED -- see above. Static and best-effort" \
		"(docs/design/activity-sdk.md §12); a human review pass still" \
		"happens per docs/guides/activity-review.md regardless of this exit code."
	exit 1
fi

echo "lint_activity.sh: clean -- no forbidden text-node or network-class references found in $ACTIVITY_DIR"
exit 0
