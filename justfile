# Covelight developer commands (T1.8, docs/plan/02-phase1-shell.md) --
# the one-command path from a fresh clone to a running shell:
#
#   git clone <repo-url> && cd covelight && just run
#
# Requires, once, before any of this: the Godot 4.7 editor
# (`brew install --cask godot` or godotengine.org), a Rust toolchain
# (rustup.rs), and `just` itself (`brew install just` or
# github.com/casey/just). See shell/README.md for what each step below
# actually does under the hood, and docs/guides/building-activities.md if
# you're here to build a learning activity rather than work on the shell.

shell_dir := "shell"

# Builds shell/rust/pck_verify (T1.4's GDExtension) and copies the platform
# binary into place -- a hard prerequisite for anything else here:
# shell/scripts/pck_loader.gd references it by name at parse time, so a
# missing binary breaks the whole project's script compilation, not just
# PCK loading (shell/README.md). Safe to re-run any time -- cargo itself is
# incremental, so an unchanged build finishes in well under a second.
_gdextension:
	{{shell_dir}}/rust/build_gdextension.sh

# Registers class_name globals (Shell, ActivityBase, GUT's own, ...) for
# the shell project -- only an editor-mode scan does this, so a fresh
# clone needs it once before anything else there will run. Harmless, fast,
# to re-run.
_import: _gdextension
	godot --headless --path {{shell_dir}} --import

# Launches the shell in a real window. form: phone-portrait (default),
# phone-landscape, or tablet -- the three ratios shell/README.md's
# "Stretch strategy" section documents and was verified against.
# `godot --path shell --resolution WxH` is the same mechanism T1.1 used to
# eyeball each ratio by hand; this just names them so you don't have to
# remember the numbers.
run form="phone-portrait": _import
	#!/usr/bin/env bash
	set -euo pipefail
	case "{{form}}" in
		phone-portrait)  res="1080x2340" ;;
		phone-landscape) res="2340x1080" ;;
		tablet)          res="2048x1536" ;;
		*)
			echo "error: unknown form factor '{{form}}' -- want phone-portrait, phone-landscape, or tablet" >&2
			exit 1
			;;
	esac
	godot --path {{shell_dir}} --resolution "$res"

# Runs the shell's own GUT suite headless. GUT prints "Nothing was run"
# and still exits 0 if a test script fails to *parse* -- this greps for
# the real pass line instead of trusting the exit code, same guard
# .github/workflows/build.yml's godot-test job uses.
test-shell: _import
	#!/usr/bin/env bash
	set -euo pipefail
	godot --headless --path {{shell_dir}} -s addons/gut/gut_cmdln.gd -gexit | tee /tmp/covelight-gut-shell.log
	grep -q "All tests passed!" /tmp/covelight-gut-shell.log

# Runs one activity's own GUT suite headless -- name is a directory under
# /activities (_template, animal_sounds, shape_sorter, color_mixing, or
# your own in progress).
test-activity name: _gdextension
	#!/usr/bin/env bash
	set -euo pipefail
	godot --headless --path "activities/{{name}}" --import
	godot --headless --path "activities/{{name}}" -s addons/gut/gut_cmdln.gd -gexit | tee /tmp/covelight-gut-{{name}}.log
	grep -q "All tests passed!" /tmp/covelight-gut-{{name}}.log

# Runs every test in the repo: the shell's own suite, plus every
# first-party activity's -- mirrors .github/workflows/build.yml's
# godot-test + godot-activity matrix, so "green locally" and "green in CI"
# mean the same thing.
test: test-shell
	#!/usr/bin/env bash
	set -euo pipefail
	for activity in _template animal_sounds shape_sorter color_mixing; do
		just test-activity "$activity"
	done
