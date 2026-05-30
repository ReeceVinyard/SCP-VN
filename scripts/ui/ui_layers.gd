class_name UILayers
extends RefCounted

## Global draw order for the game. Higher CanvasLayer.layer = drawn on top.
## Map characters (Chase, etc.) live on WORLD — always behind dialogue and choices.

const WORLD := 0
const HUD := 5
const DIALOGUE := 10
const CHOICES := 20
const MODALS := 30
const CINEMATIC := 100
