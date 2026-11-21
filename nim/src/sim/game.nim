## Core WFF 'N PROOF tabletop match engine, WFF solver, Logician AI, and Proof Lab state.

import std/[random, strformat]
import types, logic, proof, curriculum

type
  MatPhase* = enum
    mpYourTurn = "Your Turn — Move 1 Cube or Challenge"
    mpAiTurn = "Logician AI Thinking..."
    mpRoundOver = "Round Resolved"

  ProofPuzzle* = object
    title*: string
    system*: ModalSystem
    premises*: seq[string]
    goal*: string
    hint*: string
    sampleProof*: seq[ProofStep]

  WffGameState* = ref object
    rng*: Rand
    mode*: GameMode
    modalSystem*: ModalSystem

    # Academy state
    lessonIdx*: int
    lessonsCompleted*: array[12, bool]
    academyWorkspace*: seq[Symbol]
    academyFeedback*: string
    academySolved*: bool
    showHint*: bool

    # WFF Dice Sprint state
    sprintPool*: seq[LogicCube]
    sprintWorkspace*: seq[LogicCube]
    sprintScoreHuman*: int
    sprintScoreAi*: int
    sprintRound*: int
    sprintSubmitted*: bool
    sprintAiBest*: string
    sprintResultMsg*: string

    # Full 3-Zone WFF 'N PROOF Mat state
    matCubes*: seq[LogicCube]
    matGoal*: string
    matSelectedCubeId*: int
    matPhase*: MatPhase
    matTurnCount*: int
    matHumanScore*: int
    matAiScore*: int
    matRound*: int
    matLog*: seq[string]
    matWitness*: string
    matAiDelay*: float

    # Proof & Kripke Lab state
    labWorkspace*: seq[Symbol]
    labPuzzleIdx*: int
    labProofSteps*: seq[ProofStep]
    labCheck*: ProofCheckResult
    labSystemChecks*: array[ModalSystem, ModalCheckResult]
    labSelectedRule*: ProofRule
    labSelectedDepth*: int
    labRefA*: int
    labRefB*: int

let ProofPuzzles*: array[6, ProofPuzzle] = [
  ProofPuzzle(
    title: "1. Modus Ponens & Conjunction",
    system: msProp,
    premises: @["Cpq", "Kpr"],
    goal: "q",
    hint: "Extract p from Kpr using Ko, then derive q from Cpq and p using Co.",
    sampleProof: @[
      ProofStep(lineNo: 1, depth: 0, formula: "Cpq", rule: prPremise),
      ProofStep(lineNo: 2, depth: 0, formula: "Kpr", rule: prPremise),
      ProofStep(lineNo: 3, depth: 0, formula: "p", rule: prKo, refs: @[2]),
      ProofStep(lineNo: 4, depth: 0, formula: "q", rule: prCo, refs: @[1, 3]),
    ],
  ),
  ProofPuzzle(
    title: "2. Law of Identity (Fitch Subproof)",
    system: msProp,
    premises: @[],
    goal: "Cpp",
    hint: "Assume p at depth 1 (Assump), then discharge with Ci referencing lines 1–1.",
    sampleProof: @[
      ProofStep(lineNo: 1, depth: 1, formula: "p", rule: prAssump),
      ProofStep(lineNo: 2, depth: 0, formula: "Cpp", rule: prCi, refs: @[1, 1]),
    ],
  ),
  ProofPuzzle(
    title: "3. Modal K: Necessitation & Distribution",
    system: msK,
    premises: @["LCpq", "Lp"],
    goal: "Lq",
    hint: "Apply K-Dist to lines 1 (□(p→q)) and 2 (□p) to conclude □q (Lq).",
    sampleProof: @[
      ProofStep(lineNo: 1, depth: 0, formula: "LCpq", rule: prPremise),
      ProofStep(lineNo: 2, depth: 0, formula: "Lp", rule: prPremise),
      ProofStep(lineNo: 3, depth: 0, formula: "Lq", rule: prKDist, refs: @[1, 2]),
    ],
  ),
  ProofPuzzle(
    title: "4. Modal T: Reflexive Elimination",
    system: msT,
    premises: @["LCpq", "Lp"],
    goal: "q",
    hint: "Use K-Dist to get Lq (□q), then apply Axiom T (T-Elim) to derive q.",
    sampleProof: @[
      ProofStep(lineNo: 1, depth: 0, formula: "LCpq", rule: prPremise),
      ProofStep(lineNo: 2, depth: 0, formula: "Lp", rule: prPremise),
      ProofStep(lineNo: 3, depth: 0, formula: "Lq", rule: prKDist, refs: @[1, 2]),
      ProofStep(lineNo: 4, depth: 0, formula: "q", rule: prTElim, refs: @[3]),
    ],
  ),
  ProofPuzzle(
    title: "5. Modal S4: Positive Introspection",
    system: msS4,
    premises: @["Lp"],
    goal: "LLp",
    hint: "In System S4 (transitive frames), apply 4-Intro directly to □p to obtain □□p (LLp).",
    sampleProof: @[
      ProofStep(lineNo: 1, depth: 0, formula: "Lp", rule: prPremise),
      ProofStep(lineNo: 2, depth: 0, formula: "LLp", rule: prFourIntro, refs: @[1]),
    ],
  ),
  ProofPuzzle(
    title: "6. Modal S5: Negative Introspection & Duality",
    system: msS5,
    premises: @["NLp"],
    goal: "LMNp",
    hint: "Use Dual on ¬□p (NLp) to get ◇¬p (MNp), then apply Axiom 5 (5-Intro) to get □◇¬p (LMNp).",
    sampleProof: @[
      ProofStep(lineNo: 1, depth: 0, formula: "NLp", rule: prPremise),
      ProofStep(lineNo: 2, depth: 0, formula: "MNp", rule: prDual, refs: @[1]),
      ProofStep(lineNo: 3, depth: 0, formula: "LMNp", rule: prFiveIntro, refs: @[2]),
    ],
  ),
]

const ClassicDieFaces: array[6, Symbol] = [symP, symQ, symR, symN, symC, symK]
const OperatorDieFaces: array[6, Symbol] = [symC, symK, symA, symE, symN, symP]
const ModalDieFaces: array[6, Symbol] = [symL, symM, symC, symN, symP, symQ]

proc rollSymbol(rng: var Rand; idx: int; includeModal: bool): Symbol =
  if includeModal and idx mod 3 == 0:
    return ModalDieFaces[rng.rand(0 .. 5)]
  if idx mod 2 == 0:
    return ClassicDieFaces[rng.rand(0 .. 5)]
  OperatorDieFaces[rng.rand(0 .. 5)]

proc findBestWff*(available: openArray[Symbol]; required: openArray[Symbol] = @[]): seq[Symbol] =
  ## Greedy + exact Polish WFF builder: finds the longest valid WFF using all `required`
  ## symbols and a subset of `available` symbols.
  var counts: array[Symbol, int]
  for s in available:
    inc counts[s]
  var reqCounts: array[Symbol, int]
  for s in required:
    inc reqCounts[s]
    if counts[s] < reqCounts[s]:
      return @[]

  var atoms: seq[Symbol] = @[]
  var unaries: seq[Symbol] = @[]
  var binaries: seq[Symbol] = @[]

  # Pull required symbols first, then optional symbols.
  for s in Symbol:
    for _ in 0 ..< reqCounts[s]:
      case s.arity()
      of 0: atoms.add(s)
      of 1: unaries.add(s)
      else: binaries.add(s)
  for s in Symbol:
    let extra = counts[s] - reqCounts[s]
    for _ in 0 ..< extra:
      case s.arity()
      of 0: atoms.add(s)
      of 1: unaries.add(s)
      else: binaries.add(s)

  if atoms.len == 0:
    return @[]

  # A valid Polish WFF with B binary operators requires exactly B + 1 atoms.
  let reqBin = block:
    var c = 0
    for s in required:
      if s.arity() == 2: inc c
    c
  if reqBin + 1 > atoms.len:
    return @[]

  let maxBins = min(binaries.len, atoms.len - 1)
  let usedAtoms = maxBins + 1
  if usedAtoms < (block:
    var c = 0
    for s in required:
      if s.arity() == 0: inc c
    c
  ):
    return @[]

  # Assemble in Polish prefix order: all unaries, then all binaries, then atoms.
  # Every unary reduces arity by 0, every binary adds +1 needed atom, and usedAtoms = maxBins + 1 balances to 1 WFF!
  result = @[]
  for u in unaries:
    result.add(u)
  for i in 0 ..< maxBins:
    result.add(binaries[i])
  for i in 0 ..< usedAtoms:
    result.add(atoms[i])

  if not parseWff(result).isWff:
    return @[]

proc matLogPush(g: WffGameState; msg: string) =
  g.matLog.add(msg)
  if g.matLog.len > 40:
    g.matLog.delete(0)

proc refreshLabAnalysis*(g: WffGameState) =
  let parsed = parseWff(g.labWorkspace)
  for ms in ModalSystem:
    if parsed.isWff:
      g.labSystemChecks[ms] = checkModalValidity(parsed.root, ms)
    else:
      g.labSystemChecks[ms] = ModalCheckResult(
        system: ms,
        valid: false,
        summary: parsed.errorMsg,
      )
  let puz = ProofPuzzles[clamp(g.labPuzzleIdx, 0, ProofPuzzles.high)]
  g.labCheck = verifyProof(g.labProofSteps, puz.goal, g.modalSystem)

proc loadLabPuzzle*(g: WffGameState; idx: int) =
  g.labPuzzleIdx = clamp(idx, 0, ProofPuzzles.high)
  let puz = ProofPuzzles[g.labPuzzleIdx]
  g.modalSystem = puz.system
  g.labProofSteps = @[]
  for i, prem in puz.premises:
    g.labProofSteps.add(ProofStep(
      lineNo: i + 1,
      depth: 0,
      formula: prem,
      rule: prPremise,
    ))
  g.labWorkspace = @[]
  for ch in puz.goal:
    var s: Symbol
    if charToSymbol(ch, s):
      g.labWorkspace.add(s)
  g.labSelectedDepth = 0
  g.labRefA = if g.labProofSteps.len >= 1: 1 else: 0
  g.labRefB = if g.labProofSteps.len >= 2: 2 else: 0
  g.refreshLabAnalysis()

proc loadSampleProof*(g: WffGameState) =
  let puz = ProofPuzzles[clamp(g.labPuzzleIdx, 0, ProofPuzzles.high)]
  g.modalSystem = puz.system
  g.labProofSteps = puz.sampleProof
  g.refreshLabAnalysis()

proc appendLabProofStep*(g: WffGameState): bool =
  let parsed = parseWff(g.labWorkspace)
  if not parsed.isWff:
    return false
  var refs: seq[int] = @[]
  case g.labSelectedRule
  of prPremise, prAssump:
    discard
  of prR, prKo, prAi, prNo, prEo, prNec, prTElim, prFourIntro, prFiveIntro, prDual:
    if g.labRefA > 0: refs.add(g.labRefA)
  of prCo, prCi, prKi, prEi, prKDist:
    if g.labRefA > 0: refs.add(g.labRefA)
    if g.labRefB > 0: refs.add(g.labRefB)
  of prAo, prNi:
    if g.labRefA > 0: refs.add(g.labRefA)
    if g.labRefB > 0: refs.add(g.labRefB)
    if g.labProofSteps.len >= 3: refs.add(g.labProofSteps.len)

  let depth = if g.labSelectedRule == prAssump: max(1, g.labSelectedDepth) else: g.labSelectedDepth
  g.labProofSteps.add(ProofStep(
    lineNo: g.labProofSteps.len + 1,
    depth: depth,
    formula: parsed.polish,
    rule: g.labSelectedRule,
    refs: refs,
  ))
  g.refreshLabAnalysis()
  true

proc popLabProofStep*(g: WffGameState) =
  let puz = ProofPuzzles[clamp(g.labPuzzleIdx, 0, ProofPuzzles.high)]
  if g.labProofSteps.len > puz.premises.len:
    discard g.labProofSteps.pop()
    g.refreshLabAnalysis()

proc startSprintRound*(g: WffGameState) =
  inc g.sprintRound
  g.sprintPool = @[]
  g.sprintWorkspace = @[]
  g.sprintSubmitted = false
  g.sprintAiBest = ""
  g.sprintResultMsg = "Click cubes from the rolled pool to build the longest valid WFF!"
  let includeModal = g.modalSystem != msProp
  let count = if includeModal: 14 else: 12
  var atomCount = 0
  for i in 0 ..< count:
    var s = rollSymbol(g.rng, i, includeModal)
    if i >= count - 3 and atomCount < 4:
      s = Symbol(ord(symP) + (i mod 4))
    if s.arity() == 0:
      inc atomCount
    g.sprintPool.add(LogicCube(id: i + 1, sym: s, zone: mzResources))

proc sprintPickCube*(g: WffGameState; cubeId: int) =
  if g.sprintSubmitted: return
  for i, c in g.sprintPool:
    if c.id == cubeId:
      g.sprintWorkspace.add(c)
      g.sprintPool.delete(i)
      return

proc sprintReturnCube*(g: WffGameState; cubeId: int) =
  if g.sprintSubmitted: return
  for i, c in g.sprintWorkspace:
    if c.id == cubeId:
      g.sprintPool.add(c)
      g.sprintWorkspace.delete(i)
      return

proc sprintClear*(g: WffGameState) =
  if g.sprintSubmitted: return
  for c in g.sprintWorkspace:
    g.sprintPool.add(c)
  g.sprintWorkspace = @[]

proc sprintSubmit*(g: WffGameState) =
  if g.sprintSubmitted: return
  var playerSyms: seq[Symbol] = @[]
  for c in g.sprintWorkspace:
    playerSyms.add(c.sym)
  var allSyms: seq[Symbol] = playerSyms
  for c in g.sprintPool:
    allSyms.add(c.sym)

  let parsed = parseWff(playerSyms)
  let aiBest = findBestWff(allSyms)
  let aiParsed = parseWff(aiBest)
  g.sprintAiBest = if aiParsed.isWff: fmt"{aiParsed.polish} ({aiParsed.infix})" else: "(none)"

  let humanPts =
    if parsed.isWff:
      playerSyms.len + (if parsed.hasModal: 2 else: 0)
    else:
      0
  let aiPts =
    if aiParsed.isWff:
      aiBest.len + (if aiParsed.hasModal: 2 else: 0)
    else:
      0

  g.sprintScoreHuman += humanPts
  g.sprintScoreAi += aiPts
  g.sprintSubmitted = true
  if parsed.isWff:
    if humanPts >= aiPts:
      g.sprintResultMsg = fmt"Brilliant! Your WFF {parsed.polish} ({parsed.infix}) scored +{humanPts} pts vs AI +{aiPts} pts!"
    else:
      g.sprintResultMsg = fmt"Valid WFF {parsed.polish} (+{humanPts} pts). AI found {aiParsed.polish} (+{aiPts} pts)."
  else:
    g.sprintResultMsg = fmt"Not a valid WFF ({parsed.errorMsg}) — +0 pts. AI found {aiParsed.polish} (+{aiPts} pts)."

# --- Full 3-Zone WFF 'N PROOF Mat Engine ---

proc matZoneSymbols*(g: WffGameState; zone: MatZone): seq[Symbol] =
  for c in g.matCubes:
    if c.zone == zone:
      result.add(c.sym)

proc checkMatSolvable*(g: WffGameState; includeResources: bool): (bool, string) =
  ## Checks whether a valid WFF of length >= 5 (and modal if modalSystem != msProp)
  ## can be formed using ALL Required cubes + Permitted cubes (+ Resources if includeResources)
  ## and ZERO Forbidden cubes.
  let req = g.matZoneSymbols(mzRequired)
  var avail = req
  for s in g.matZoneSymbols(mzPermitted):
    avail.add(s)
  if includeResources:
    for s in g.matZoneSymbols(mzResources):
      avail.add(s)

  let best = findBestWff(avail, req)
  if best.len == 0:
    return (false, "")
  let parsed = parseWff(best)
  if not parsed.isWff:
    return (false, "")
  if best.len < 5:
    return (false, "")
  if g.modalSystem != msProp and not parsed.hasModal:
    # Check if we still have modal symbols available
    var hasMod = false
    for s in avail:
      if s.isModalSymbol(): hasMod = true
    if not hasMod:
      return (false, "")
  (true, fmt"{parsed.polish} = {parsed.infix}")

proc startMatRound*(g: WffGameState) =
  inc g.matRound
  g.matCubes = @[]
  g.matSelectedCubeId = -1
  g.matPhase = mpYourTurn
  g.matTurnCount = 0
  g.matWitness = ""
  g.matAiDelay = 0.0
  let includeModal = g.modalSystem != msProp
  let count = if includeModal: 14 else: 12
  var atomCount = 0
  var modalCount = 0
  for i in 0 ..< count:
    var s = rollSymbol(g.rng, i, includeModal)
    if i >= count - 4 and atomCount < 4:
      s = Symbol(ord(symP) + (i mod 4))
    if includeModal and i == 0 and not s.isModalSymbol():
      s = symL
    if includeModal and i == 1 and not s.isModalSymbol():
      s = symM
    if s.arity() == 0: inc atomCount
    if s.isModalSymbol(): inc modalCount
    g.matCubes.add(LogicCube(id: i + 1, sym: s, zone: mzResources))

  g.matGoal =
    if includeModal:
      fmt"Valid Modal WFF (>= 5 cubes, includes □/◇) in {systemShortName(g.modalSystem)}"
    else:
      "Valid Propositional WFF (>= 5 cubes) using ALL Required & NO Forbidden"
  g.matLogPush(fmt"Round {g.matRound}: Rolled {count} cubes. Goal: {g.matGoal}")

proc matMoveCube*(g: WffGameState; cubeId: int; dest: MatZone; byHuman: bool): bool =
  if g.matPhase == mpRoundOver:
    return false
  if dest notin {mzRequired, mzPermitted, mzForbidden}:
    return false
  for i in 0 ..< g.matCubes.len:
    if g.matCubes[i].id == cubeId and g.matCubes[i].zone == mzResources:
      g.matCubes[i].zone = dest
      g.matSelectedCubeId = -1
      inc g.matTurnCount
      let actor = if byHuman: "You" else: "Logician AI"
      let sym = g.matCubes[i].sym
      g.matLogPush(fmt"{actor} placed [{sym.polishChar()} {sym.modernGlyph()}] into {$dest}.")
      if byHuman:
        g.matPhase = mpAiTurn
        g.matAiDelay = 0.45
      else:
        g.matPhase = mpYourTurn
      return true
  false

proc matChallenge*(g: WffGameState; kind: string; byHuman: bool) =
  if g.matPhase == mpRoundOver:
    return
  let actor = if byHuman: "You" else: "Logician AI"
  if kind == "impossible":
    let (solvable, witness) = g.checkMatSolvable(includeResources = true)
    if not solvable:
      g.matWitness = "Confirmed IMPOSSIBLE — no valid WFF satisfies Required & Forbidden."
      if byHuman: g.matHumanScore += 6 else: g.matAiScore += 6
      g.matLogPush(fmt"{actor} called IMPOSSIBLE and WON (+6 pts)!")
    else:
      g.matWitness = "Refuted! Solution still exists: " & witness
      if byHuman: g.matAiScore += 6 else: g.matHumanScore += 6
      g.matLogPush(fmt"{actor} called IMPOSSIBLE — refuted by {witness} (+6 to opponent).")
  else:
    # "now": challenge that a solution can ALREADY be built from Required + Permitted!
    let (solvableNow, witness) = g.checkMatSolvable(includeResources = false)
    if solvableNow:
      g.matWitness = "Confirmed NOW! Witness: " & witness
      if byHuman: g.matHumanScore += 6 else: g.matAiScore += 6
      g.matLogPush(fmt"{actor} called NOW and WON (+6 pts)! Witness: {witness}")
    else:
      g.matWitness = "Refuted — Required + Permitted cannot yet form the Goal."
      if byHuman: g.matAiScore += 4 else: g.matHumanScore += 4
      g.matLogPush(fmt"{actor} called NOW too early — opponent scores +4 pts.")
  g.matPhase = mpRoundOver

proc stepMatAi*(g: WffGameState; dt: float) =
  if g.mode != gmProofMat or g.matPhase != mpAiTurn:
    return
  g.matAiDelay -= dt
  if g.matAiDelay > 0.0:
    return

  # 1. Check if human's last move made Goal impossible -> call IMPOSSIBLE!
  let (solvableAll, _) = g.checkMatSolvable(includeResources = true)
  if not solvableAll:
    g.matChallenge("impossible", byHuman = false)
    return

  # 2. Check if Goal is already solvable from Required + Permitted -> call NOW!
  let (solvableNow, _) = g.checkMatSolvable(includeResources = false)
  if solvableNow and g.matTurnCount >= 4:
    g.matChallenge("now", byHuman = false)
    return

  # 3. Pick a resource cube and place it without breaking solvability.
  var resIds: seq[int] = @[]
  for c in g.matCubes:
    if c.zone == mzResources:
      resIds.add(c.id)
  if resIds.len == 0:
    g.matChallenge("impossible", byHuman = false)
    return

  let chosenId = resIds[g.rng.rand(0 .. resIds.high)]
  # Try Permitted or Required first if it keeps solvability.
  let zones = [mzPermitted, mzRequired, mzForbidden]
  let preferred = zones[g.rng.rand(0 .. 2)]
  discard g.matMoveCube(chosenId, preferred, byHuman = false)

proc loadLesson*(g: WffGameState; idx: int) =
  g.lessonIdx = clamp(idx, 0, Lessons.high)
  g.academyWorkspace = @[]
  g.academySolved = g.lessonsCompleted[g.lessonIdx]
  g.academyFeedback = Lessons[g.lessonIdx].task
  g.showHint = false
  g.modalSystem = Lessons[g.lessonIdx].system

proc academyPushSymbol*(g: WffGameState; s: Symbol) =
  if g.academyWorkspace.len < 16:
    g.academyWorkspace.add(s)
    let (ok, msg) = evaluateLesson(g.lessonIdx, g.academyWorkspace)
    g.academyFeedback = msg
    if ok:
      g.academySolved = true
      g.lessonsCompleted[g.lessonIdx] = true

proc academyPopSymbol*(g: WffGameState) =
  if g.academyWorkspace.len > 0:
    discard g.academyWorkspace.pop()
    let (ok, msg) = evaluateLesson(g.lessonIdx, g.academyWorkspace)
    g.academyFeedback = msg
    if ok:
      g.academySolved = true
      g.lessonsCompleted[g.lessonIdx] = true

proc academyClear*(g: WffGameState) =
  g.academyWorkspace = @[]
  g.academyFeedback = Lessons[g.lessonIdx].task

proc newWffGame*(seed: int64 = 42): WffGameState =
  result = WffGameState(
    rng: initRand(seed),
    mode: gmAcademy,
    modalSystem: msProp,
    matSelectedCubeId: -1,
    labSelectedRule: prCo,
  )
  result.loadLesson(0)
  result.startSprintRound()
  result.startMatRound()
  result.loadLabPuzzle(0)
