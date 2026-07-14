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

## Minimum side length (project units, same 1080-wide base as SAFE_MARGIN)
## for any interactive element in an activity -- docs/design/activity-sdk.md's
## input API. Deliberately larger than adult-hand accessibility minimums
## (WCAG 2.2 AAA ~44px, Android Material 48dp -- both land around 0.3in
## physical): pre-literate children have coarser motor control than either
## guideline assumes. ~0.4in physical at the same density SAFE_MARGIN was
## sized against -- a design estimate, not a measured one; T1.5's "hand it
## to an actual small child" check is the real validation.
const MIN_TOUCH_TARGET_SIZE: float = 160.0
