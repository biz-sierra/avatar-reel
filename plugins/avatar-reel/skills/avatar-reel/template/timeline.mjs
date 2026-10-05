// THE EDIT. One row per cut: [start, MODE, source, opts]. Start = at("spoken phrase") so a new VO never breaks the timing.
//   FULL  — face fills frame. opts: zoom (1.14 punch-in), grey (true), ui ("igui" parody-reel overlay for a bad-example beat)
//   SPLIT — panel on top (0-640), face below. source = gfx scene name | "lib:<library clip>" | "clip:<clips/ file>" | "broll:<your own clip>" | "replay"
//   CUT   — full-frame b-roll: "broll:<your clip>" | "lib:..." | "clip:..."
// opts: ss (clip start sec) · key (unique output name when a scene is used twice) · scene (scene to render under that key)
//       any scene param as "@phrase" = seconds from this cut's start to that phrase (e.g. { off: "@invisible" })
// Full worked example: ../examples/ai-gate-break/timeline.mjs (in the skill folder)
import { at, build } from "./reel-lib.mjs";
export const { segs, END } = build([
  [0,                    "FULL"],
  // [at("first beat"),  "SPLIT", "switch", { off: "@invisible" }],
]);
