## Godot 4 GDExtension tabletop renderer & input controller for Props & Proofs (Modern & Modal Logic).

import std/[math, strformat, strutils, times]
import gdext
import gdext/classes/[
  gdengine,
  gdnode,
  gdnode2d,
  gdcanvasitem,
  gddisplayserver,
  gdinputevent,
  gdinputeventmousebutton,
  gdinputeventmousemotion,
  gdinputeventkey,
  gdthemedb,
  gdfont,
]

import ../sim/[types, logic, proof, curriculum, game, presenter]

type PropsAndProofsController* {.gdsync.} = ptr object of Node2D
  presenter: WffPresenter
  headless: bool

proc toGdColor(c: Rgba): Color {.inline.} =
  color(c.r, c.g, c.b, c.a)

proc toGdRect(rc: UiRect): Rect2 {.inline.} =
  rect2(rc.x, rc.y, rc.w, rc.h)

proc drawText(
  self: PropsAndProofsController;
  font: gdref Font;
  x, y: float;
  txt: string;
  size: int32 = 14;
  col: Color = color(0.95, 0.92, 0.84, 1.0);
  maxW: float = -1.0;
  align: HorizontalAlignment = horizontalAlignmentLeft;
  shadow: bool = false;
) =
  if font[].isNil or txt.len == 0:
    return
  let gStr = newGdString(txt)
  if shadow:
    self.drawString(font, vector2(x + 1.0, y + 1.5), gStr, align, maxW, size, color(0.03, 0.03, 0.04, 0.85))
  self.drawString(font, vector2(x, y), gStr, align, maxW, size, col)

proc drawWrappedText(
  self: PropsAndProofsController;
  font: gdref Font;
  x, y, maxW: float;
  txt: string;
  size: int32 = 13;
  col: Color = color(0.90, 0.88, 0.80, 1.0);
  lineStep: float = 19.0;
): float =
  let charsPerLine = max(24, int(maxW / (float(size) * 0.56)))
  var curY = y
  var line = ""
  for word in txt.splitWhitespace():
    if line.len == 0:
      line = word
    elif line.len + 1 + word.len <= charsPerLine:
      line.add(' ')
      line.add(word)
    else:
      self.drawText(font, x, curY, line, size, col)
      curY += lineStep
      line = word
  if line.len > 0:
    self.drawText(font, x, curY, line, size, col)
    curY += lineStep
  curY

proc drawCard(self: PropsAndProofsController; rc: UiRect; bg, border: Color; bw: float = 1.8) =
  let gr = rc.toGdRect()
  self.drawRect(gr, bg, filled = true)
  self.drawRect(gr, border, filled = false, width = bw)

proc drawLogicCube(
  self: PropsAndProofsController;
  font: gdref Font;
  rc: UiRect;
  sym: Symbol;
  hovered: bool = false;
  selected: bool = false;
) =
  let base = cubeColor(sym)
  # Drop shadow
  self.drawRect(rect2(rc.x + 3.0, rc.y + 4.0, rc.w, rc.h), color(0.02, 0.03, 0.03, 0.55), filled = true)
  # Main cube face
  let fillCol =
    if hovered: color(min(1.0, base.r + 0.12), min(1.0, base.g + 0.12), min(1.0, base.b + 0.12), 1.0)
    else: base.toGdColor()
  self.drawRect(rc.toGdRect(), fillCol, filled = true)
  # Top bevel highlight
  self.drawRect(rect2(rc.x + 2.0, rc.y + 2.0, rc.w - 4.0, 4.0), color(1.0, 1.0, 1.0, 0.22), filled = true)
  # Border
  let borderCol =
    if selected: color(0.98, 0.84, 0.28, 1.0)
    elif hovered: color(0.96, 0.92, 0.78, 0.95)
    else: color(0.84, 0.76, 0.58, 0.70)
  let bw = if selected: 3.2 else: 1.6
  self.drawRect(rc.toGdRect(), borderCol, filled = false, width = bw)

  # Polish symbol (top-left bold) + modern/modal glyph (bottom-right)
  let pChar = $sym.polishChar()
  let glyph = sym.modernGlyph()
  let bigSz = if rc.w >= 54.0: 22'i32 else: 18'i32
  self.drawText(font, rc.x + 8.0, rc.y + float(bigSz) + 4.0, pChar, bigSz, color(0.99, 0.97, 0.92, 1.0), shadow = true)
  if glyph != pChar:
    let subSz = if rc.w >= 54.0: 16'i32 else: 13'i32
    self.drawText(font, rc.x + rc.w - 22.0, rc.y + rc.h - 8.0, glyph, subSz, color(0.95, 0.88, 0.62, 0.95), shadow = true)

proc drawButtons(self: PropsAndProofsController; font: gdref Font) =
  let p = self.presenter
  for b in p.buttons:
    let hov = b.enabled and p.hoverBtnId == b.id
    var bg, border, txtCol: Color
    case b.style
    of bsPrimary:
      bg = if not b.enabled: color(0.16, 0.22, 0.19, 0.55)
           elif hov: color(0.18, 0.54, 0.36, 1.0)
           else: color(0.14, 0.44, 0.29, 0.96)
      border = color(0.62, 0.90, 0.72, if b.enabled: 0.90 else: 0.30)
      txtCol = color(0.96, 0.99, 0.96, if b.enabled: 1.0 else: 0.45)
    of bsAccent:
      bg = if not b.enabled: color(0.24, 0.21, 0.14, 0.55)
           elif hov: color(0.76, 0.56, 0.18, 1.0)
           else: color(0.62, 0.44, 0.13, 0.96)
      border = color(0.98, 0.86, 0.52, if b.enabled: 0.95 else: 0.30)
      txtCol = color(0.99, 0.97, 0.90, if b.enabled: 1.0 else: 0.45)
    of bsDanger:
      bg = if not b.enabled: color(0.26, 0.14, 0.14, 0.55)
           elif hov: color(0.72, 0.22, 0.20, 1.0)
           else: color(0.56, 0.17, 0.16, 0.96)
      border = color(0.96, 0.64, 0.58, if b.enabled: 0.90 else: 0.30)
      txtCol = color(0.99, 0.94, 0.92, if b.enabled: 1.0 else: 0.45)
    of bsActiveTab:
      bg = color(0.20, 0.35, 0.52, 0.98)
      border = color(0.62, 0.84, 0.98, 0.98)
      txtCol = color(0.96, 0.99, 1.0, 1.0)
    of bsInactiveTab:
      bg = if hov: color(0.18, 0.24, 0.22, 0.95) else: color(0.11, 0.16, 0.14, 0.92)
      border = color(0.42, 0.50, 0.46, 0.65)
      txtCol = color(0.84, 0.86, 0.82, 0.92)
    of bsSecondary:
      bg = if not b.enabled: color(0.14, 0.16, 0.16, 0.50)
           elif hov: color(0.24, 0.30, 0.28, 0.98)
           else: color(0.17, 0.22, 0.20, 0.95)
      border = color(0.60, 0.66, 0.62, if b.enabled: 0.78 else: 0.28)
      txtCol = color(0.92, 0.92, 0.88, if b.enabled: 1.0 else: 0.45)

    self.drawCard(b.rc, bg, border, if hov: 2.2 else: 1.4)
    let fontSz = if b.rc.h <= 30.0: 12'i32 else: 13'i32
    self.drawText(
      font,
      b.rc.x + 4.0,
      b.rc.y + b.rc.h * 0.5 + float(fontSz) * 0.36,
      b.label,
      fontSz,
      txtCol,
      b.rc.w - 8.0,
      horizontalAlignmentCenter,
      shadow = true,
    )

proc drawKripkeModel(self: PropsAndProofsController; font: gdref Font; rc: UiRect; km: KripkeModel; ms: ModalSystem) =
  self.drawCard(rc, color(0.08, 0.11, 0.14, 0.95), color(0.34, 0.52, 0.70, 0.75), 1.4)
  self.drawText(
    font,
    rc.x + 12.0,
    rc.y + 20.0,
    fmt"KRIPKE COUNTERMODEL IN {systemShortName(ms)} ({km.worldCount} world(s) — fails at w{km.failingWorld})",
    12,
    color(0.98, 0.72, 0.48, 1.0),
  )

  let n = max(1, km.worldCount)
  var posX: array[4, float]
  var posY: array[4, float]
  let cy = rc.y + rc.h * 0.56
  for i in 0 ..< n:
    posX[i] = rc.x + (rc.w / float(n + 1)) * float(i + 1)
    posY[i] = cy + (if n == 3 and i == 1: -22.0 else: 8.0)

  # Draw accessibility relation arrows R
  let radius = 26.0
  for edge in km.edges:
    let (u, v) = edge
    if u == v:
      # Reflexive self-loop arc above the world
      self.drawArc(
        vector2(posX[u], posY[u] - radius - 10.0),
        14.0,
        0.0,
        PI * 2.0,
        24,
        color(0.56, 0.80, 0.98, 0.85),
        1.8,
      )
    else:
      let dx = posX[v] - posX[u]
      let dy = posY[v] - posY[u]
      let dist = max(1.0, hypot(dx, dy))
      let ux = dx / dist
      let uy = dy / dist
      let sx = posX[u] + ux * (radius + 2.0)
      let sy = posY[u] + uy * (radius + 2.0)
      let ex = posX[v] - ux * (radius + 4.0)
      let ey = posY[v] - uy * (radius + 4.0)
      self.drawLine(vector2(sx, sy), vector2(ex, ey), color(0.68, 0.86, 0.98, 0.90), 2.0)
      # Arrowhead
      let px = -uy
      let py = ux
      self.drawLine(vector2(ex, ey), vector2(ex - ux * 9.0 + px * 5.0, ey - uy * 9.0 + py * 5.0), color(0.68, 0.86, 0.98, 0.95), 2.0)
      self.drawLine(vector2(ex, ey), vector2(ex - ux * 9.0 - px * 5.0, ey - uy * 9.0 - py * 5.0), color(0.68, 0.86, 0.98, 0.95), 2.0)

  # Draw world circles & truth valuations
  for w in km.worlds:
    let cx = posX[w.id]
    let cyW = posY[w.id]
    let fail = w.id == km.failingWorld
    let fillC = if fail: color(0.56, 0.14, 0.16, 0.96) else: color(0.15, 0.28, 0.42, 0.96)
    let rimC = if fail: color(0.98, 0.56, 0.48, 1.0) else: color(0.62, 0.84, 0.98, 0.95)
    self.drawCircle(vector2(cx, cyW), radius, fillC)
    self.drawArc(vector2(cx, cyW), radius, 0.0, PI * 2.0, 32, rimC, 2.2)
    self.drawText(font, cx - 12.0, cyW + 5.0, fmt"w{w.id}", 14, color(0.98, 0.98, 0.96, 1.0), shadow = true)
    let pTag = if w.pVal: "p:T" else: "p:F"
    let qTag = if w.qVal: " q:T" else: " q:F"
    let fTag = if w.formulaVal: "φ:T" else: "φ:F"
    self.drawText(font, cx - 34.0, cyW + radius + 16.0, pTag & qTag, 11, color(0.84, 0.90, 0.94, 0.95))
    self.drawText(
      font,
      cx - 16.0,
      cyW + radius + 30.0,
      fTag,
      11,
      if w.formulaVal: color(0.48, 0.92, 0.62, 1.0) else: color(0.98, 0.52, 0.48, 1.0),
    )

proc drawFormulaInspector(
  self: PropsAndProofsController;
  font: gdref Font;
  rc: UiRect;
  syms: openArray[Symbol];
  ms: ModalSystem;
) =
  self.drawCard(rc, color(0.10, 0.14, 0.13, 0.96), color(0.46, 0.60, 0.52, 0.80))
  self.drawText(font, rc.x + 14.0, rc.y + 24.0, "LIVE FORMULA INSPECTOR (POLISH ↔ MODERN ↔ SEMANTICS)", 13, color(0.94, 0.84, 0.56, 1.0), shadow = true)

  let parsed = parseWff(syms)
  if not parsed.isWff:
    let tr = polishSlotTrace(syms)
    self.drawText(font, rc.x + 14.0, rc.y + 54.0, "Status: Building Formula (Not Yet Complete)", 14, color(0.96, 0.72, 0.44, 1.0))
    var curY = self.drawWrappedText(font, rc.x + 14.0, rc.y + 78.0, rc.w - 28.0, parsed.errorMsg, 13, color(0.88, 0.86, 0.80, 0.96))

    # Live Polish Slot Tracker card
    curY += 8.0
    let slotRc = uiRect(rc.x + 14.0, curY, rc.w - 28.0, 96.0)
    self.drawCard(slotRc, color(0.08, 0.13, 0.16, 0.96), color(0.46, 0.72, 0.88, 0.82), 1.4)
    self.drawText(font, slotRc.x + 12.0, slotRc.y + 20.0, "LIVE POLISH SLOT TRACKER (Start at 1; Binary +1, Unary +0, Atom -1)", 11, color(0.68, 0.88, 0.98, 1.0))
    discard self.drawWrappedText(font, slotRc.x + 12.0, slotRc.y + 42.0, slotRc.w - 24.0, tr.summary, 13, color(0.96, 0.94, 0.86, 1.0), 17.0)
    discard self.drawWrappedText(font, slotRc.x + 12.0, slotRc.y + 78.0, slotRc.w - 24.0, "Trace: " & tr.trace, 11, color(0.70, 0.86, 0.78, 0.92), 15.0)
    curY = slotRc.y + slotRc.h + 14.0

    # Symbol & Connective Quick Reference (always visible while building if space permits)
    if curY + 210.0 <= rc.y + rc.h:
      let refRc = uiRect(rc.x + 14.0, curY, rc.w - 28.0, min(236.0, rc.y + rc.h - curY - 12.0))
      self.drawCard(refRc, color(0.09, 0.12, 0.11, 0.94), color(0.48, 0.58, 0.50, 0.72), 1.2)
      self.drawText(font, refRc.x + 12.0, refRc.y + 22.0, "SYMBOL QUICK REFERENCE (POLISH PREFIX NOTATION)", 12, color(0.94, 0.84, 0.56, 1.0))
      let refLines = [
        "Atoms (fills 1 slot):     p, q, r, s   — basic true/false claims",
        "Unary (+0 slots, 1 WFF):  N (¬ not)    — e.g. Np = ¬p",
        "Binary (+1 slot, 2 WFFs): C (→ if-then) — Cpq = (p → q)",
        "                          K (∧ and)     — Kpq = (p ∧ q)",
        "                          A (∨ or)      — Apq = (p ∨ q)",
        "                          E (↔ iff)     — Epq = (p ↔ q)",
        "Modal (+0 slots, 1 WFF):  L (□ necessarily) — true in ALL reachable worlds",
        "                          M (◇ possibly)    — true in SOME reachable world",
        "Reading tip: Operator first, then 1st WFF, then 2nd WFF. Zero parentheses!",
      ]
      var ry = refRc.y + 44.0
      for ln in refLines:
        if ry + 14.0 > refRc.y + refRc.h: break
        self.drawText(font, refRc.x + 12.0, ry, ln, 12, color(0.86, 0.90, 0.86, 0.95))
        ry += 21.0
    return

  self.drawText(font, rc.x + 14.0, rc.y + 52.0, fmt"Polish:  {parsed.polish}", 16, color(0.56, 0.94, 0.72, 1.0), shadow = true)
  self.drawText(font, rc.x + 14.0, rc.y + 78.0, fmt"Modern:  {parsed.infix}", 16, color(0.76, 0.90, 1.0, 1.0), shadow = true)
  let nextY = self.drawWrappedText(font, rc.x + 14.0, rc.y + 104.0, rc.w - 28.0, "English: " & parsed.english, 13, color(0.90, 0.88, 0.80, 0.96))

  let famous = describeFamousAxiom(parsed.polish)
  var curY = nextY + 4.0
  if famous.len > 0:
    self.drawCard(uiRect(rc.x + 14.0, curY, rc.w - 28.0, 28.0), color(0.24, 0.20, 0.08, 0.95), color(0.94, 0.78, 0.34, 0.90), 1.2)
    self.drawText(font, rc.x + 22.0, curY + 19.0, "Famous Law: " & famous, 12, color(0.99, 0.92, 0.62, 1.0))
    curY += 36.0

  # Validity badges across Prop / K / T / S4 / S5
  self.drawText(font, rc.x + 14.0, curY + 14.0, "Validity Across Logic Systems:", 12, color(0.82, 0.86, 0.84, 0.95))
  curY += 22.0
  let badgeW = (rc.w - 28.0 - 4.0 * 6.0) / 5.0
  var activeCheck: ModalCheckResult
  for i, sys in [msProp, msK, msT, msS4, msS5]:
    let chk = checkModalValidity(parsed.root, sys)
    if sys == ms:
      activeCheck = chk
    let bx = rc.x + 14.0 + float(i) * (badgeW + 6.0)
    let bg = if chk.valid: color(0.13, 0.38, 0.24, 0.95) else: color(0.32, 0.14, 0.14, 0.92)
    let bd = if sys == ms: color(0.98, 0.86, 0.42, 1.0) else: color(0.50, 0.56, 0.54, 0.65)
    self.drawCard(uiRect(bx, curY, badgeW, 42.0), bg, bd, if sys == ms: 2.2 else: 1.2)
    self.drawText(font, bx + 4.0, curY + 17.0, systemShortName(sys), 12, color(0.96, 0.96, 0.94, 1.0), badgeW - 8.0, horizontalAlignmentCenter)
    let tag = if chk.valid: "VALID" else: "INVALID"
    self.drawText(font, bx + 4.0, curY + 34.0, tag, 11, if chk.valid: color(0.62, 0.98, 0.74, 1.0) else: color(0.98, 0.66, 0.62, 1.0), badgeW - 8.0, horizontalAlignmentCenter)
  curY += 54.0

  if not parsed.hasModal and ms == msProp:
    let tt = evalTruthTable(parsed.root)
    let verdict =
      if tt.isTautology: "TAUTOLOGY (True in all rows)"
      elif tt.isContradiction: "CONTRADICTION (False in all rows)"
      else: "CONTINGENT (Mixed T/F)"
    self.drawText(font, rc.x + 14.0, curY + 14.0, "Truth Table — " & verdict, 13, color(0.92, 0.86, 0.66, 1.0))
    curY += 24.0
    var hdr = ""
    for a in tt.atoms:
      hdr.add(fmt" {a.polishChar()} |")
    hdr.add("  φ")
    self.drawText(font, rc.x + 16.0, curY + 12.0, hdr, 12, color(0.76, 0.90, 0.96, 1.0))
    curY += 18.0
    let maxRows = min(tt.rows.len, 8)
    for rIdx in 0 ..< maxRows:
      let row = tt.rows[rIdx]
      var rStr = ""
      for aIdx in 0 ..< tt.atoms.len:
        let b = ((row.bits shr (tt.atoms.len - 1 - aIdx)) and 1) == 1
        rStr.add(if b: " T |" else: " F |")
      rStr.add(if row.value: "  T" else: "  F")
      let col = if row.value: color(0.60, 0.94, 0.72, 1.0) else: color(0.94, 0.60, 0.56, 1.0)
      self.drawText(font, rc.x + 16.0, curY + 12.0, rStr, 12, col)
      curY += 17.0
  elif activeCheck.hasCountermodel:
    let kmRc = uiRect(rc.x + 14.0, curY, rc.w - 28.0, max(150.0, rc.y + rc.h - curY - 14.0))
    self.drawKripkeModel(font, kmRc, activeCheck.countermodel, ms)
  else:
    let kCheck = checkModalValidity(parsed.root, msK)
    if kCheck.hasCountermodel:
      self.drawText(font, rc.x + 14.0, curY + 14.0, activeCheck.summary, 13, color(0.58, 0.96, 0.72, 1.0))
      let kmRc = uiRect(rc.x + 14.0, curY + 24.0, rc.w - 28.0, max(145.0, rc.y + rc.h - curY - 38.0))
      self.drawKripkeModel(font, kmRc, kCheck.countermodel, msK)
    else:
      discard self.drawWrappedText(font, rc.x + 14.0, curY + 18.0, rc.w - 28.0, activeCheck.summary, 13, color(0.58, 0.96, 0.72, 1.0))

proc drawAcademy(self: PropsAndProofsController; font: gdref Font) =
  let p = self.presenter
  let lp = p.leftPanelRect()
  let rp = p.rightPanelRect()
  let lesson = Lessons[p.game.lessonIdx]

  self.drawCard(lp, color(0.11, 0.16, 0.14, 0.96), color(0.46, 0.60, 0.52, 0.80))
  self.drawText(font, lp.x + 18.0, lp.y + 26.0, fmt"ACADEMY • {lesson.track} ({p.game.lessonIdx + 1}/{Lessons.len})", 14, color(0.96, 0.84, 0.52, 1.0), shadow = true)
  self.drawText(font, lp.x + 18.0, lp.y + 98.0, lesson.title, 18, color(0.98, 0.96, 0.90, 1.0), shadow = true)

  discard self.drawWrappedText(font, lp.x + 18.0, lp.y + 122.0, lp.w - 36.0, lesson.explanation, 13, color(0.88, 0.90, 0.86, 0.96), 18.0)

  # Worked Breakdown / How It Works card
  let wtRc = uiRect(lp.x + 18.0, lp.y + 204.0, lp.w - 36.0, 78.0)
  self.drawCard(wtRc, color(0.10, 0.15, 0.21, 0.95), color(0.46, 0.68, 0.86, 0.80), 1.3)
  self.drawText(font, wtRc.x + 10.0, wtRc.y + 18.0, "WORKED BREAKDOWN:", 11, color(0.68, 0.88, 0.98, 1.0))
  discard self.drawWrappedText(font, wtRc.x + 10.0, wtRc.y + 36.0, wtRc.w - 20.0, lesson.walkthrough, 12, color(0.92, 0.94, 0.96, 0.96), 17.0)

  # Objective card
  let objRc = uiRect(lp.x + 18.0, lp.y + 292.0, lp.w - 36.0, 62.0)
  self.drawCard(objRc, color(0.15, 0.24, 0.20, 0.95), color(0.56, 0.84, 0.66, 0.85), 1.4)
  self.drawText(font, objRc.x + 10.0, objRc.y + 18.0, "OBJECTIVE:", 11, color(0.64, 0.96, 0.76, 1.0))
  discard self.drawWrappedText(font, objRc.x + 10.0, objRc.y + 36.0, objRc.w - 20.0, lesson.task, 13, color(0.96, 0.96, 0.92, 1.0), 17.0)

  self.drawText(font, lp.x + 22.0, lp.y + 378.0, "CLICK CUBES BELOW (OR TYPE p,q,r,s,N,C,K,A,E,L,M):", 11, color(0.84, 0.80, 0.64, 0.95))
  for i, ch in p.cubeHits:
    self.drawLogicCube(font, ch.rc, ch.sym, hovered = (i == p.hoverCubeIdx))

  # Workspace tray with live slot badge
  let trayRc = uiRect(lp.x + 18.0, lp.y + 454.0, lp.w - 36.0, 86.0)
  self.drawCard(trayRc, color(0.07, 0.10, 0.09, 0.96), color(0.74, 0.62, 0.34, 0.85), 1.6)
  let slotInfo = polishSlotTrace(p.game.academyWorkspace)
  let slotTag =
    if slotInfo.completeAt == p.game.academyWorkspace.len and p.game.academyWorkspace.len > 0: "Open slots: 0 (Complete WFF)"
    elif slotInfo.completeAt >= 0: "Extra cubes after complete WFF!"
    else: fmt"Open slots: {slotInfo.openSlots}"
  let slotCol =
    if slotInfo.completeAt == p.game.academyWorkspace.len and p.game.academyWorkspace.len > 0: color(0.56, 0.96, 0.72, 1.0)
    elif slotInfo.completeAt >= 0: color(0.98, 0.56, 0.50, 1.0)
    else: color(0.94, 0.82, 0.52, 0.95)
  self.drawText(font, trayRc.x + 12.0, trayRc.y + 18.0, "YOUR FORMULA WORKSPACE:", 11, color(0.84, 0.78, 0.60, 0.90))
  self.drawText(font, trayRc.x + 210.0, trayRc.y + 18.0, slotTag, 11, slotCol)
  for i, sym in p.game.academyWorkspace:
    let cRc = uiRect(trayRc.x + 12.0 + float(i) * 52.0, trayRc.y + 26.0, 46.0, 46.0)
    self.drawLogicCube(font, cRc, sym)

  # Feedback & hint banner
  let fbY = trayRc.y + trayRc.h + 12.0
  let fbH = if p.game.showHint: 100.0 else: 70.0
  let fbBg = if p.game.academySolved: color(0.12, 0.34, 0.22, 0.96) else: color(0.16, 0.18, 0.20, 0.95)
  let fbBd = if p.game.academySolved: color(0.54, 0.96, 0.70, 0.95) else: color(0.52, 0.58, 0.62, 0.75)
  self.drawCard(uiRect(lp.x + 18.0, fbY, lp.w - 36.0, fbH), fbBg, fbBd, 1.4)
  let afterFbY = self.drawWrappedText(font, lp.x + 28.0, fbY + 22.0, lp.w - 56.0, p.game.academyFeedback, 13, color(0.98, 0.96, 0.90, 1.0), 17.0)
  if p.game.showHint:
    discard self.drawWrappedText(font, lp.x + 28.0, max(fbY + 56.0, afterFbY + 4.0), lp.w - 56.0, "Hint: " & lesson.hint, 12, color(0.98, 0.88, 0.56, 1.0), 16.0)

  # Why It Matters takeaway card
  let whyY = fbY + fbH + 10.0
  let whyMaxH = (lp.y + lp.h - 64.0) - whyY
  if whyMaxH >= 48.0:
    let whyRc = uiRect(lp.x + 18.0, whyY, lp.w - 36.0, min(72.0, whyMaxH))
    self.drawCard(whyRc, color(0.14, 0.14, 0.10, 0.94), color(0.76, 0.66, 0.36, 0.75), 1.2)
    self.drawText(font, whyRc.x + 10.0, whyRc.y + 18.0, "WHY THIS MATTERS IN GAMEPLAY:", 11, color(0.96, 0.84, 0.50, 1.0))
    discard self.drawWrappedText(font, whyRc.x + 10.0, whyRc.y + 35.0, whyRc.w - 20.0, lesson.whyItMatters, 12, color(0.90, 0.88, 0.80, 0.94), 16.0)

  self.drawFormulaInspector(font, rp, p.game.academyWorkspace, lesson.system)

proc drawWffGame(self: PropsAndProofsController; font: gdref Font) =
  let p = self.presenter
  let lp = p.leftPanelRect()
  let rp = p.rightPanelRect()

  self.drawCard(lp, color(0.11, 0.16, 0.14, 0.96), color(0.46, 0.60, 0.52, 0.80))
  self.drawText(font, lp.x + 18.0, lp.y + 30.0, fmt"WFF GAME (DICE SPRINT) — Round {p.game.sprintRound}", 17, color(0.98, 0.88, 0.58, 1.0), shadow = true)
  self.drawText(
    font,
    lp.x + 18.0,
    lp.y + 56.0,
    fmt"Score — You: {p.game.sprintScoreHuman} pts   |   Logician AI: {p.game.sprintScoreAi} pts   |   System: {systemShortName(p.game.modalSystem)}",
    13,
    color(0.76, 0.94, 0.84, 1.0),
  )
  self.drawText(font, lp.x + 22.0, lp.y + 110.0, "ROLLED DICE POOL (Click a cube to move it into your WFF):", 12, color(0.88, 0.84, 0.68, 0.95))
  var wsSyms: seq[Symbol] = @[]
  for c in p.game.sprintWorkspace:
    wsSyms.add(c.sym)
  let spSlots = polishSlotTrace(wsSyms)
  self.drawText(font, lp.x + 22.0, lp.y + 330.0, fmt"YOUR WFF TRAY ({spSlots.summary}):", 12, color(0.68, 0.94, 0.78, 0.95))

  for i, ch in p.cubeHits:
    self.drawLogicCube(font, ch.rc, ch.sym, hovered = (i == p.hoverCubeIdx))

  let resRc = uiRect(lp.x + 18.0, lp.y + 490.0, lp.w - 36.0, 110.0)
  self.drawCard(resRc, color(0.08, 0.12, 0.11, 0.96), color(0.64, 0.56, 0.32, 0.85), 1.4)
  discard self.drawWrappedText(font, resRc.x + 14.0, resRc.y + 26.0, resRc.w - 28.0, p.game.sprintResultMsg, 13, color(0.96, 0.94, 0.86, 1.0))
  if p.game.sprintSubmitted:
    self.drawText(font, resRc.x + 14.0, resRc.y + 82.0, "Logician AI Solution: " & p.game.sprintAiBest, 13, color(0.70, 0.90, 1.0, 1.0))

  self.drawFormulaInspector(font, rp, wsSyms, p.game.modalSystem)

proc drawProofMat(self: PropsAndProofsController; font: gdref Font) =
  let p = self.presenter
  let lp = p.leftPanelRect()
  let rp = p.rightPanelRect()

  self.drawCard(lp, color(0.10, 0.16, 0.13, 0.96), color(0.50, 0.64, 0.54, 0.80))
  self.drawText(font, lp.x + 18.0, lp.y + 28.0, fmt"PROPS & PROOFS 3-ZONE MAT — Round {p.game.matRound}", 17, color(0.98, 0.88, 0.58, 1.0), shadow = true)
  self.drawText(
    font,
    lp.x + 18.0,
    lp.y + 54.0,
    fmt"Match Score — You: {p.game.matHumanScore}   |   Logician AI: {p.game.matAiScore}   |   {$p.game.matPhase}",
    13,
    color(0.76, 0.94, 0.84, 1.0),
  )

  # Goal banner
  self.drawCard(uiRect(lp.x + 18.0, lp.y + 68.0, lp.w - 36.0, 38.0), color(0.22, 0.18, 0.08, 0.95), color(0.92, 0.74, 0.30, 0.90), 1.4)
  self.drawText(font, lp.x + 28.0, lp.y + 92.0, "GOAL: " & p.game.matGoal, 13, color(0.99, 0.94, 0.72, 1.0))

  self.drawText(font, lp.x + 22.0, lp.y + 124.0, "RESOURCES (Select a cube, then place it in Required / Permitted / Forbidden):", 12, color(0.86, 0.84, 0.72, 0.95))
  for i, ch in p.cubeHits:
    self.drawLogicCube(font, ch.rc, ch.sym, hovered = (i == p.hoverCubeIdx), selected = ch.selected)

  # Draw the 3 Mat Zones side by side
  let zw = (lp.w - 56.0) / 3.0
  let zy = lp.y + 318.0
  let zh = 220.0
  let zones = [
    (mzRequired, "REQUIRED (Must Use)", color(0.10, 0.24, 0.17, 0.95), color(0.46, 0.86, 0.62, 0.88)),
    (mzPermitted, "PERMITTED (May Use)", color(0.22, 0.19, 0.10, 0.95), color(0.88, 0.74, 0.36, 0.88)),
    (mzForbidden, "FORBIDDEN (Cannot Use)", color(0.26, 0.11, 0.11, 0.95), color(0.92, 0.48, 0.44, 0.88)),
  ]
  for zIdx, zInfo in zones:
    let (zone, title, bg, bd) = zInfo
    let zx = lp.x + 18.0 + float(zIdx) * (zw + 10.0)
    self.drawCard(uiRect(zx, zy, zw, zh), bg, bd, 1.5)
    self.drawText(font, zx + 10.0, zy + 20.0, title, 12, color(0.96, 0.94, 0.86, 1.0))
    var k = 0
    for c in p.game.matCubes:
      if c.zone == zone:
        let col = k mod 4
        let row = k div 4
        let cRc = uiRect(zx + 10.0 + float(col) * 54.0, zy + 32.0 + float(row) * 54.0, 48.0, 48.0)
        self.drawLogicCube(font, cRc, c.sym)
        inc k

  if p.game.matWitness.len > 0:
    let wRc = uiRect(lp.x + 18.0, zy + zh + 14.0, lp.w - 36.0, 56.0)
    self.drawCard(wRc, color(0.14, 0.22, 0.30, 0.96), color(0.58, 0.82, 0.98, 0.90), 1.5)
    discard self.drawWrappedText(font, wRc.x + 12.0, wRc.y + 22.0, wRc.w - 24.0, p.game.matWitness, 13, color(0.96, 0.98, 1.0, 1.0))

  # Right panel: Live Mat Solver Status + Match Chronicle
  self.drawCard(rp, color(0.10, 0.14, 0.13, 0.96), color(0.46, 0.60, 0.52, 0.80))
  self.drawText(font, rp.x + 16.0, rp.y + 28.0, "HOW TO WIN ON THE PROPS & PROOFS MAT", 14, color(0.96, 0.84, 0.52, 1.0), shadow = true)
  discard self.drawWrappedText(
    font,
    rp.x + 16.0,
    rp.y + 52.0,
    rp.w - 32.0,
    "Each turn, move 1 cube from Resources into Required, Permitted, or Forbidden. Watch the balance of operators and atoms! If Required + Permitted ALREADY contain a valid Goal WFF, click 'Challenge: NOW!' (+6 pts). If the opponent's last move made any valid Goal impossible, click 'Challenge: IMPOSSIBLE!' (+6 pts).",
    12,
    color(0.86, 0.88, 0.84, 0.95),
    17.0,
  )

  # Live Mat Balance Readout
  let st = p.game.matZoneStats()
  let balRc = uiRect(rp.x + 16.0, rp.y + 150.0, rp.w - 32.0, 56.0)
  self.drawCard(balRc, color(0.08, 0.13, 0.16, 0.95), color(0.46, 0.72, 0.88, 0.80), 1.2)
  self.drawText(font, balRc.x + 10.0, balRc.y + 20.0, fmt"LIVE MAT BALANCE (Required + Permitted):  {st.reqPermAtoms} atoms,  {st.reqPermBins} binaries,  {st.reqPermUnaries} unaries  |  {st.resCount} in Resources", 11, color(0.76, 0.92, 0.98, 1.0))
  self.drawText(font, balRc.x + 10.0, balRc.y + 42.0, "Rule of thumb: B binaries need B + 1 atoms (and >= 5 total cubes for Goal).", 11, color(0.88, 0.86, 0.72, 0.94))

  # Chronicle log
  self.drawText(font, rp.x + 16.0, rp.y + 228.0, "MATCH CHRONICLE", 13, color(0.76, 0.90, 0.96, 1.0))
  self.drawLine(vector2(rp.x + 16.0, rp.y + 236.0), vector2(rp.x + rp.w - 16.0, rp.y + 236.0), color(0.42, 0.54, 0.50, 0.65), 1.2)
  let maxLines = max(8, int((rp.h - 262.0) / 21.0))
  let startIdx = max(0, p.game.matLog.len - maxLines)
  var ly = rp.y + 260.0
  for idx in startIdx ..< p.game.matLog.len:
    self.drawText(font, rp.x + 16.0, ly, p.game.matLog[idx], 12, color(0.92, 0.90, 0.84, 0.96), rp.w - 32.0)
    ly += 21.0

proc drawProofLab(self: PropsAndProofsController; font: gdref Font) =
  let p = self.presenter
  let lp = p.leftPanelRect()
  let rp = p.rightPanelRect()
  let puz = ProofPuzzles[p.game.labPuzzleIdx]

  self.drawCard(lp, color(0.11, 0.15, 0.14, 0.96), color(0.46, 0.60, 0.52, 0.80))
  self.drawText(font, lp.x + 18.0, lp.y + 28.0, fmt"PROOF & KRIPKE LAB — {puz.title}", 15, color(0.98, 0.88, 0.58, 1.0), shadow = true)
  self.drawText(font, lp.x + 18.0, lp.y + 94.0, fmt"Goal: {puz.goal} ({parseWffString(puz.goal).infix})  |  System: {$p.game.modalSystem}", 13, color(0.76, 0.94, 0.84, 1.0))
  self.drawText(font, lp.x + 18.0, lp.y + 120.0, "SYMBOL KEYBOARD (Click or type p,q,r,s,N,C,K,A,E,L,M):", 11, color(0.84, 0.82, 0.70, 0.95))

  for i, ch in p.cubeHits:
    self.drawLogicCube(font, ch.rc, ch.sym, hovered = (i == p.hoverCubeIdx))

  # Inspector embedded in lower half of left panel
  let inspRc = uiRect(lp.x + 14.0, lp.y + 196.0, lp.w - 28.0, lp.h - 266.0)
  self.drawFormulaInspector(font, inspRc, p.game.labWorkspace, p.game.modalSystem)

  # Right panel: Fitch Proof Builder
  self.drawCard(rp, color(0.10, 0.13, 0.15, 0.96), color(0.48, 0.60, 0.72, 0.80))
  self.drawText(font, rp.x + 18.0, rp.y + 28.0, "FITCH NATURAL DEDUCTION & MODAL PROOF", 14, color(0.96, 0.86, 0.56, 1.0), shadow = true)
  discard self.drawWrappedText(font, rp.x + 18.0, rp.y + 52.0, rp.w - 36.0, "Hint: " & puz.hint, 12, color(0.82, 0.88, 0.92, 0.92))

  # Fitch proof lines
  var fy = rp.y + 104.0
  for st in p.game.labCheck.steps:
    let indent = float(st.depth) * 22.0
    # Draw Fitch vertical scope bars
    for d in 0 .. st.depth:
      let bx = rp.x + 48.0 + float(d) * 22.0
      self.drawLine(vector2(bx, fy - 16.0), vector2(bx, fy + 10.0), color(0.56, 0.78, 0.94, 0.75), 1.8)
    let lineCol = if st.valid: color(0.62, 0.96, 0.74, 1.0) else: color(0.98, 0.54, 0.50, 1.0)
    self.drawText(font, rp.x + 18.0, fy, fmt"{st.lineNo}.", 13, color(0.76, 0.82, 0.86, 0.90))
    let pRes = parseWffString(st.formula)
    let disp = if pRes.isWff: fmt"{st.formula}  ({pRes.infix})" else: st.formula
    self.drawText(font, rp.x + 58.0 + indent, fy, disp, 13, lineCol)
    var refStr = ""
    for ri, rv in st.refs:
      if ri > 0: refStr.add(",")
      refStr.add($rv)
    let ruleStr = if refStr.len > 0: fmt"{$st.rule} [{refStr}]" else: $st.rule
    self.drawText(font, rp.x + rp.w - 230.0, fy, ruleStr, 12, color(0.90, 0.84, 0.66, 0.95))
    if not st.valid:
      self.drawText(font, rp.x + 58.0 + indent, fy + 16.0, "↳ " & st.message, 11, color(0.98, 0.64, 0.58, 0.95))
      fy += 18.0
    fy += 28.0

  # Proof status bar
  let stBg = if p.game.labCheck.goalReached: color(0.12, 0.36, 0.22, 0.96) else: color(0.14, 0.18, 0.22, 0.95)
  self.drawCard(uiRect(rp.x + 18.0, rp.y + 368.0, rp.w - 36.0, 44.0), stBg, color(0.58, 0.78, 0.88, 0.80), 1.4)
  discard self.drawWrappedText(font, rp.x + 28.0, rp.y + 394.0, rp.w - 56.0, p.game.labCheck.summary, 13, color(0.96, 0.98, 0.96, 1.0))

  self.drawText(font, rp.x + 18.0, rp.y + 422.0, "SELECT INFERENCE RULE:", 11, color(0.84, 0.82, 0.70, 0.95))

  # Selected rule guide card below the 2-row rule strip
  let rgRc = uiRect(rp.x + 18.0, rp.y + 500.0, rp.w - 36.0, 82.0)
  self.drawCard(rgRc, color(0.08, 0.12, 0.16, 0.95), color(0.48, 0.70, 0.88, 0.80), 1.3)
  self.drawText(font, rgRc.x + 10.0, rgRc.y + 18.0, fmt"SELECTED RULE GUIDE — {$p.game.labSelectedRule}", 11, color(0.70, 0.90, 1.0, 1.0))
  discard self.drawWrappedText(font, rgRc.x + 10.0, rgRc.y + 38.0, rgRc.w - 20.0, ruleHelp(p.game.labSelectedRule), 12, color(0.94, 0.94, 0.90, 0.96), 17.0)
  self.drawText(font, rgRc.x + 10.0, rgRc.y + 72.0, "How to add a line: 1) Build formula on left  2) Pick Rule & Ref1/Ref2  3) Click '+ Add Step'.", 11, color(0.82, 0.84, 0.74, 0.92))

proc drawOverlay(self: PropsAndProofsController; font: gdref Font) =
  let p = self.presenter
  self.drawRect(rect2(0.0, 0.0, p.width, p.height), color(0.02, 0.03, 0.04, 0.76), filled = true)
  let mr = p.modalRect()
  self.drawCard(mr, color(0.10, 0.14, 0.13, 0.99), color(0.86, 0.72, 0.38, 0.95), 2.4)

  if p.overlay == moRules:
    self.drawText(font, mr.x + 24.0, mr.y + 36.0, "PROPS & PROOFS — POLISH NOTATION & RULES GUIDE", 20, color(0.98, 0.88, 0.56, 1.0), shadow = true)
    let lines = [
      "1. POLISH (ŁUKASIEWICZ) PREFIX NOTATION — ZERO PARENTHESES:",
      "   • Atoms (0-ary, fills 1 slot):  p, q, r, s  are standalone true/false claims (WFFs).",
      "   • Unary (1-ary, +0 slots):      N (¬ not),  L (□ necessarily),  M (◇ possibly)  prefix 1 WFF.",
      "   • Binary (2-ary, +1 slot):      C (→ if-then),  K (∧ and),  A (∨ or),  E (↔ iff)  prefix 2 WFFs.",
      "   • Reading example:  CKpqr = C [Kpq] [r] = ((p ∧ q) → r)   |   CpKqr = (p → (q ∧ r)).",
      "",
      "2. THE SLOT-COUNTING TRICK (INSTANT WFF CHECK):",
      "   • Start at 1 open slot. Binary adds +1, Unary adds +0, Atom subtracts -1.",
      "   • A sequence is a valid WFF iff slots hit 0 on the final cube (so B binaries need B + 1 atoms).",
      "",
      "3. THE WFF GAME (DICE SPRINT):",
      "   • Roll 12–14 logic cubes and assemble the longest valid WFF against the Logician AI.",
      "   • Tip: Stack all unary cubes (N, L, M) first — they add free length without costing atoms!",
      "",
      "4. THE 3-ZONE PROPS & PROOFS MAT:",
      "   • Alternate placing 1 Resource cube into REQUIRED (must use), PERMITTED (may use), or FORBIDDEN.",
      "   • Call 'Challenge: NOW!' if Required + Permitted already form a valid Goal WFF (+6 pts).",
      "   • Call 'Challenge: IMPOSSIBLE!' if the last move made any valid Goal impossible (+6 pts).",
      "",
      "5. KEYBOARD SHORTCUTS:",
      "   • Type p, q, r, s, N, C, K, A, E, L, M to place cubes; Backspace to undo; Esc to close popups.",
    ]
    var ly = mr.y + 74.0
    for ln in lines:
      self.drawText(font, mr.x + 24.0, ly, ln, 13, color(0.92, 0.92, 0.88, 0.98))
      ly += 26.0
  else:
    self.drawText(font, mr.x + 24.0, mr.y + 36.0, "MODAL LOGIC SYSTEMS REFERENCE (K → T → S4 → S5)", 20, color(0.70, 0.90, 1.0, 1.0), shadow = true)
    let lines = [
      "1. POSSIBLE WORLDS & HOW TO READ A KRIPKE GRAPH:",
      "   • Circles (w0, w1, w2) are possible worlds. Arrows (w → v) mean world w can 'see' world v.",
      "   • □φ (Lφ) is true at w iff φ is true at EVERY world v that w has an arrow to.",
      "   • ◇φ (Mφ) is true at w iff φ is true at AT LEAST ONE world v that w has an arrow to.",
      "   • Red circle = the failing world where φ evaluates to False (φ:F). Loop above circle = self-loop (wRw).",
      "   • Modal Duality (all systems):  ¬□p ↔ ◇¬p  (ENLpMNp)   and   ¬◇p ↔ □¬p  (ENMpLNp).",
      "",
      "2. THE MODAL HIERARCHY (Each stronger system adds arrow rules to R):",
      "   • System K  (Any arrows, even dead-ends):  Axiom K:  □(p→q) → (□p→□q)   [CLCpqCLpLq]",
      "                                              Rule Nec: From pure theorem ⊢ φ, infer ⊢ □φ.",
      "   • System T  (+ Reflexive: every wRw):      Axiom T:  □p → p              [CLpp]  (Truth)",
      "   • System S4 (+ Transitive: wRv & vRu→wRu): Axiom 4:  □p → □□p            [CLpLLp] (Provability / Knowledge)",
      "   • System S5 (+ Symmetric: wRv → vRw):      Axiom 5:  ◇p → □◇p            [CMpLMp] (Metaphysical Necessity)",
      "                                              Axiom B:  p → □◇p             [CpLMp]",
      "",
      "3. PRACTICE TIP:",
      "   • Work through Academy Lessons 11–16, then test formulas in Proof & Kripke Lab to watch",
      "     how adding Reflexivity, Transitivity, or Symmetry eliminates each countermodel!",
    ]
    var ly = mr.y + 74.0
    for ln in lines:
      self.drawText(font, mr.x + 24.0, ly, ln, 13, color(0.90, 0.94, 0.98, 0.98))
      ly += 26.0

method ready*(self: PropsAndProofsController) {.gdsync.} =
  self.headless = ($DisplayServer.singleton.getName() == "headless")
  let vp = self.getViewportRect()
  let w = if vp.size.x > 200.0: float(vp.size.x) else: 1680.0
  let h = if vp.size.y > 200.0: float(vp.size.y) else: 960.0
  let seed = int64(epochTime() * 1000.0)
  self.presenter = newWffPresenter(w, h, seed)
  self.queueRedraw()

method process*(self: PropsAndProofsController; delta: float64) {.gdsync.} =
  if self.presenter.isNil or Engine.singleton.isEditorHint():
    return
  let vp = self.getViewportRect()
  if vp.size.x > 200.0 and vp.size.y > 200.0:
    if abs(float(vp.size.x) - self.presenter.width) > 1.0 or abs(float(vp.size.y) - self.presenter.height) > 1.0:
      self.presenter.resize(float(vp.size.x), float(vp.size.y))
  self.presenter.step(float(delta))
  self.queueRedraw()

method input*(self: PropsAndProofsController; event: gdref InputEvent) {.gdsync.} =
  if self.presenter.isNil or Engine.singleton.isEditorHint() or event[].isNil:
    return
  let mm = event[] as InputEventMouseMotion
  if not mm.isNil:
    let pos = mm.getPosition()
    self.presenter.onMouseMove(float(pos.x), float(pos.y))
    self.queueRedraw()
    return
  let mb = event[] as InputEventMouseButton
  if not mb.isNil:
    if mb.isPressed() and mb.getButtonIndex() == mouseButtonLeft:
      let pos = mb.getPosition()
      discard self.presenter.onMouseClick(float(pos.x), float(pos.y))
      self.queueRedraw()
    return
  let ke = event[] as InputEventKey
  if not ke.isNil and ke.isPressed() and not ke.isEcho():
    let kc = ke.getKeycode()
    if kc == keyEscape:
      discard self.presenter.onKeyChar('\x1b')
      self.queueRedraw()
    elif kc == keyBackspace:
      discard self.presenter.onKeyChar('\b')
      self.queueRedraw()
    else:
      let uni = ke.getUnicode()
      if uni >= 32 and uni < 127:
        discard self.presenter.onKeyChar(chr(uni))
        self.queueRedraw()

method draw*(self: PropsAndProofsController) {.gdsync.} =
  if self.presenter.isNil:
    return
  let p = self.presenter
  let font = ThemeDB.singleton.getFallbackFont()

  # Scholarly green-slate tabletop background
  self.drawRect(rect2(0.0, 0.0, p.width, p.height), color(0.06, 0.10, 0.09, 1.0), filled = true)

  # Top header bar
  let tb = p.topBarRect()
  self.drawCard(tb, color(0.09, 0.14, 0.12, 0.98), color(0.78, 0.64, 0.32, 0.85), 1.8)
  self.drawText(font, tb.x + 16.0, tb.y + 34.0, "PROPS & PROOFS", 22, color(0.98, 0.88, 0.56, 1.0), shadow = true)
  self.drawText(font, tb.x + 16.0, tb.y + 50.0, "Modern & Modal Logic", 11, color(0.70, 0.86, 0.80, 0.90))

  case p.game.mode
  of gmAcademy: self.drawAcademy(font)
  of gmWffGame: self.drawWffGame(font)
  of gmProofMat: self.drawProofMat(font)
  of gmProofLab: self.drawProofLab(font)

  if p.overlay == moNone:
    self.drawButtons(font)
  else:
    self.drawOverlay(font)
    self.drawButtons(font)

  if p.toastTimer > 0.0 and p.toastText.len > 0:
    let tr = uiRect((p.width - 540.0) * 0.5, p.height - 54.0, 540.0, 38.0)
    self.drawCard(tr, color(0.12, 0.24, 0.34, 0.96), color(0.62, 0.86, 0.98, 0.95), 1.6)
    self.drawText(font, tr.x + 12.0, tr.y + 24.0, p.toastText, 13, color(0.98, 0.99, 1.0, 1.0), tr.w - 24.0, horizontalAlignmentCenter)
