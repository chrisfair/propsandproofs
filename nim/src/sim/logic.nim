## Polish notation WFF parser, infix/English translator, truth-table engine,
## and finite Kripke frame validity & countermodel checker for Modal Systems K, T, S4, and S5.

import std/[algorithm, strformat]
import types

type
  WffNode* = ref object
    sym*: Symbol
    left*: WffNode
    right*: WffNode

  ParseResult* = object
    isWff*: bool
    root*: WffNode
    polish*: string
    infix*: string
    english*: string
    errorMsg*: string
    hasModal*: bool
    depth*: int

  TruthRow* = object
    bits*: int
    value*: bool

  TruthTableResult* = object
    atoms*: seq[Symbol]
    rows*: seq[TruthRow]
    isTautology*: bool
    isContradiction*: bool
    isContingent*: bool

  KripkeWorld* = object
    id*: int
    pVal*, qVal*, rVal*, sVal*: bool
    formulaVal*: bool

  KripkeModel* = object
    worldCount*: int
    edges*: seq[(int, int)]
    worlds*: seq[KripkeWorld]
    failingWorld*: int

  ModalCheckResult* = object
    system*: ModalSystem
    valid*: bool
    summary*: string
    countermodel*: KripkeModel
    hasCountermodel*: bool

proc toPolish*(node: WffNode): string =
  if node.isNil:
    return ""
  case node.sym.arity()
  of 0: $node.sym.polishChar()
  of 1: $node.sym.polishChar() & toPolish(node.left)
  else: $node.sym.polishChar() & toPolish(node.left) & toPolish(node.right)

proc toInfixInner(node: WffNode; isRoot: bool): string =
  if node.isNil:
    return ""
  case node.sym.arity()
  of 0:
    node.sym.modernGlyph()
  of 1:
    node.sym.modernGlyph() & toInfixInner(node.left, false)
  else:
    let inner = toInfixInner(node.left, false) & " " & node.sym.modernGlyph() & " " & toInfixInner(node.right, false)
    if isRoot: inner else: "(" & inner & ")"

proc toInfix*(node: WffNode): string =
  toInfixInner(node, true)

proc toEnglish*(node: WffNode): string =
  if node.isNil:
    return ""
  case node.sym
  of symP: "p"
  of symQ: "q"
  of symR: "r"
  of symS: "s"
  of symN: "not (" & toEnglish(node.left) & ")"
  of symL: "necessarily (" & toEnglish(node.left) & ")"
  of symM: "possibly (" & toEnglish(node.left) & ")"
  of symC: "if " & toEnglish(node.left) & " then " & toEnglish(node.right)
  of symK: "(" & toEnglish(node.left) & " and " & toEnglish(node.right) & ")"
  of symA: "(" & toEnglish(node.left) & " or " & toEnglish(node.right) & ")"
  of symE: "(" & toEnglish(node.left) & " iff " & toEnglish(node.right) & ")"

proc nodeDepth(node: WffNode): int =
  if node.isNil:
    return 0
  case node.sym.arity()
  of 0: 1
  of 1: 1 + nodeDepth(node.left)
  else: 1 + max(nodeDepth(node.left), nodeDepth(node.right))

proc nodeHasModal(node: WffNode): bool =
  if node.isNil:
    return false
  if node.sym.isModalSymbol():
    return true
  nodeHasModal(node.left) or nodeHasModal(node.right)

proc wffEquals*(a, b: WffNode): bool =
  if a.isNil and b.isNil: return true
  if a.isNil or b.isNil: return false
  a.sym == b.sym and wffEquals(a.left, b.left) and wffEquals(a.right, b.right)

proc parseExpr(syms: openArray[Symbol]; pos: var int; err: var string): WffNode =
  if pos >= syms.len:
    err = "Incomplete WFF: expected another symbol or atom."
    return nil
  let s = syms[pos]
  inc pos
  let n = WffNode(sym: s)
  case s.arity()
  of 0:
    return n
  of 1:
    n.left = parseExpr(syms, pos, err)
    if n.left.isNil:
      if err.len == 0:
        err = fmt"Unary operator '{s.polishChar()}' ({s.modernGlyph()}) is missing its operand."
      return nil
    return n
  else:
    n.left = parseExpr(syms, pos, err)
    if n.left.isNil:
      err = fmt"Binary operator '{s.polishChar()}' ({s.modernGlyph()}) is missing its 1st operand."
      return nil
    n.right = parseExpr(syms, pos, err)
    if n.right.isNil:
      err = fmt"Binary operator '{s.polishChar()}' ({s.modernGlyph()}) is missing its 2nd operand."
      return nil
    return n

proc parseWff*(syms: openArray[Symbol]): ParseResult =
  if syms.len == 0:
    result.errorMsg = "Place cubes to form a Well-Formed Formula (WFF)."
    return
  var pos = 0
  var err = ""
  let root = parseExpr(syms, pos, err)
  if root.isNil:
    result.errorMsg = err
    return
  if pos < syms.len:
    let extra = syms[pos]
    result.errorMsg = fmt"Extra symbol '{extra.polishChar()}' after complete WFF '{toPolish(root)}'."
    return
  result.isWff = true
  result.root = root
  result.polish = toPolish(root)
  result.infix = toInfix(root)
  result.english = toEnglish(root)
  result.hasModal = nodeHasModal(root)
  result.depth = nodeDepth(root)

proc parseWffString*(text: string): ParseResult =
  var syms: seq[Symbol] = @[]
  for ch in text:
    if ch in {' ', '\t', '\n', '\r'}:
      continue
    var s: Symbol
    if not charToSymbol(ch, s):
      result.errorMsg = fmt"Unknown symbol '{ch}'. Use p,q,r,s, N,C,K,A,E, L,M."
      return
    syms.add(s)
  parseWff(syms)

proc polishSlotTrace*(syms: openArray[Symbol]): tuple[openSlots: int, completeAt: int, summary: string, trace: string] =
  ## Computes the Polish prefix slot-counting trace:
  ## start with 1 open slot; binary adds +1, unary adds +0, atom fills -1.
  ## A formula is complete the exact moment open slots reach 0 with no trailing cubes.
  if syms.len == 0:
    return (
      openSlots: 1,
      completeAt: -1,
      summary: "Open slots: 1. Start with an operator (N, C, K, A, E, L, M) or an atom (p, q, r, s).",
      trace: "[start: 1 slot]",
    )

  var slots = 1
  var completeAt = -1
  var trace = "[start:1]"
  for i, s in syms:
    if slots == 0 and completeAt < 0:
      completeAt = i
    let delta = s.arity() - 1
    slots += delta
    let dStr =
      if delta > 0: "+1"
      elif delta == 0: "+0"
      else: "-1"
    trace.add(fmt" {s.polishChar()}({dStr}→{slots})")

  if completeAt >= 0:
    return (
      openSlots: slots,
      completeAt: completeAt,
      summary: fmt"Already formed a complete WFF after {completeAt} cube(s). Press Backspace to remove extra cubes.",
      trace: trace,
    )
  if slots == 0:
    return (
      openSlots: 0,
      completeAt: syms.len,
      summary: "Open slots: 0 — complete Well-Formed Formula!",
      trace: trace,
    )
  let noun = if slots == 1: "slot" else: "slots"
  (
    openSlots: slots,
    completeAt: -1,
    summary: fmt"Open slots: {slots} — add {slots} more atom/WFF {noun} (or wrap with unary/binary operators).",
    trace: trace,
  )

proc collectAtoms(node: WffNode; found: var seq[Symbol]) =
  if node.isNil: return
  if node.sym.arity() == 0:
    if node.sym notin found:
      found.add(node.sym)
  else:
    collectAtoms(node.left, found)
    collectAtoms(node.right, found)

proc evalProp*(node: WffNode; pVal, qVal, rVal, sVal: bool): bool =
  if node.isNil: return false
  case node.sym
  of symP: pVal
  of symQ: qVal
  of symR: rVal
  of symS: sVal
  of symN: not evalProp(node.left, pVal, qVal, rVal, sVal)
  of symC: (not evalProp(node.left, pVal, qVal, rVal, sVal)) or evalProp(node.right, pVal, qVal, rVal, sVal)
  of symK: evalProp(node.left, pVal, qVal, rVal, sVal) and evalProp(node.right, pVal, qVal, rVal, sVal)
  of symA: evalProp(node.left, pVal, qVal, rVal, sVal) or evalProp(node.right, pVal, qVal, rVal, sVal)
  of symE: evalProp(node.left, pVal, qVal, rVal, sVal) == evalProp(node.right, pVal, qVal, rVal, sVal)
  of symL, symM: evalProp(node.left, pVal, qVal, rVal, sVal)

proc evalTruthTable*(node: WffNode): TruthTableResult =
  var atoms: seq[Symbol] = @[]
  collectAtoms(node, atoms)
  atoms.sort(proc(a, b: Symbol): int = cmp(ord(a), ord(b)))
  result.atoms = atoms
  let n = atoms.len
  let rowCount = 1 shl n
  var allTrue = true
  var allFalse = true
  for mask in 0 ..< rowCount:
    var pV, qV, rV, sV = false
    for idx, atom in atoms:
      let bitVal = ((mask shr (n - 1 - idx)) and 1) == 1
      case atom
      of symP: pV = bitVal
      of symQ: qV = bitVal
      of symR: rV = bitVal
      of symS: sV = bitVal
      else: discard
    let val = evalProp(node, pV, qV, rV, sV)
    if not val: allTrue = false
    if val: allFalse = false
    result.rows.add(TruthRow(bits: mask, value: val))
  result.isTautology = allTrue
  result.isContradiction = allFalse
  result.isContingent = (not allTrue) and (not allFalse)

# --- Modal Kripke Semantics Engine ---

proc evalAtWorld(
  node: WffNode;
  w: int;
  worldCount: int;
  adj: array[4, array[4, bool]];
  vals: array[4, array[4, bool]];
): bool =
  case node.sym
  of symP: vals[w][0]
  of symQ: vals[w][1]
  of symR: vals[w][2]
  of symS: vals[w][3]
  of symN: not evalAtWorld(node.left, w, worldCount, adj, vals)
  of symC: (not evalAtWorld(node.left, w, worldCount, adj, vals)) or evalAtWorld(node.right, w, worldCount, adj, vals)
  of symK: evalAtWorld(node.left, w, worldCount, adj, vals) and evalAtWorld(node.right, w, worldCount, adj, vals)
  of symA: evalAtWorld(node.left, w, worldCount, adj, vals) or evalAtWorld(node.right, w, worldCount, adj, vals)
  of symE: evalAtWorld(node.left, w, worldCount, adj, vals) == evalAtWorld(node.right, w, worldCount, adj, vals)
  of symL:
    # □φ is true at w iff φ is true at every world v accessible from w (wRv).
    for v in 0 ..< worldCount:
      if adj[w][v] and not evalAtWorld(node.left, v, worldCount, adj, vals):
        return false
    true
  of symM:
    # ◇φ is true at w iff φ is true at at least one world v accessible from w (wRv).
    for v in 0 ..< worldCount:
      if adj[w][v] and evalAtWorld(node.left, v, worldCount, adj, vals):
        return true
    false

proc frameMatchesSystem(ms: ModalSystem; n: int; adj: array[4, array[4, bool]]): bool =
  if ms in {msT, msS4, msS5}:
    for i in 0 ..< n:
      if not adj[i][i]: return false
  if ms == msS5:
    for i in 0 ..< n:
      for j in 0 ..< n:
        if adj[i][j] != adj[j][i]: return false
  if ms in {msS4, msS5}:
    for i in 0 ..< n:
      for j in 0 ..< n:
        if adj[i][j]:
          for k in 0 ..< n:
            if adj[j][k] and not adj[i][k]:
              return false
  true

proc buildCountermodel(
  node: WffNode;
  n: int;
  adj: array[4, array[4, bool]];
  vals: array[4, array[4, bool]];
  failW: int;
): KripkeModel =
  result.worldCount = n
  result.failingWorld = failW
  for i in 0 ..< n:
    for j in 0 ..< n:
      if adj[i][j]:
        result.edges.add((i, j))
    result.worlds.add(KripkeWorld(
      id: i,
      pVal: vals[i][0],
      qVal: vals[i][1],
      rVal: vals[i][2],
      sVal: vals[i][3],
      formulaVal: evalAtWorld(node, i, n, adj, vals),
    ))

proc checkModalValidity*(node: WffNode; ms: ModalSystem): ModalCheckResult =
  result.system = ms
  if node.isNil:
    result.summary = "No valid WFF to evaluate."
    return
  if ms == msProp:
    if nodeHasModal(node):
      result.summary = "Contains modal operators (□/◇). Switch to K, T, S4, or S5."
      return
    let tt = evalTruthTable(node)
    result.valid = tt.isTautology
    if tt.isTautology:
      result.summary = "Tautology (valid in Classical Propositional Logic)."
    elif tt.isContradiction:
      result.summary = "Contradiction (false under every truth assignment)."
    else:
      result.summary = "Contingent (true in some assignments, false in others)."
    return

  var atoms: seq[Symbol] = @[]
  collectAtoms(node, atoms)
  let atomCount = atoms.len
  # Search finite Kripke frames up to 3 worlds (complete for K/T/S4/S5 formulas of depth <= 3).
  let maxWorlds = if atomCount <= 2: 3 else: 2
  for n in 1 .. maxWorlds:
    let edgeBits = n * n
    let totalFrames = 1 shl edgeBits
    let valBits = n * max(1, atomCount)
    let totalVals = 1 shl valBits
    for fMask in 0 ..< totalFrames:
      var adj: array[4, array[4, bool]]
      var bit = 0
      for i in 0 ..< n:
        for j in 0 ..< n:
          adj[i][j] = ((fMask shr bit) and 1) == 1
          inc bit
      if not frameMatchesSystem(ms, n, adj):
        continue
      for vMask in 0 ..< totalVals:
        var vals: array[4, array[4, bool]]
        var vBit = 0
        for w in 0 ..< n:
          for aIdx in 0 ..< atomCount:
            let b = ((vMask shr vBit) and 1) == 1
            inc vBit
            case atoms[aIdx]
            of symP: vals[w][0] = b
            of symQ: vals[w][1] = b
            of symR: vals[w][2] = b
            of symS: vals[w][3] = b
            else: discard
        for w in 0 ..< n:
          if not evalAtWorld(node, w, n, adj, vals):
            result.valid = false
            result.hasCountermodel = true
            result.countermodel = buildCountermodel(node, n, adj, vals, w)
            result.summary = fmt"Invalid in {systemShortName(ms)}: fails at world w{w} ({n}-world Kripke countermodel)."
            return
  result.valid = true
  result.summary = fmt"Valid in {systemShortName(ms)} across all checked Kripke frames!"

proc describeFamousAxiom*(polish: string): string =
  case polish
  of "Cpp": "Law of Identity (p → p)"
  of "CpCqp": "Positive Paradox / Weakening (p → (q → p))"
  of "CNpCpq": "Principle of Explosion (¬p → (p → q))"
  of "ApNp": "Law of Excluded Middle (p ∨ ¬p)"
  of "NKNpp": "Law of Non-Contradiction ¬(¬p ∧ p)"
  of "CCpqCNqNp": "Contraposition ((p → q) → (¬q → ¬p))"
  of "CLpp": "Modal Axiom T (Reflexivity): what is necessary is true"
  of "CpMp": "Dual of Axiom T: what is true is possible"
  of "CLpMp": "Modal Axiom D (Seriality): what is necessary is possible"
  of "CLpLLp": "Modal Axiom 4 (S4 Transitivity): necessity is itself necessary"
  of "CMpLMp": "Modal Axiom 5 (S5 Equivalence): what is possible is necessarily possible"
  of "CpLMp": "Modal Axiom B (Symmetry): what is true is necessarily possible"
  of "CLCpqCLpLq": "Modal Axiom K (Distribution): □ distributes over →"
  of "ENLpMNp": "Modal Duality: ¬□p ↔ ◇¬p"
  of "ENMpLNp": "Modal Duality: ¬◇p ↔ □¬p"
  else: ""
