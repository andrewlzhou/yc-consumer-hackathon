# Worldscape design language, for porting to Not Yet (iOS)

Source: `worldscape/apps/macos/Sources/Worldscape/` (read-only). Paths below are relative to it:
`DS/` = `DesignSystem/`, `F/` = `Features/`. Intent notes: `worldscape/docs/macos/design-system.md`,
`world.md`, `workspace.md`. Every value here is quoted from code. "iOS:" lines are porting advice,
not source facts. Not read in full: the Metal shaders (`DS/GrainGradient/`, `F/World/WorldLight*`,
`F/Annotations/Art/AnnotationShader.swift`) — only their call sites and docs.

## 1. What carries the look

1. **Dark only, one near-black canvas, kept clean.** `#010101`, no grain or tint on it
   (`DS/Palette.swift:8`, design-system.md:9). There is no light theme anywhere in the code.
2. **One hue family.** Four blues plus white at fixed opacities for all text, fills and strokes
   (`DS/Palette.swift:9-30`). Opacity neutrals read correctly over both black and blue. Red
   `#FF5C7A` is errors only (`:32`).
3. **Only buttons have depth; everything else is flat.** Buttons are physical keys with a side,
   three shadows and a press that sinks them (`DS/Buttons.swift:54-150`). Fields are a 1pt outline
   with no fill and no focus/error highlight (`DS/LabeledField.swift:66-80`). Chat bubbles are flat
   fills with a 0.5pt edge (`F/Chat/MessageColumn.swift:334-352`).
4. **Glass is layered, never a bare material.** Every glass surface is: blur, then a dark or blue
   tint, then a top sheen, then a hairline that is brightest on top, over a blurred shadow shape
   (`F/Chat/AttachmentPill.swift:43-83`, `F/World/WorldCard.swift:159-199`,
   `F/Annotations/ContextBubble.swift:171-213`).
5. **Hairlines are gradients, 0.5-1pt.** Top-lit: bright at the top, faint at the bottom
   (`F/CommandBar/BarSurface.swift:109-124`). Founders rejected a white top rim on blue as
   "janky"; the bar's top rim is accent blue (design-system.md:50).
6. **One typeface, three weights, weight = importance.** Hiragino Sans W6 titles, W5 button
   labels, W4 everything else; large type tightens, small type opens (`DS/Typography.swift:28-57`).
7. **Colour is saved for one place per screen.** The blue gradient appears on the input bar, the
   primary button and the hero panel; lists, settings and chat are near-monochrome. Pills on the
   bar are deliberately never blue (`AttachmentPill.swift:39-42`).
8. **Motion is springy on arrival, absent on exit.** Things rise/ooze in with slight overshoot;
   closing is instant or a short fade (`F/CommandBar/CommandBarMotion.swift:3-10`). Rest state is
   still. A background glow was tried and dropped (design-system.md:52).

Deliberate choices with a recorded owner/date: bar gradient not plain glass (founders, 11-05);
pills = smoky glass, 26pt (11-06); soft outline icons, one even stroke ~8% of box (11-06); world
light "textured and immersive, never a blanket gradient" (11-08); hot pink `#FF2E93` only as
occasional streaks (11-08). Commit history is 6 large commits; these dates come from the docs.

## 2. Tokens

### Colour (dark only)
| Token | Value | Use |
|---|---|---|
| canvas | `#010101` | window background |
| electric | `#005EFF` | primary action, focus |
| iris | `#4A56FF` | secondary |
| ultramarine | `#1500FF` | tertiary, gradient depth |
| glow | `#436FFF` | lightest blue; drag highlight, search match, streaming caret |
| textPrimary / Secondary / Tertiary | white 94% / 62% / 36% | |
| stroke / strokeHover | white 16% / 24% | field outlines |
| danger | `#FF5C7A` | errors only |
| link / linkHover | `#8CA8FF` / `#ADC1FF` | text link on dark glass (`ContextBubble.swift:87-88`) |
| quiet blue label | `#6C8CFF` at 78% | "2 replies" (`MessageColumn.swift:163`) |

Surface fills (white unless noted): plain bar 6%; own bubble 10%; reply bubble black 16%;
list card 3%; row hover 5%; divider 6%; small chips 10% (hover 16%); icon button hover 7-14%.

Primary key: face `#2A78FF → #005EFF → #0052E3` top to bottom; side `#0048CC → #00309A`.
Secondary key: face `#34343A → #24242A`; side `#111114`.
Input bar gradient (`BarSurface.swift:73-100`): horizontal `#0E0FA2 → #1121BE → #0833C4` at 76%
over glass; vertical overlay `#010428`@50% (top) → clear (0.45) → `#2A4FE6`@26% (0.82) →
`#3F64F2`@30%; bottom fog `#DDE6FF` 0→22% over a fixed 30pt, plus three blurred fog ellipses
(8/10/16%, blur 14). Rim: `#6B88FF`@90% → `#93A5E8`@55% → `#5F6C90`@80%, 0.5pt.
Bubbles beside the blue bar: own `#1426B8`@78%, reply `#0B1035`@70%, over glass; edges
`#6B88FF`@45% / `#8C9BE0`@18% (`MessageColumn.swift:589-609`).
Dark overlay glass: `#0D1456 → #070B2C → #020410` diagonal at 78% over blur, top sheen white
6%→0; hairline `#9CB0FF`@45% → white 14% → white 7%, 0.5pt.
Avatar gradients: six blue pairs at 78% with a white 18% top sheen (`F/People/PersonRow.swift:91-121`).

### Materials
- `GlassBackground` = `NSVisualEffectView`, `.behindWindow`, forced dark; `.hudWindow` default,
  `.sidebar` under the bar and blue bubbles (`DS/GlassBackground.swift:6-22`).
- `FrostedShade` = `.hudWindow` + canvas at 40% (`DS/FrostedShade.swift:7-8`): the app background.
- Cards use SwiftUI `.ultraThinMaterial` forced to light scheme at 40% opacity (`WorldCard.swift:178-180`).
- Reduce Transparency fallback is a solid gradient `#12173A → #0B0C12` (`ContextBubble.swift:179-180`).

### Type (`DS/Typography.swift`) — Hiragino Sans, `HiraginoSans-W4/W5/W6`
| Role | Weight | Size | Tracking |
|---|---|---|---|
| wordmark | W6 | variable (56-96 on login) | −0.03 × size |
| statement | W4 | variable (26-34) | −0.012 × size; line spacing 0.3 × size |
| title | W6 | 28 | −0.4 |
| cardTitle | W6 | 14 | −0.1 |
| body | W4 | 14 | 0 |
| button | W5 | 14 | 0.2 |
| item (list rows) | W4 | 13 | 0 |
| label, link | W4 | 12.5 | 0.1 |
| caption | W4 | 12 | 0.1 |
| smallButton | W5 | 12 | 0.2 |
| section | W4 | 11 | 0.3 |
| footnote | W4 | 11 | 0.1 |

Input bar text 17pt W4, line height 24 (`F/CommandBar/CommandBarParts.swift:8-10`). Chat text
14pt, line spacing 8 (`F/Chat/MarkdownText.swift:14-15`). Inline code: system monospaced, size−1,
white 9% background. SF Symbols are sized per use, 7.5-19pt, weight semibold/bold. Hiragino sets
at 1.0 line height, so multi-line text always gets explicit `lineSpacing` (2-8pt).

### Spacing, radii, sizes
There is **no named spacing scale** in code; these are the values actually used.
- Control heights: primary 44, quiet 40, field 44, search 42, small key 28, pill 26, chip 22,
  list row 58, input bar 56 (grows 24/line to 4 lines), avatar 38.
- Padding: fields 14 horizontal; bubbles 16 × 12.5; card 18 leading / 12 trailing / 13 top /
  17 bottom; list row 12 horizontal; bar 26 leading / 13 trailing; panel 10 from window edge.
- Gaps: label→field 9; form fields 18-20; title→form 28; row icon→text 14; pill contents 6-8;
  messages 10 (over bar) or 18 (in app); bubbles within one reply 6.
- Radii (all `.continuous`): keys and fields 10; small key 8; thumbnail 6; list row 12; list card
  14; attachment card 16; glass card and context bubble 20; notice 22; hero panel 28; bubbles
  `fontSize/2 + 12.5` = 19.5 so one line reads as a pill; bar, pills, chips = capsule.
- Card width 248; context bubble 240-360; input bar 600.

### Shadows and strokes
- Primary key base (`Buttons.swift:142-148`): black 45% r1 y1; black 30% r6 y4; electric 20%
  (32% hover) r12 y6. Pressed: r0.5 y0.5; 18% r1.5 y0.5; electric 10% r4 y1. Depth 2pt.
- Label on blue: black 22% r1 y1. Send arrow: `#0A1466`@30% r4 y1.
- Bar: same shape filled `#01061F`@40%, blur 14, offset y8 (a blurred shape, not `.shadow`).
- Pill: black 30%, blur 7, y3. Glass card: `#030836`@30% blur 15 y9 (lit: 42%, 20, 14).
- Hero panel: `#050B5E`@35% r28 y10. List card: black 50% r12 y6.
- Strokes: field 1pt white 16%; bubble 0.5pt; pill 0.75pt gradient white 40→10→18%; card 1pt
  gradient white 40→10%; list card 1pt white 12→5%; icon circles 0.5-1pt white 12-20%.
- Inner shadows are built as stroke + offset + blur + mask (`InsetShadow`, `Buttons.swift:155-168`)
  because animating SwiftUI `.shadow(.inner)` fill styles turned the button white.

## 3. Motion

| What | Curve | Source |
|---|---|---|
| Hover/lit colour change | `.easeOut(0.15)` (0.12 for small ×, 0.2 for primary glow) | everywhere |
| Key press down / release | `.easeOut(0.07)` / `.spring(response: 0.3, dampingFraction: 0.6)` | `Buttons.swift:79-82` |
| Round icon button press | scale 0.9, `.spring(0.2, 0.6)` | `CommandBarParts.swift:118-124` |
| Layout growth (bar, tray) | `.spring(0.3, 0.85)`; `.spring(0.36, 0.84)` | `ChatBar.swift:97-98` |
| Message rises in | `.spring(0.44, 0.84)`; reply delayed 0.22s; from scale 0.92, y+46, opacity 0 | `MessageColumn.swift:26,44,699-708` |
| Streaming text reflow | `.easeOut(0.14)` | `MessageColumn.swift:52` |
| Dots → text in a bubble | `.smooth(duration: 0.28)` | `MessageColumn.swift:308` |
| Disclosure open | `.spring(0.3, 0.86)`; rows `.opacity + offset(y: -4)` | `MessageColumn.swift:393,434` |
| Card arrives | `.spring(0.7, 0.86)` + stagger; from scale 0.92, blur 8, y+18 | `WorldCard.swift:132,143-155` |
| Card hover / press / selected | scale 1.018 / 0.975 / 1.045; springs (0.32,0.78)/(0.26,0.7)/(0.42,0.72) | `WorldCard.swift:78-81` |
| Card idle drift | ±2.5pt y, easeInOut, period 4.2-5.9s, autoreverse | `WorldCard.swift:82,134-136` |
| Card dismissed | rim off instantly, then scale 0.86 + fade, `.spring(0.3, 0.9)`, removed at 240ms | `WorldCard.swift:119-128` |
| Clear/× button appears | scale 0.7→1 + fade, `.spring(0.25, 0.75)` | `WorldCard.swift:240-242` |
| Screen/empty-state swap | `.easeInOut(0.3)` / `.easeInOut(0.45)` | `F/Workspace/ChatStage.swift:34-35` |
| Text value change | `.contentTransition(.numericText())` + `.easeOut(0.25)` | `F/Settings/RowCard.swift:81-82` |
| Input bar arrival | 0.36s "ooze": back-out overshoot 0.8/0.5/1.1; content fades 0.16→0.34s; rim+shadow land over 0.25s; colours drift then still at 1.85s | `CommandBarMotion.swift:12-105` |
| Hero light bloom | 1.3s, bezier (0.5,0)-(0.2,1) | `F/World/WorldBackdrop.swift:10,38` |
| Login intro | 4.6s timeline; "settle" bezier (0.16,1)-(0.3,1) for things landing | `F/Login/LoginIntro.swift:11-17,105-121` |

Loading and streaming states:
- **Thinking:** three 6pt dots, 4.5 apart, hop −3.5pt in turn (0.15s stagger, 1.2s cycle, opacity
  0.4→0.9), optionally followed by the current step in caption/secondary text with a shimmer
  (`MessageColumn.swift:360-381, 612-636`).
- **Shimmer:** a white 55% band, half the text width, sweeping every 1.8s, masked to the text,
  `.plusLighter` (`:639-661`). Off under Reduce Motion.
- **Streaming:** text grows behind an inline 2×12pt caret in `glow`; `.contentTransition(.identity)`
  so words don't cross-fade; the first bubble turns from dots into words in place (`:292-300, 678-687`).
- **Button working:** label fades out, a 15pt arc spinner (trim 0.12-0.82, 1.75pt round stroke,
  0.8s linear) takes its place; the key keeps its size (`Buttons.swift:86-96, 170-184`).
- **Send while replying:** arrow morphs to a 13pt rounded square (stop) with scale 0.6↔1 cross-fade,
  `.spring(0.3, 0.72)` (`ChatBar.swift:140-160`).
- Reduce Motion: fades only, no drift/bloom/shimmer. Increase Contrast doubles hairline strength.

## 4. Component patterns, with iOS notes

**A. Primary key** — `DS/Buttons.swift:54-150`. Base offset down by 2pt, face on top; press moves
the face onto the base and tightens shadows; colours never change.
```swift
ZStack { KeyBase(isPressed:, isGlowing:).offset(y: 2)
         KeyFace(isPressed:).overlay { label }.offset(y: isPressed ? 2 : 0) }
.frame(maxWidth: .infinity).frame(height: 44)
.animation(isPressed ? .easeOut(duration: 0.07) : .spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
```
iOS: ports directly as a `ButtonStyle`. Drop `onHover`/glow-on-hover and `pointingHandCursor`.
44pt already meets the touch minimum; consider 50pt for a main CTA. Add a haptic on press.

**B. Secondary key (28pt), quiet key (40pt outline), link** — `Buttons.swift:186-278`.
iOS: 28pt is too short to tap; keep the look but extend `contentShape` to 44pt or raise to 36pt.
Hover text brightening becomes the pressed state (link already uses opacity 0.6 when pressed).

**C. Outlined field** — `DS/LabeledField.swift:16-44, 66-80`. Label above (12.5pt secondary),
44pt box, `FieldBorder` 1pt white 16%, radius 10, placeholder in tertiary, no focus ring.
iOS: ports directly. Delete `editorBaselineShift` (an AppKit-only fix). No hover state.

**D. Input bar** — `F/CommandBar/ChatBar.swift:67-98` + `BarSurface.swift`. Capsule, 56pt, 17pt
text, send arrow 19pt semibold in a 34pt frame, dim (60%) until there is text. Two fills: blue
gradient with rim (over other content) or white 6% with no rim (inside the app).
```swift
HStack(spacing: 12) { PromptField(...); SendButton(...) }
  .padding(.leading, 26).padding(.trailing, 13)
  .background { BarSurface(fill:, pose:) }
```
iOS: layout ports; the text view is AppKit (`ExpandingTextView`, `GlowingCaret`) and must be
rebuilt with `TextField(axis: .vertical).lineLimit(1...4)`; use `.tint(.white)` instead of the
custom glowing caret unless time allows a UIKit caret. 600pt width → screen width minus 16pt
margins. Send target 34 → 44. The "ooze" arrival (`Canvas` + `.alphaThreshold` + `.blur`,
`CommandBarView.swift:138-153`) uses APIs that exist on iOS, but it is designed for a bar summoned
from a screen edge; skip it unless the bar is summoned. The gradient recipe ports if
`GlassBackground` is swapped for `.ultraThinMaterial` (see G).

**E. Chat bubbles / answer presentation** — `F/Chat/MessageColumn.swift:334-352, 589-609`.
Own messages right, max 80% of column; replies left, max 88%, split into several short bubbles
"the way people text". Above a reply: quiet one-line disclosures ("Searching for…", "Thought for
14s ›") in footnote/tertiary that open to one line per step (`:385-501`). Failures stay in the
bubble: icon + caption + capsule "Try again" chip (22pt, white 10%) (`:504-555`).
```swift
content.padding(.horizontal, 16).padding(.vertical, 12.5)
  .background { BubbleFill(isPerson:, tone:) }.clipShape(shape)
  .overlay { shape.strokeBorder(BubbleFill.edge(isPerson:, tone:), lineWidth: 0.5) }
```
iOS: ports directly (use the `.plain` tone: white 10% / black 16%). Hover-revealed copy button
(`:309-315`) → long-press context menu. Swipe-to-reply is a trackpad gesture; not needed.
14pt chat text is small on a phone; 16-17pt is the usual iOS reading size (advice, not source).

**F. Glass card (best fit for a buy/wait verdict)** — `F/World/WorldCard.swift:45-85, 159-199`.
Header row: 9.5pt symbol + footnote "Kind · 3h ago" at white 68%; title W6 14 (2 lines); detail
caption at white 82% (3 lines).
```swift
shape.fill(Color(hex: 0x030836).opacity(0.3)).blur(radius: 15).offset(y: 9)      // shadow
shape.fill(.ultraThinMaterial).environment(\.colorScheme, .light).opacity(0.4)   // frost
shape.fill(LinearGradient(colors: [.white.opacity(0.11), .white.opacity(0.035)], startPoint: .top, endPoint: .bottom))
shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.1)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
```
iOS: ports directly, and only looks right over a colourful backdrop (it sits on the blue light,
not on black). Hover lift → press scale 0.975. Hover-only × → always-visible × or swipe/context
menu. 248pt width → full width. Keep the rise-in (scale 0.92, blur 8, y+18) and stagger.

**G. Pill / chip glass** — `F/Chat/AttachmentPill.swift:43-83`; `F/CommandBar/ResumePill.swift:13-29`.
26pt capsule: blurred black shadow, blur material, `#080A12`@22% tint, sheen white 12→3→5%,
0.75pt rim white 40→10→18%. Text 12pt W4, tracking 0.1.
iOS: replace `GlassBackground(material: .hudWindow)` with
`Rectangle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark)`. Note the difference:
macOS blurs the desktop behind the window; iOS materials only blur the app's own content, so
glass over the plain `#010101` canvas will look like flat dark grey. Put glass over the gradient
or over content. Raise height to 32-36 for touch.

**H. Dark overlay bubble (tooltip/popover)** — `F/Annotations/ContextBubble.swift:17-49, 171-213`.
Radius 20, inset 15, text 13pt with line spacing 5, max 4 lines, one blue text link, faint 18pt ×.
Scales from the corner nearest its anchor. iOS: ports with the material swap in G; × needs a
44pt hit area (source already pads the hit shape by 4pt).

**I. List card and rows** — `F/Settings/RowCard.swift:32-56`; `F/People/PersonRow.swift:14-46`.
Card: white 3% fill, 1pt gradient border, radius 14, 1pt white 6% dividers inset 62pt.
Row: 58pt, avatar 38, name 13pt primary, summary 11pt secondary · tertiary, trailing time in
tertiary with `.monospacedDigit()`. iOS: ports directly; hover fill → pressed fill.

**J. Empty state** — two forms. New chat: the wordmark debossed into the surface
(`DS/DebossedWordmark.swift:9-20`: black 30% fill, inner shadows, white 7.5% copy offset 1pt
below). Empty list: 22pt light symbol in tertiary, one caption line in secondary, one small
key, 72pt from top, no explanatory paragraph (`F/People/PeopleStage.swift:119-135`).
iOS: both port directly.

**K. Hero gradient** — Metal shaders with grain, 30fps at rest, paused when hidden
(design-system.md:36-44). iOS: Metal runs on iOS but the shaders were not reviewed here, and
they are compiled at launch on macOS. A static approximation is glow → iris → ultramarine with
grain (the docs use this for stills). `MeshGradient` (iOS 18) is a cheaper substitute; the
result will differ from the source and should be judged by eye.

**L. Small icon buttons** — circle, white 7% fill (14% hover), 1pt white 12% ring, 11pt semibold
symbol at 60% (`CommandBarParts.swift:91-115`). Sizes 18-30pt. iOS: keep visual size, pad
`contentShape` to 44pt.

### Does not apply on iOS
Pointer cursors and all `onHover` states; `NSVisualEffectView` behind-window blur; window drag;
keyboard hints ("⌘F", "Esc"); the screen bar summoned over other apps and its full-screen
"tide" shade (`CommandBarView.swift:96-134`); on-screen annotations; two-finger trackpad swipes.

### Open questions for the iOS team
- **Hiragino Sans weights on iOS are unverified.** macOS ships W0-W9; iOS has historically
  shipped fewer (W3, W6, W7). Check `UIFont.fontNames(forFamilyName: "Hiragino Sans")` on a
  device before relying on W4/W5. If missing: bundle a font or map W4→W3, W5→W6.
- Type sizes (11-14pt) were chosen for a Mac at arm's length and are fixed, not Dynamic Type.
  Decide whether to scale up ~2pt and whether to use `.custom(_:size:relativeTo:)`.
- The look depends on blue light behind glass. Decide where the gradient lives in Not Yet
  (verdict screen background, input bar, or both) before building cards.
