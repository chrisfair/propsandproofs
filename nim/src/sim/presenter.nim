## Pure-Nim UI layout, hit-testing, button registry, and interaction presenter for WFF 'N PROOF.

import std/[strformat, strutils]
import types, proof, curriculum, game

type
  ButtonStyle* = enum
    bsPrimary
    bsSecondary
    bsAccent
    bsDanger
    bsActiveTab
    bsInactiveTab

  UiButton* = object
    id*: string
    label*: string
    rc*: UiRect
    style*: ButtonStyle
    enabled*: bool

  CubeHit* = object
    cubeId*: int
    sym*: Symbol
    rc*: UiRect
    zone*: MatZone
    selected*: bool
    paletteIdx*: int

  WffPresenter* = ref object
    game*: WffGameState
    width*: float
    height*: float
    mouseX*: float
    mouseY*: float
    hoverBtnId*: string
    hoverCubeIdx*: int
    buttons*: seq[UiButton]
    cubeHits*: seq[CubeHit]
    overlay*: ModalOverlay
    toastText*: string
    toastTimer*: float

proc setToast*(p: WffPresenter; msg: string; dur: float = 3.2) =
  p.toastText = msg
  p.toastTimer = dur

proc topBarRect*(p: WffPresenter): UiRect =
  uiRect(16.0, 12.0, p.width - 32.0, 56.0)

proc mainAreaRect*(p: WffPresenter): UiRect =
  uiRect(16.0, 80.0, p.width - 32.0, p.height - 96.0)

proc leftPanelRect*(p: WffPresenter): UiRect =
  let m = p.mainAreaRect()
  uiRect(m.x, m.y, m.w * 0.56 - 8.0, m.h)

proc rightPanelRect*(p: WffPresenter): UiRect =
  let m = p.mainAreaRect()
  let lw = m.w * 0.56
  uiRect(m.x + lw + 8.0, m.y, m.w - lw - 8.0, m.h)

proc modalRect*(p: WffPresenter): UiRect =
  let w = min(980.0, p.width - 80.0)
  let h = min(680.0, p.height - 80.0)
  uiRect((p.width - w) * 0.5, (p.height - h) * 0.5, w, h)

proc addBtn(p: WffPresenter; id, label: string; rc: UiRect; style: ButtonStyle = bsSecondary; enabled: bool = true) =
  p.buttons.add(UiButton(id: id, label: label, rc: rc, style: style, enabled: enabled))

proc rebuildLayout*(p: WffPresenter) =
  p.buttons = @[]
  p.cubeHits = @[]
  let tb = p.topBarRect()

  # Mode tabs in top bar
  let tabW = 186.0
  var tx = tb.x + 240.0
  for m in GameMode:
    let st = if p.game.mode == m: bsActiveTab else: bsInactiveTab
    p.addBtn("mode:" & $ord(m), $m, uiRect(tx, tb.y + 10.0, tabW, 36.0), st)
    tx += tabW + 8.0

  # Modal system selector pills on right of top bar
  let sysNames = [msProp, msK, msT, msS4, msS5]
  let pillW = 54.0
  var sx = tb.x + tb.w - float(sysNames.len) * (pillW + 4.0) - 210.0
  for ms in sysNames:
    let st = if p.game.modalSystem == ms: bsAccent else: bsInactiveTab
    p.addBtn("sys:" & $ord(ms), systemShortName(ms), uiRect(sx, tb.y + 12.0, pillW, 32.0), st)
    sx += pillW + 4.0

  p.addBtn("modal:rules", "Rules", uiRect(tb.x + tb.w - 196.0, tb.y + 12.0, 88.0, 32.0), bsSecondary)
  p.addBtn("modal:modalref", "K/T/S4/S5", uiRect(tb.x + tb.w - 100.0, tb.y + 12.0, 92.0, 32.0), bsPrimary)

  if p.overlay != moNone:
    let mr = p.modalRect()
    p.addBtn("modal:close", "Close [Esc]", uiRect(mr.x + mr.w - 136.0, mr.y + 14.0, 120.0, 34.0), bsDanger)
    return

  let lp = p.leftPanelRect()
  let rp = p.rightPanelRect()

  case p.game.mode
  of gmAcademy:
    # Lesson selector strip at top of left panel
    let btnW = (lp.w - 36.0 - 11.0 * 6.0) / 12.0
    for i in 0 ..< Lessons.len:
      let bx = lp.x + 18.0 + float(i) * (btnW + 6.0)
      let st =
        if i == p.game.lessonIdx: bsAccent
        elif p.game.lessonsCompleted[i]: bsPrimary
        else: bsInactiveTab
      let mark = if p.game.lessonsCompleted[i]: fmt"{i+1}✓" else: fmt"{i+1}"
      p.addBtn("lesson:" & $i, mark, uiRect(bx, lp.y + 44.0, btnW, 32.0), st)

    # Palette cubes for current lesson
    let lesson = Lessons[p.game.lessonIdx]
    let cubeSize = 58.0
    let gap = 10.0
    for i, sym in lesson.palette:
      let col = i mod 10
      let row = i div 10
      let cx = lp.x + 22.0 + float(col) * (cubeSize + gap)
      let cy = lp.y + 304.0 + float(row) * (cubeSize + gap)
      p.cubeHits.add(CubeHit(
        cubeId: 1000 + i,
        sym: sym,
        rc: uiRect(cx, cy, cubeSize, cubeSize),
        zone: mzResources,
        paletteIdx: i,
      ))

    # Action buttons
    let ay = lp.y + lp.h - 58.0
    p.addBtn("acad:back", "Backspace", uiRect(lp.x + 18.0, ay, 118.0, 38.0), bsSecondary)
    p.addBtn("acad:clear", "Clear", uiRect(lp.x + 146.0, ay, 92.0, 38.0), bsDanger)
    p.addBtn("acad:hint", "Toggle Hint", uiRect(lp.x + 248.0, ay, 122.0, 38.0), bsSecondary)
    p.addBtn("acad:example", "Load Example", uiRect(lp.x + 380.0, ay, 134.0, 38.0), bsSecondary)
    let hasNext = p.game.lessonIdx < Lessons.high
    p.addBtn("acad:next", "Next Lesson →", uiRect(lp.x + lp.w - 164.0, ay, 146.0, 38.0), bsPrimary, enabled = hasNext)

  of gmWffGame:
    # Rolled pool cubes
    let cubeSize = 58.0
    let gap = 10.0
    for i, c in p.game.sprintPool:
      let col = i mod 8
      let row = i div 8
      let cx = lp.x + 22.0 + float(col) * (cubeSize + gap)
      let cy = lp.y + 124.0 + float(row) * (cubeSize + gap)
      p.cubeHits.add(CubeHit(cubeId: c.id, sym: c.sym, rc: uiRect(cx, cy, cubeSize, cubeSize), zone: mzResources))

    # Workspace cubes (click to return to pool)
    for i, c in p.game.sprintWorkspace:
      let col = i mod 10
      let row = i div 10
      let cx = lp.x + 22.0 + float(col) * (cubeSize + gap)
      let cy = lp.y + 344.0 + float(row) * (cubeSize + gap)
      p.cubeHits.add(CubeHit(cubeId: c.id, sym: c.sym, rc: uiRect(cx, cy, cubeSize, cubeSize), zone: mzGoal))

    let ay = lp.y + lp.h - 58.0
    p.addBtn("sprint:submit", "Submit WFF", uiRect(lp.x + 18.0, ay, 150.0, 38.0), bsPrimary, enabled = not p.game.sprintSubmitted)
    p.addBtn("sprint:clear", "Clear", uiRect(lp.x + 178.0, ay, 100.0, 38.0), bsDanger, enabled = not p.game.sprintSubmitted)
    p.addBtn("sprint:new", "Roll New Dice", uiRect(lp.x + lp.w - 168.0, ay, 150.0, 38.0), bsAccent)

  of gmProofMat:
    # Resources tray cubes
    let cubeSize = 52.0
    let gap = 8.0
    var rIdx = 0
    for c in p.game.matCubes:
      if c.zone == mzResources:
        let col = rIdx mod 9
        let row = rIdx div 9
        let cx = lp.x + 22.0 + float(col) * (cubeSize + gap)
        let cy = lp.y + 132.0 + float(row) * (cubeSize + gap)
        p.cubeHits.add(CubeHit(
          cubeId: c.id,
          sym: c.sym,
          rc: uiRect(cx, cy, cubeSize, cubeSize),
          zone: mzResources,
          selected: c.id == p.game.matSelectedCubeId,
        ))
        inc rIdx

    # 3-zone placement buttons
    let canMove = p.game.matPhase == mpYourTurn and p.game.matSelectedCubeId > 0
    let zy = lp.y + 270.0
    let zw = (lp.w - 56.0) / 3.0
    p.addBtn("mat:place:req", "→ REQUIRED", uiRect(lp.x + 18.0, zy, zw, 36.0), bsPrimary, enabled = canMove)
    p.addBtn("mat:place:perm", "→ PERMITTED", uiRect(lp.x + 28.0 + zw, zy, zw, 36.0), bsAccent, enabled = canMove)
    p.addBtn("mat:place:forb", "→ FORBIDDEN", uiRect(lp.x + 38.0 + zw * 2.0, zy, zw, 36.0), bsDanger, enabled = canMove)

    # Challenge & New Round buttons
    let ay = lp.y + lp.h - 58.0
    let canChal = p.game.matPhase == mpYourTurn
    p.addBtn("mat:chal:now", "Challenge: NOW!", uiRect(lp.x + 18.0, ay, 168.0, 38.0), bsPrimary, enabled = canChal)
    p.addBtn("mat:chal:imp", "Challenge: IMPOSSIBLE!", uiRect(lp.x + 196.0, ay, 200.0, 38.0), bsDanger, enabled = canChal)
    p.addBtn("mat:new", "New Round", uiRect(lp.x + lp.w - 150.0, ay, 132.0, 38.0), bsAccent)

  of gmProofLab:
    # Puzzle selector buttons
    let pW = (lp.w - 36.0 - 5.0 * 6.0) / 6.0
    for i in 0 ..< ProofPuzzles.len:
      let bx = lp.x + 18.0 + float(i) * (pW + 6.0)
      let st = if i == p.game.labPuzzleIdx: bsAccent else: bsInactiveTab
      p.addBtn("lab:puz:" & $i, fmt"P{i+1}", uiRect(bx, lp.y + 42.0, pW, 30.0), st)

    # Full 11-symbol keyboard palette
    let cubeSize = 48.0
    let gap = 7.0
    for sym in Symbol:
      let i = ord(sym)
      let cx = lp.x + 18.0 + float(i) * (cubeSize + gap)
      let cy = lp.y + 132.0
      p.cubeHits.add(CubeHit(cubeId: 2000 + i, sym: sym, rc: uiRect(cx, cy, cubeSize, cubeSize), zone: mzResources, paletteIdx: i))

    # Rule selector strip on right panel
    let rules = [prAssump, prCo, prCi, prKi, prKo, prAi, prNo, prR, prNec, prKDist, prTElim, prFourIntro, prFiveIntro, prDual]
    let rBtnW = (rp.w - 36.0 - 6.0 * 6.0) / 7.0
    for i, rl in rules:
      let col = i mod 7
      let row = i div 7
      let rx = rp.x + 18.0 + float(col) * (rBtnW + 6.0)
      let ry = rp.y + 426.0 + float(row) * 34.0
      let st = if p.game.labSelectedRule == rl: bsAccent else: bsInactiveTab
      let shortLbl = ($rl).split(' ')[0]
      p.addBtn("lab:rule:" & $ord(rl), shortLbl, uiRect(rx, ry, rBtnW, 28.0), st)

    let ay = rp.y + rp.h - 56.0
    p.addBtn("lab:depth", fmt"Depth: {p.game.labSelectedDepth}", uiRect(rp.x + 18.0, ay, 94.0, 36.0), bsSecondary)
    p.addBtn("lab:refA", fmt"Ref1: {p.game.labRefA}", uiRect(rp.x + 120.0, ay, 88.0, 36.0), bsSecondary)
    p.addBtn("lab:refB", fmt"Ref2: {p.game.labRefB}", uiRect(rp.x + 216.0, ay, 88.0, 36.0), bsSecondary)
    p.addBtn("lab:addstep", "+ Add Step", uiRect(rp.x + 312.0, ay, 112.0, 36.0), bsPrimary)
    p.addBtn("lab:undo", "Undo", uiRect(rp.x + 432.0, ay, 72.0, 36.0), bsDanger)
    p.addBtn("lab:sample", "Show Proof", uiRect(rp.x + rp.w - 124.0, ay, 108.0, 36.0), bsAccent)

    let lay = lp.y + lp.h - 56.0
    p.addBtn("lab:back", "Backspace", uiRect(lp.x + 18.0, lay, 114.0, 36.0), bsSecondary)
    p.addBtn("lab:clear", "Clear Formula", uiRect(lp.x + 140.0, lay, 128.0, 36.0), bsDanger)

proc newWffPresenter*(w, h: float; seed: int64 = 42): WffPresenter =
  result = WffPresenter(
    game: newWffGame(seed),
    width: w,
    height: h,
    hoverCubeIdx: -1,
  )
  result.rebuildLayout()

proc resize*(p: WffPresenter; w, h: float) =
  if w > 200.0 and h > 200.0:
    p.width = w
    p.height = h
    p.rebuildLayout()

proc step*(p: WffPresenter; dt: float) =
  if p.toastTimer > 0.0:
    p.toastTimer = max(0.0, p.toastTimer - dt)
  let prevPhase = p.game.matPhase
  p.game.stepMatAi(dt)
  if p.game.matPhase != prevPhase:
    p.rebuildLayout()

proc onMouseMove*(p: WffPresenter; x, y: float) =
  p.mouseX = x
  p.mouseY = y
  p.hoverBtnId = ""
  for b in p.buttons:
    if b.enabled and b.rc.contains(x, y):
      p.hoverBtnId = b.id
      break
  p.hoverCubeIdx = -1
  for i, c in p.cubeHits:
    if c.rc.contains(x, y):
      p.hoverCubeIdx = i
      break

proc handleButton*(p: WffPresenter; id: string) =
  if id.startsWith("mode:"):
    let mIdx = parseInt(id.split(':')[1])
    p.game.mode = GameMode(clamp(mIdx, 0, ord(high(GameMode))))
    p.overlay = moNone
  elif id.startsWith("sys:"):
    let sIdx = parseInt(id.split(':')[1])
    p.game.modalSystem = ModalSystem(clamp(sIdx, 0, ord(high(ModalSystem))))
    p.game.refreshLabAnalysis()
    p.setToast(fmt"Switched logic system to {$p.game.modalSystem}")
  elif id == "modal:rules":
    p.overlay = if p.overlay == moRules: moNone else: moRules
  elif id == "modal:modalref":
    p.overlay = if p.overlay == moModalRef: moNone else: moModalRef
  elif id == "modal:close":
    p.overlay = moNone
  elif id.startsWith("lesson:"):
    p.game.loadLesson(parseInt(id.split(':')[1]))
  elif id == "acad:back":
    p.game.academyPopSymbol()
  elif id == "acad:clear":
    p.game.academyClear()
  elif id == "acad:hint":
    p.game.showHint = not p.game.showHint
  elif id == "acad:example":
    let ex = Lessons[p.game.lessonIdx].examplePolish
    p.game.academyClear()
    for ch in ex:
      var s: Symbol
      if charToSymbol(ch, s):
        p.game.academyPushSymbol(s)
  elif id == "acad:next":
    p.game.loadLesson(p.game.lessonIdx + 1)
  elif id == "sprint:submit":
    p.game.sprintSubmit()
  elif id == "sprint:clear":
    p.game.sprintClear()
  elif id == "sprint:new":
    p.game.startSprintRound()
  elif id == "mat:place:req":
    discard p.game.matMoveCube(p.game.matSelectedCubeId, mzRequired, byHuman = true)
  elif id == "mat:place:perm":
    discard p.game.matMoveCube(p.game.matSelectedCubeId, mzPermitted, byHuman = true)
  elif id == "mat:place:forb":
    discard p.game.matMoveCube(p.game.matSelectedCubeId, mzForbidden, byHuman = true)
  elif id == "mat:chal:now":
    p.game.matChallenge("now", byHuman = true)
  elif id == "mat:chal:imp":
    p.game.matChallenge("impossible", byHuman = true)
  elif id == "mat:new":
    p.game.startMatRound()
  elif id.startsWith("lab:puz:"):
    p.game.loadLabPuzzle(parseInt(id.split(':')[2]))
  elif id.startsWith("lab:rule:"):
    p.game.labSelectedRule = ProofRule(parseInt(id.split(':')[2]))
  elif id == "lab:depth":
    p.game.labSelectedDepth = (p.game.labSelectedDepth + 1) mod 3
  elif id == "lab:refA":
    let n = max(1, p.game.labProofSteps.len)
    p.game.labRefA = (p.game.labRefA mod n) + 1
  elif id == "lab:refB":
    let n = max(1, p.game.labProofSteps.len)
    p.game.labRefB = (p.game.labRefB mod n) + 1
  elif id == "lab:addstep":
    if not p.game.appendLabProofStep():
      p.setToast("Build a valid WFF first before adding a proof step.")
  elif id == "lab:undo":
    p.game.popLabProofStep()
  elif id == "lab:sample":
    p.game.loadSampleProof()
    p.setToast("Loaded verified sample proof!")
  elif id == "lab:back":
    if p.game.labWorkspace.len > 0:
      discard p.game.labWorkspace.pop()
      p.game.refreshLabAnalysis()
  elif id == "lab:clear":
    p.game.labWorkspace = @[]
    p.game.refreshLabAnalysis()

  p.rebuildLayout()

proc onMouseClick*(p: WffPresenter; x, y: float): bool =
  p.mouseX = x
  p.mouseY = y
  for b in p.buttons:
    if b.enabled and b.rc.contains(x, y):
      p.handleButton(b.id)
      return true

  if p.overlay != moNone:
    return false

  for c in p.cubeHits:
    if c.rc.contains(x, y):
      case p.game.mode
      of gmAcademy:
        p.game.academyPushSymbol(c.sym)
      of gmWffGame:
        if c.zone == mzResources:
          p.game.sprintPickCube(c.cubeId)
        else:
          p.game.sprintReturnCube(c.cubeId)
      of gmProofMat:
        if p.game.matPhase == mpYourTurn and c.zone == mzResources:
          p.game.matSelectedCubeId = if p.game.matSelectedCubeId == c.cubeId: -1 else: c.cubeId
      of gmProofLab:
        if p.game.labWorkspace.len < 16:
          p.game.labWorkspace.add(c.sym)
          p.game.refreshLabAnalysis()
      p.rebuildLayout()
      return true
  false

proc onKeyChar*(p: WffPresenter; ch: char): bool =
  if p.overlay != moNone:
    if ch == '\x1b':
      p.overlay = moNone
      p.rebuildLayout()
      return true
    return false

  if ch == '\b':
    case p.game.mode
    of gmAcademy: p.game.academyPopSymbol()
    of gmProofLab:
      if p.game.labWorkspace.len > 0:
        discard p.game.labWorkspace.pop()
        p.game.refreshLabAnalysis()
    of gmWffGame:
      if p.game.sprintWorkspace.len > 0 and not p.game.sprintSubmitted:
        p.game.sprintReturnCube(p.game.sprintWorkspace[^1].id)
    of gmProofMat:
      p.game.matSelectedCubeId = -1
    p.rebuildLayout()
    return true

  var sym: Symbol
  if charToSymbol(ch, sym):
    case p.game.mode
    of gmAcademy:
      p.game.academyPushSymbol(sym)
    of gmProofLab:
      if p.game.labWorkspace.len < 16:
        p.game.labWorkspace.add(sym)
        p.game.refreshLabAnalysis()
    of gmWffGame:
      for c in p.game.sprintPool:
        if c.sym == sym:
          p.game.sprintPickCube(c.id)
          break
    of gmProofMat:
      if p.game.matPhase == mpYourTurn:
        for c in p.game.matCubes:
          if c.zone == mzResources and c.sym == sym:
            p.game.matSelectedCubeId = c.id
            break
    p.rebuildLayout()
    return true
  false
