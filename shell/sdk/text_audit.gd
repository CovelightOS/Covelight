extends RefCounted
class_name TextAudit

## Recursively scans a live scene tree for any node type that could render
## text to the child -- the mechanical, checkable version of CLAUDE.md #1
## ("no text in the kid-facing UI"). Originally written inline in T1.2's
## crash-containment test (shell/tests/test_shell_state_machine.gd); pulled
## into the SDK so the same check runs identically in the shell's own
## tests, an activity's own tests (see /activities/_template/tests), and
## `tools/lint_activity.sh`'s static pass -- one definition of "text-
## capable," not three that can drift apart.
##
## Honest limitation: this walks node *types*, so it catches every built-in
## Godot control that displays a string (Label, Button, ...), but it cannot
## catch text rendered outside the node-type system -- a custom `_draw()`
## call to `draw_string()`, or a pre-rendered image of text used as a
## Sprite2D texture. Those are real gaps; `docs/guides/activity-review.md`
## asks a human reviewer to actually look at the activity for exactly this
## reason -- this scan narrows what a reviewer has to check by hand, it
## doesn't replace them.

## Godot built-in node types that render or accept text. Checked by `is`,
## not by class-name string, so a scripted subclass of any of these is
## still caught.
static func find_text_nodes(root: Node) -> Array[Node]:
	var found: Array[Node] = []
	_walk(root, found)
	return found

static func _walk(node: Node, found: Array[Node]) -> void:
	if _is_text_capable(node):
		found.append(node)
	for child in node.get_children():
		_walk(child, found)

static func _is_text_capable(node: Node) -> bool:
	return node is Label or node is RichTextLabel or node is Button \
		or node is LinkButton or node is MenuButton or node is LineEdit \
		or node is TextEdit or node is OptionButton or node is SpinBox \
		or node is ItemList or node is Tree or node is AcceptDialog \
		or node is PopupMenu or node is TabBar or node is TabContainer
