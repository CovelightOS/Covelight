extends RefCounted
class_name LayoutConstants

## Safe-margin inset, in project units at the 1080-wide base resolution
## (shell/README.md's "Renderer + stretch" base). Small children rest their
## thumbs on a device's physical edges, so any touch target placed flush
## against the screen edge gets triggered by accident — this is the
## exclusion zone every child-facing element anchors inside of, never
## flush against anchor 0.0/1.0 with a small offset.
##
## Value: ~0.3in of physical margin at typical phone pixel density
## (roughly Android's own edge-gesture exclusion ballpark), i.e. comfortably
## wider than a resting thumb pad, not just a cosmetic gap.
const SAFE_MARGIN: float = 120.0
