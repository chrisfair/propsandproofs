## Fitch-style Natural Deduction & Modal Logic proof verifier for WFF 'N PROOF.

import std/strformat
import types, logic

type
  ProofRule* = enum
    prPremise = "Premise"
    prAssump = "Assump"
    prR = "R (Reit)"
    prCi = "Ci (→ Intro)"
    prCo = "Co (→ Elim / MP)"
    prKi = "Ki (∧ Intro)"
    prKo = "Ko (∧ Elim)"
    prAi = "Ai (∨ Intro)"
    prAo = "Ao (∨ Elim)"
    prNi = "Ni (¬ Intro)"
    prNo = "No (¬¬ Elim)"
    prEi = "Ei (↔ Intro)"
    prEo = "Eo (↔ Elim)"
    prNec = "Nec (□ Intro)"
    prKDist = "K (□ Dist)"
    prTElim = "T (□p → p)"
    prFourIntro = "4 (□p → □□p)"
    prFiveIntro = "5 (◇p → □◇p)"
    prDual = "Dual (¬□ ↔ ◇¬)"

  ProofStep* = object
    lineNo*: int
    depth*: int
    formula*: string
    node*: WffNode
    rule*: ProofRule
    refs*: seq[int]
    valid*: bool
    message*: string

  ProofCheckResult* = object
    allValid*: bool
    goalReached*: bool
    steps*: seq[ProofStep]
    summary*: string

proc isAccessible(steps: seq[ProofStep]; curIdx: int; targetLine: int): bool =
  if targetLine < 1 or targetLine > curIdx:
    return false
  let targetIdx = targetLine - 1
  let curDepth = steps[curIdx].depth
  let targetDepth = steps[targetIdx].depth
  if targetDepth > curDepth:
    return false
  # Ensure the target's scope was never closed between targetIdx and curIdx.
  for i in (targetIdx + 1) ..< curIdx:
    if steps[i].depth < targetDepth:
      return false
    if steps[i].depth == targetDepth and steps[i].rule == prAssump:
      return false
  true

proc isClosedSubproof(steps: seq[ProofStep]; curIdx, startLine, endLine: int): bool =
  if startLine < 1 or endLine < startLine or endLine > curIdx:
    return false
  let sIdx = startLine - 1
  let eIdx = endLine - 1
  let subDepth = steps[curIdx].depth + 1
  if steps[sIdx].rule != prAssump or steps[sIdx].depth != subDepth:
    return false
  if steps[eIdx].depth != subDepth:
    return false
  for i in sIdx .. eIdx:
    if steps[i].depth < subDepth:
      return false
  true

proc isModalDualPair(a, b: WffNode): bool =
  # ¬□X <-> ◇¬X or ¬◇X <-> □¬X
  if a.sym == symN and a.left.sym == symL and b.sym == symM and b.left.sym == symN:
    return wffEquals(a.left.left, b.left.left)
  if a.sym == symM and a.left.sym == symN and b.sym == symN and b.left.sym == symL:
    return wffEquals(a.left.left, b.left.left)
  if a.sym == symN and a.left.sym == symM and b.sym == symL and b.left.sym == symN:
    return wffEquals(a.left.left, b.left.left)
  if a.sym == symL and a.left.sym == symN and b.sym == symN and b.left.sym == symM:
    return wffEquals(a.left.left, b.left.left)
  false

proc verifyProof*(
  rawSteps: seq[ProofStep];
  goalPolish: string;
  system: ModalSystem;
): ProofCheckResult =
  result.steps = rawSteps
  var allOk = true

  for idx in 0 ..< result.steps.len:
    var st = result.steps[idx]
    st.lineNo = idx + 1
    let parsed = parseWffString(st.formula)
    if not parsed.isWff:
      st.valid = false
      st.message = "Invalid WFF: " & parsed.errorMsg
      result.steps[idx] = st
      allOk = false
      continue
    st.node = parsed.root
    st.formula = parsed.polish

    case st.rule
    of prPremise:
      if st.depth != 0:
        st.valid = false
        st.message = "Premises must be at top-level depth 0."
      else:
        st.valid = true
        st.message = "Given premise."
    of prAssump:
      if st.depth < 1:
        st.valid = false
        st.message = "Subproof assumptions must have depth >= 1."
      else:
        st.valid = true
        st.message = "Opened Fitch subproof."
    of prR:
      if st.refs.len == 1 and isAccessible(result.steps, idx, st.refs[0]):
        let src = result.steps[st.refs[0] - 1]
        if src.valid and wffEquals(src.node, st.node):
          st.valid = true
          st.message = fmt"Reiterated line {st.refs[0]}."
        else:
          st.valid = false
          st.message = "Reiteration requires an identical accessible formula."
      else:
        st.valid = false
        st.message = "R requires 1 accessible line reference."
    of prCo:
      if st.refs.len == 2 and isAccessible(result.steps, idx, st.refs[0]) and isAccessible(result.steps, idx, st.refs[1]):
        let a = result.steps[st.refs[0] - 1]
        let b = result.steps[st.refs[1] - 1]
        let ok1 = a.valid and b.valid and a.node.sym == symC and wffEquals(a.node.left, b.node) and wffEquals(a.node.right, st.node)
        let ok2 = a.valid and b.valid and b.node.sym == symC and wffEquals(b.node.left, a.node) and wffEquals(b.node.right, st.node)
        if ok1 or ok2:
          st.valid = true
          st.message = fmt"Modus Ponens (Co) from lines {st.refs[0]}, {st.refs[1]}."
        else:
          st.valid = false
          st.message = "Co requires CAB and A to derive B."
      else:
        st.valid = false
        st.message = "Co requires 2 accessible line references."
    of prCi:
      if st.refs.len == 2 and isClosedSubproof(result.steps, idx, st.refs[0], st.refs[1]):
        let s = result.steps[st.refs[0] - 1]
        let e = result.steps[st.refs[1] - 1]
        if s.valid and e.valid and st.node.sym == symC and wffEquals(st.node.left, s.node) and wffEquals(st.node.right, e.node):
          st.valid = true
          st.message = fmt"Conditional Proof (Ci) discharging subproof {st.refs[0]}–{st.refs[1]}."
        else:
          st.valid = false
          st.message = "Ci requires C(Assump)(Conclusion) from subproof."
      else:
        st.valid = false
        st.message = "Ci requires start & end lines of an immediately nested subproof."
    of prKi:
      if st.refs.len == 2 and isAccessible(result.steps, idx, st.refs[0]) and isAccessible(result.steps, idx, st.refs[1]):
        let a = result.steps[st.refs[0] - 1]
        let b = result.steps[st.refs[1] - 1]
        if a.valid and b.valid and st.node.sym == symK and
           ((wffEquals(st.node.left, a.node) and wffEquals(st.node.right, b.node)) or
            (wffEquals(st.node.left, b.node) and wffEquals(st.node.right, a.node))):
          st.valid = true
          st.message = fmt"Conjunction Intro (Ki) from lines {st.refs[0]}, {st.refs[1]}."
        else:
          st.valid = false
          st.message = "Ki requires A and B to form KAB."
      else:
        st.valid = false
        st.message = "Ki requires 2 accessible lines."
    of prKo:
      if st.refs.len == 1 and isAccessible(result.steps, idx, st.refs[0]):
        let a = result.steps[st.refs[0] - 1]
        if a.valid and a.node.sym == symK and (wffEquals(a.node.left, st.node) or wffEquals(a.node.right, st.node)):
          st.valid = true
          st.message = fmt"Conjunction Elim (Ko) from line {st.refs[0]}."
        else:
          st.valid = false
          st.message = "Ko extracts either conjunct from KAB."
      else:
        st.valid = false
        st.message = "Ko requires 1 accessible conjunction line."
    of prAi:
      if st.refs.len == 1 and isAccessible(result.steps, idx, st.refs[0]):
        let a = result.steps[st.refs[0] - 1]
        if a.valid and st.node.sym == symA and (wffEquals(st.node.left, a.node) or wffEquals(st.node.right, a.node)):
          st.valid = true
          st.message = fmt"Disjunction Intro (Ai) from line {st.refs[0]}."
        else:
          st.valid = false
          st.message = "Ai forms A(X)(Y) where X or Y matches the referenced line."
      else:
        st.valid = false
        st.message = "Ai requires 1 accessible line."
    of prAo:
      if st.refs.len == 3 and isAccessible(result.steps, idx, st.refs[0]) and
         isAccessible(result.steps, idx, st.refs[1]) and isAccessible(result.steps, idx, st.refs[2]):
        let disj = result.steps[st.refs[0] - 1]
        let c1 = result.steps[st.refs[1] - 1]
        let c2 = result.steps[st.refs[2] - 1]
        if disj.valid and c1.valid and c2.valid and
           disj.node.sym == symA and c1.node.sym == symC and c2.node.sym == symC and
           wffEquals(c1.node.left, disj.node.left) and wffEquals(c2.node.left, disj.node.right) and
           wffEquals(c1.node.right, st.node) and wffEquals(c2.node.right, st.node):
          st.valid = true
          st.message = fmt"Disjunction Elim (Ao) from lines {st.refs[0]}, {st.refs[1]}, {st.refs[2]}."
        else:
          st.valid = false
          st.message = "Ao requires AXY, CXZ, and CYZ to conclude Z."
      else:
        st.valid = false
        st.message = "Ao requires 3 accessible lines (disjunction + two conditionals)."
    of prNi:
      if st.refs.len == 3 and isClosedSubproof(result.steps, idx, st.refs[0], st.refs[1]) and
         st.refs[2] >= st.refs[0] and st.refs[2] <= st.refs[1]:
        let s = result.steps[st.refs[0] - 1]
        let e1 = result.steps[st.refs[1] - 1]
        let e2 = result.steps[st.refs[2] - 1]
        let contra = (e1.node.sym == symN and wffEquals(e1.node.left, e2.node)) or
                     (e2.node.sym == symN and wffEquals(e2.node.left, e1.node))
        if s.valid and e1.valid and e2.valid and contra and st.node.sym == symN and wffEquals(st.node.left, s.node):
          st.valid = true
          st.message = fmt"Negation Intro / Reductio (Ni) from subproof {st.refs[0]}–{st.refs[1]}."
        else:
          st.valid = false
          st.message = "Ni requires a subproof assuming X that derives B and NB."
      else:
        st.valid = false
        st.message = "Ni requires [subproofStart, subproofEnd, contraLine]."
    of prNo:
      if st.refs.len == 1 and isAccessible(result.steps, idx, st.refs[0]):
        let a = result.steps[st.refs[0] - 1]
        if a.valid and a.node.sym == symN and a.node.left.sym == symN and wffEquals(a.node.left.left, st.node):
          st.valid = true
          st.message = fmt"Double Negation Elim (No) from line {st.refs[0]}."
        else:
          st.valid = false
          st.message = "No removes NN from NNX to yield X."
      else:
        st.valid = false
        st.message = "No requires 1 accessible line of form NNX."
    of prEi:
      if st.refs.len == 2 and isAccessible(result.steps, idx, st.refs[0]) and isAccessible(result.steps, idx, st.refs[1]):
        let a = result.steps[st.refs[0] - 1]
        let b = result.steps[st.refs[1] - 1]
        if a.valid and b.valid and a.node.sym == symC and b.node.sym == symC and
           wffEquals(a.node.left, b.node.right) and wffEquals(a.node.right, b.node.left) and
           st.node.sym == symE and wffEquals(st.node.left, a.node.left) and wffEquals(st.node.right, a.node.right):
          st.valid = true
          st.message = fmt"Biconditional Intro (Ei) from lines {st.refs[0]}, {st.refs[1]}."
        else:
          st.valid = false
          st.message = "Ei requires CXY and CYX to derive EXY."
      else:
        st.valid = false
        st.message = "Ei requires 2 accessible converse conditionals."
    of prEo:
      if st.refs.len == 1 and isAccessible(result.steps, idx, st.refs[0]):
        let a = result.steps[st.refs[0] - 1]
        if a.valid and a.node.sym == symE and st.node.sym == symC and
           ((wffEquals(st.node.left, a.node.left) and wffEquals(st.node.right, a.node.right)) or
            (wffEquals(st.node.left, a.node.right) and wffEquals(st.node.right, a.node.left))):
          st.valid = true
          st.message = fmt"Biconditional Elim (Eo) from line {st.refs[0]}."
        else:
          st.valid = false
          st.message = "Eo extracts CXY or CYX from EXY."
      else:
        st.valid = false
        st.message = "Eo requires 1 accessible biconditional line."
    of prNec:
      if system == msProp:
        st.valid = false
        st.message = "Necessitation requires Modal System K, T, S4, or S5."
      elif st.refs.len == 1 and isAccessible(result.steps, idx, st.refs[0]):
        let a = result.steps[st.refs[0] - 1]
        var hasOpenPremise = false
        for j in 0 ..< idx:
          if result.steps[j].rule in {prPremise, prAssump} and result.steps[j].depth <= st.depth:
            hasOpenPremise = true
            break
        if hasOpenPremise:
          st.valid = false
          st.message = "Necessitation only applies to pure theorems (no open premises/assumptions)."
        elif a.valid and st.node.sym == symL and wffEquals(st.node.left, a.node):
          st.valid = true
          st.message = fmt"Necessitation (Nec): ⊢ {a.formula} yields ⊢ □{a.formula}."
        else:
          st.valid = false
          st.message = "Nec wraps a proven theorem X into LX (□X)."
      else:
        st.valid = false
        st.message = "Nec requires 1 accessible theorem line."
    of prKDist:
      if system == msProp:
        st.valid = false
        st.message = "Axiom K Distribution requires Modal System K, T, S4, or S5."
      elif st.refs.len == 2 and isAccessible(result.steps, idx, st.refs[0]) and isAccessible(result.steps, idx, st.refs[1]):
        let a = result.steps[st.refs[0] - 1]
        let b = result.steps[st.refs[1] - 1]
        let ok1 = a.valid and b.valid and a.node.sym == symL and a.node.left.sym == symC and
                  b.node.sym == symL and st.node.sym == symL and
                  wffEquals(a.node.left.left, b.node.left) and wffEquals(a.node.left.right, st.node.left)
        let ok2 = a.valid and b.valid and b.node.sym == symL and b.node.left.sym == symC and
                  a.node.sym == symL and st.node.sym == symL and
                  wffEquals(b.node.left.left, a.node.left) and wffEquals(b.node.left.right, st.node.left)
        if ok1 or ok2:
          st.valid = true
          st.message = fmt"Modal K-Distribution from lines {st.refs[0]}, {st.refs[1]}."
        else:
          st.valid = false
          st.message = "K-Dist requires □(X→Y) and □X to derive □Y."
      else:
        st.valid = false
        st.message = "K-Dist requires 2 accessible lines: LCXY and LX."
    of prTElim:
      if system notin {msT, msS4, msS5}:
        st.valid = false
        st.message = "Axiom T (□X → X) requires System T, S4, or S5 (reflexive frames)."
      elif st.refs.len == 1 and isAccessible(result.steps, idx, st.refs[0]):
        let a = result.steps[st.refs[0] - 1]
        if a.valid and a.node.sym == symL and wffEquals(a.node.left, st.node):
          st.valid = true
          st.message = fmt"Axiom T Elimination (□X → X) from line {st.refs[0]}."
        else:
          st.valid = false
          st.message = "T-Elim derives X from LX (□X)."
      else:
        st.valid = false
        st.message = "T-Elim requires 1 accessible line of form LX."
    of prFourIntro:
      if system notin {msS4, msS5}:
        st.valid = false
        st.message = "Axiom 4 (□X → □□X) requires System S4 or S5 (transitive frames)."
      elif st.refs.len == 1 and isAccessible(result.steps, idx, st.refs[0]):
        let a = result.steps[st.refs[0] - 1]
        if a.valid and a.node.sym == symL and st.node.sym == symL and wffEquals(st.node.left, a.node):
          st.valid = true
          st.message = fmt"Axiom 4 Intro (□X → □□X) from line {st.refs[0]}."
        else:
          st.valid = false
          st.message = "4-Intro derives LLX from LX."
      else:
        st.valid = false
        st.message = "4-Intro requires 1 accessible line of form LX."
    of prFiveIntro:
      if system != msS5:
        st.valid = false
        st.message = "Axiom 5 (◇X → □◇X) requires System S5 (equivalence frames)."
      elif st.refs.len == 1 and isAccessible(result.steps, idx, st.refs[0]):
        let a = result.steps[st.refs[0] - 1]
        if a.valid and a.node.sym == symM and st.node.sym == symL and wffEquals(st.node.left, a.node):
          st.valid = true
          st.message = fmt"Axiom 5 Intro (◇X → □◇X) from line {st.refs[0]}."
        else:
          st.valid = false
          st.message = "5-Intro derives LMX from MX."
      else:
        st.valid = false
        st.message = "5-Intro requires 1 accessible line of form MX."
    of prDual:
      if system == msProp:
        st.valid = false
        st.message = "Modal Duality requires Modal System K, T, S4, or S5."
      elif st.refs.len == 1 and isAccessible(result.steps, idx, st.refs[0]):
        let a = result.steps[st.refs[0] - 1]
        if a.valid and isModalDualPair(a.node, st.node):
          st.valid = true
          st.message = fmt"Modal Duality from line {st.refs[0]}."
        else:
          st.valid = false
          st.message = "Dual swaps ¬□X ↔ ◇¬X or ¬◇X ↔ □¬X."
      else:
        st.valid = false
        st.message = "Dual requires 1 accessible modal negation line."

    if not st.valid:
      allOk = false
    result.steps[idx] = st

  result.allValid = allOk
  let goalParsed = parseWffString(goalPolish)
  if allOk and goalParsed.isWff and result.steps.len > 0:
    let last = result.steps[^1]
    if last.depth == 0 and last.valid and wffEquals(last.node, goalParsed.root):
      result.goalReached = true

  if result.goalReached:
    result.summary = fmt"Q.E.D.! Proof verified in {systemShortName(system)}: proved {goalParsed.infix}."
  elif allOk:
    result.summary = fmt"All {result.steps.len} step(s) valid so far. Derive {goalPolish} at depth 0 to complete."
  else:
    result.summary = "Proof has an invalid step — inspect the highlighted line."
