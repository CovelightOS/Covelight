# Activity template

Copy this whole directory to start a new activity. Full contract:
`docs/design/activity-sdk.md`.

```sh
cp -r activities/_template activities/your_activity_name
cd activities/your_activity_name
ln -sf ../../../shell/sdk addons/covelight_sdk       # if the copy didn't preserve symlinks
ln -sf ../../../shell/addons/gut addons/gut           # same
```

Then:

1. Edit `manifest.cfg` — set a real `id` (this becomes your `.pck`'s
   filename and the key your progress data is stored under; don't change
   it after publishing).
2. Replace `activity.tscn` / `activity.gd` with your actual activity. Keep
   extending `res://addons/covelight_sdk/activity_base.gd` by path.
3. Keep every interactive element inset by at least
   `LayoutConstants.SAFE_MARGIN` and sized at least
   `LayoutConstants.MIN_TOUCH_TARGET_SIZE` — `TouchTarget`/`Draggable`
   already default to the size; you're responsible for the inset.
4. Run your own tests (`tests/test_activity_template.gd` is the pattern to
   copy) before opening a PR — `docs/guides/activity-review.md` is what a
   reviewer checks next.

```sh
godot --headless --path . --import   # once, on a fresh checkout -- registers class_name globals
godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit
```
