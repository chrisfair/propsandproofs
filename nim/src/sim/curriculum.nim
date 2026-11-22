## 16-lesson interactive Props & Proofs & Modal Logic Academy curriculum.

import std/strformat
import types, logic

type
  LessonCheckKind* = enum
    lckExactPolish      # Must match a specific Polish formula
    lckAnyWffMinLen     # Must be any valid WFF of length >= targetLen
    lckPropTautology    # Must be a valid propositional tautology of length >= targetLen
    lckModalValidIn     # Must be a modal WFF valid in `system` (and optionally invalid in a weaker system)

  LessonDef* = object
    id*: int
    track*: string
    title*: string
    system*: ModalSystem
    explanation*: string
    walkthrough*: string
    whyItMatters*: string
    task*: string
    hint*: string
    palette*: seq[Symbol]
    checkKind*: LessonCheckKind
    targetPolish*: string
    targetLen*: int
    requireModal*: bool
    mustFailSystem*: ModalSystem
    hasFailCheck*: bool
    examplePolish*: string

const Lessons*: array[16, LessonDef] = [
  LessonDef(
    id: 1,
    track: "Track 1: Polish Notation",
    title: "1. Atoms & Simple Negation (p, Np)",
    system: msProp,
    explanation: "In logic, lowercase letters p, q, r, s are atoms — stand-ins for any true-or-false claim (like 'p = it is raining'). Any single atom is already a Well-Formed Formula (WFF). Put N ('not') in front of a WFF to negate it.",
    walkthrough: "p  =  'p' (1 cube, valid WFF).   Prefix N -> Np  =  ¬p ('not p').   Notice the operator comes BEFORE its input, like a function not(p).",
    whyItMatters: "Every cube in Props & Proofs is either an atom (0 inputs), a unary operator (1 input), or a binary operator (2 inputs). N always grabs the very next WFF.",
    task: "Build the negation of p (¬p) using two cubes: Np.",
    hint: "Click N first, then click p. Watch the Live Formula Inspector on the right translate Np into ¬p.",
    palette: @[symN, symP, symQ],
    checkKind: lckExactPolish,
    targetPolish: "Np",
    targetLen: 2,
    examplePolish: "Np",
  ),
  LessonDef(
    id: 2,
    track: "Track 1: Polish Notation",
    title: "2. Stacking Unary Operators (NNp)",
    system: msProp,
    explanation: "Because N expects 1 WFF immediately after it, you can chain unary operators without ever needing parentheses. Each N simply wraps the entire WFF that follows it.",
    walkthrough: "Read from inside out: p is a WFF -> Np is ¬p -> NNp is ¬(¬p), 'not not p'.   Slot rule: N consumes 1 slot and opens 1 new slot, so it never changes how many atoms you need.",
    whyItMatters: "In WFF Sprint and the 3-Zone Mat, unary cubes (N, L, M) are free length boosters — you can stack them in front of any valid formula without needing extra atoms.",
    task: "Build the double negation of p (¬¬p): NNp.",
    hint: "Click N, then N, then p. Check the truth table on the right: NNp has the exact same truth values as p.",
    palette: @[symN, symN, symP, symQ],
    checkKind: lckExactPolish,
    targetPolish: "NNp",
    targetLen: 3,
    examplePolish: "NNp",
  ),
  LessonDef(
    id: 3,
    track: "Track 1: Polish Notation",
    title: "3. Binary Connectives First (C, K, A, E)",
    system: msProp,
    explanation: "Four uppercase cubes join TWO WFFs: C = → (if-then), K = ∧ (and), A = ∨ (or), E = ↔ (if and only if). In Polish (prefix) notation, the connective always goes FIRST, followed by its left input, then its right input.",
    walkthrough: "Cpq  =  (p → q) 'if p then q'.   Kpq  =  (p ∧ q) 'p and q'.   Apq  =  (p ∨ q) 'p or q'.   Epq  =  (p ↔ q) 'p iff q'.",
    whyItMatters: "Putting the connective first removes all ambiguity about grouping — you never need parentheses, which is why a logic game can be played with physical dice!",
    task: "Build 'if p then q' (p → q) in Polish notation: Cpq.",
    hint: "Click C (the operator goes first), then p (left side), then q (right side).",
    palette: @[symC, symK, symA, symE, symP, symQ],
    checkKind: lckExactPolish,
    targetPolish: "Cpq",
    targetLen: 3,
    examplePolish: "Cpq",
  ),
  LessonDef(
    id: 4,
    track: "Track 1: Polish Notation",
    title: "4. Nesting Without Parentheses (CKpqr)",
    system: msProp,
    explanation: "To nest one binary formula inside another, just place the inner formula where an atom would go. Polish notation makes the grouping 100% unambiguous by position alone.",
    walkthrough: "Compare these two:  CKpqr = C [Kpq] [r] = ((p ∧ q) → r).   CpKqr = C [p] [Kqr] = (p → (q ∧ r)).   Start from the outermost connective and fill its 1st slot, then its 2nd slot.",
    whyItMatters: "Reading left-to-right by 'outer operator, then 1st chunk, then 2nd chunk' is the core skill for every mode in Props & Proofs.",
    task: "Build ((p ∧ q) → r) in Polish notation: CKpqr.",
    hint: "Outer operator is C (→). Its 1st input is Kpq (p ∧ q). Its 2nd input is r. Put them together: C, K, p, q, r.",
    palette: @[symC, symK, symA, symP, symQ, symR],
    checkKind: lckExactPolish,
    targetPolish: "CKpqr",
    targetLen: 5,
    examplePolish: "CKpqr",
  ),
  LessonDef(
    id: 5,
    track: "Track 1: Polish Notation",
    title: "5. The Slot-Counting Trick (WFF Sprint)",
    system: msProp,
    explanation: "How do you know if a long string of cubes is a valid WFF? Count open slots! Start at 1 open slot. Each binary (C,K,A,E) adds +1 slot; each unary (N,L,M) adds +0; each atom (p,q,r,s) fills -1 slot. You have a valid WFF when slots hit 0 on the final cube.",
    walkthrough: "Example CApqKrs:  start(1) -> C(+1=2) -> A(+1=3) -> p(-1=2) -> q(-1=1) -> K(+1=2) -> r(-1=1) -> s(-1=0, DONE!).   Shortcut: B binaries always require exactly B + 1 atoms.",
    whyItMatters: "In WFF Game (Dice Sprint), you can instantly compute your maximum possible score: take ALL unaries, plus B binaries and B + 1 atoms!",
    task: "Build any valid WFF of at least 7 cubes using the palette below.",
    hint: "Use 3 binary operators and 4 atoms (3 + 4 = 7), like CApqKrs, or add N in front of a 6-cube WFF. Watch the Live Slot Tracker on the right!",
    palette: @[symC, symK, symA, symN, symP, symQ, symR, symS],
    checkKind: lckAnyWffMinLen,
    targetLen: 7,
    examplePolish: "CApqKrs",
  ),
  LessonDef(
    id: 6,
    track: "Track 1: Polish Notation",
    title: "6. Truth Tables & Tautologies",
    system: msProp,
    explanation: "A truth table tests every T/F combination of atoms. A formula that comes out True in EVERY row is a Tautology (a law of logic). Remember: 'p → q' (Cpq) is only False when p is True and q is False; if p is False, 'p → q' is True!",
    walkthrough: "ApNp (p ∨ ¬p, Excluded Middle): if p=T then T∨F=T; if p=F then F∨T=T.   CpCqp (p → (q → p)): true in all 4 rows.   Cpp (p → p): true in both rows.",
    whyItMatters: "Tautologies are the building blocks of proofs. When you build a formula, the right panel automatically evaluates its truth table and flags Tautology / Contingent / Contradiction.",
    task: "Build any Propositional Tautology of at least 4 cubes (e.g., ApNp or CpCqp).",
    hint: "Try A, p, N, p for (p ∨ ¬p), or C, p, C, q, p for (p → (q → p)). If a row is F, the feedback will tell you which row failed.",
    palette: @[symC, symA, symK, symN, symP, symQ, symP],
    checkKind: lckPropTautology,
    targetLen: 4,
    examplePolish: "ApNp",
  ),
  LessonDef(
    id: 7,
    track: "Track 2: Strategy & Proofs",
    title: "7. Contraposition (CCpqCNqNp)",
    system: msProp,
    explanation: "The statement 'if p then q' (p → q) always says the exact same thing as its contrapositive 'if not q then not p' (¬q → ¬p). Example: 'If it rains, the street is wet' means 'If the street is NOT wet, it did NOT rain.'",
    walkthrough: "Break it into 3 pieces:  outer C (→),  left piece Cpq (p → q),  right piece CNqNp (¬q → ¬p).   Concatenate: C + Cpq + CNqNp = CCpqCNqNp.",
    whyItMatters: "Chunking long formulas into [outer] + [left] + [right] lets you read and build 9-cube formulas effortlessly without losing track of nesting.",
    task: "Build the Contraposition law ((p → q) → (¬q → ¬p)): CCpqCNqNp.",
    hint: "Click C, then C, p, q (left side), then C, N, q, N, p (right side).",
    palette: @[symC, symC, symC, symN, symN, symP, symP, symQ, symQ],
    checkKind: lckExactPolish,
    targetPolish: "CCpqCNqNp",
    targetLen: 9,
    examplePolish: "CCpqCNqNp",
  ),
  LessonDef(
    id: 8,
    track: "Track 2: Strategy & Proofs",
    title: "8. Rewriting Implication (ECpqANpq)",
    system: msProp,
    explanation: "Because (p → q) is only False when p is True and q is False, it is logically equivalent to (¬p ∨ q) — 'either p is false, or q is true.' The biconditional E (↔) asserts that both sides always have the exact same truth value.",
    walkthrough: "Outer E (↔) joins two chunks:  left chunk Cpq (p → q),  right chunk ANpq (¬p ∨ q).   Together: E + Cpq + ANpq = ECpqANpq.",
    whyItMatters: "In logic and in the 3-Zone Mat, if your opponent puts C into FORBIDDEN, you can express the same idea using A (∨) and N (¬) instead.",
    task: "Build the equivalence (p → q) ↔ (¬p ∨ q): ECpqANpq.",
    hint: "Click E, then C, p, q, then A, N, p, q. Verify on the right that all 4 truth-table rows are True.",
    palette: @[symE, symC, symA, symN, symP, symP, symQ, symQ],
    checkKind: lckExactPolish,
    targetPolish: "ECpqANpq",
    targetLen: 8,
    examplePolish: "ECpqANpq",
  ),
  LessonDef(
    id: 9,
    track: "Track 2: Strategy & Proofs",
    title: "9. How to Win the 3-Zone Proof Mat",
    system: msProp,
    explanation: "In 3-Zone Proof Mat, you and the AI alternate moving 1 Resource cube into REQUIRED (must use), PERMITTED (may use), or FORBIDDEN (banned). Goal: a valid WFF of >= 5 cubes. Call 'NOW!' (+6 pts) once Required + Permitted already form a Goal; call 'IMPOSSIBLE!' (+6 pts) if the AI's move broke all solutions.",
    walkthrough: "Watch the atom-to-binary balance! A 5-cube WFF needs e.g. 2 binaries + 3 atoms (CKpqr), or 1 unary + 1 binary + 2 atoms + 1 more unary (NNCpq). If too many atoms go to FORBIDDEN, no valid WFF can be built -> call IMPOSSIBLE!",
    whyItMatters: "This is the heart of classic WFF 'N PROOF: you don't build the formula every turn — you constrain the board and challenge the exact moment a solution becomes ready or impossible.",
    task: "Practice building a 5+ cube Mat Goal WFF from these cubes (e.g., CKpqr or NNCpq).",
    hint: "Try C, K, p, q, r (2 binaries + 3 atoms = 5 cubes) or N, C, K, p, q, r (6 cubes).",
    palette: @[symC, symK, symN, symP, symQ, symR],
    checkKind: lckAnyWffMinLen,
    targetLen: 5,
    examplePolish: "CKpqr",
  ),
  LessonDef(
    id: 10,
    track: "Track 2: Strategy & Proofs",
    title: "10. Fitch Proofs & Modus Ponens",
    system: msProp,
    explanation: "In the Proof & Kripke Lab, you derive a Goal step-by-step from Premises using inference rules. The most famous rule is Modus Ponens (Co): if you have p and (p → q), you may conclude q. Subproofs (Depth 1) let you temporarily Assume φ to prove ψ, then discharge with Ci to conclude Cφψ.",
    walkthrough: "Modus Ponens as a single tautology is ((p ∧ (p → q)) → q):  outer C,  left side KpCpq (p ∧ (p → q)),  right side q.   Result: CKpCpqq.",
    whyItMatters: "When you open the Proof Lab, select a rule button (like Co, Ko, Ci) to read its exact Ref1/Ref2 guide right above the rule strip, or click 'Show Proof' to study a worked Fitch derivation.",
    task: "Build the Modus Ponens tautology ((p ∧ (p → q)) → q): CKpCpqq.",
    hint: "Click C (outer →), then K (∧), then p, then C, p, q (p → q), then q (conclusion): CKpCpqq.",
    palette: @[symC, symC, symK, symP, symP, symQ, symQ],
    checkKind: lckExactPolish,
    targetPolish: "CKpCpqq",
    targetLen: 7,
    examplePolish: "CKpCpqq",
  ),
  LessonDef(
    id: 11,
    track: "Track 3: Modal Logic",
    title: "11. Possible Worlds: □ (L) & ◇ (M)",
    system: msK,
    explanation: "Modal logic adds two unary operators for 'possible worlds' connected by arrows (accessibility): L = □ ('necessarily p' — p is true in EVERY world reachable by an arrow) and M = ◇ ('possibly p' — p is true in AT LEAST ONE reachable world).",
    walkthrough: "Just like N, both L and M take 1 WFF right after them:  Lp = □p,  Mp = ◇p.   Join them with C (→):  CLpMp = (□p → ◇p), 'if necessarily p, then possibly p.'",
    whyItMatters: "Notice after building CLpMp that it is INVALID in System K! Why? If a world w0 has NO outgoing arrows, □p is vacuously True while ◇p is False. In System T (where every world sees itself), CLpMp becomes VALID!",
    task: "Build 'if necessarily p, then possibly p' (□p → ◇p): CLpMp.",
    hint: "Click C, then L, p (□p), then M, p (◇p). Inspect the Kripke graph on the right to see the dead-end world w0!",
    palette: @[symC, symL, symM, symN, symP, symP, symQ],
    checkKind: lckExactPolish,
    targetPolish: "CLpMp",
    targetLen: 5,
    examplePolish: "CLpMp",
  ),
  LessonDef(
    id: 12,
    track: "Track 3: Modal Logic",
    title: "12. Modal Duality (¬□p ↔ ◇¬p)",
    system: msK,
    explanation: "Necessity (□) and Possibility (◇) are mirror opposites, just like 'all' and 'some'. Saying 'p is NOT true in every reachable world' (¬□p) means the exact same thing as 'there is at least one reachable world where p is FALSE' (◇¬p).",
    walkthrough: "Outer E (↔) connects two unary chains:  left side NLp (¬□p),  right side MNp (◇¬p).   Together: ENLpMNp.",
    whyItMatters: "Modal Duality holds in EVERY normal modal system (K, T, S4, S5). In the Proof Lab, the 'Dual' rule lets you flip ¬□ into ◇¬ (or ¬◇ into □¬) in a single step.",
    task: "Build the Modal Duality law ¬□p ↔ ◇¬p: ENLpMNp.",
    hint: "Click E, then N, L, p, then M, N, p. Watch all four modal badges (K, T, S4, S5) light up green VALID!",
    palette: @[symE, symN, symN, symL, symM, symP, symP],
    checkKind: lckExactPolish,
    targetPolish: "ENLpMNp",
    targetLen: 7,
    examplePolish: "ENLpMNp",
  ),
  LessonDef(
    id: 13,
    track: "Track 3: Modal Logic",
    title: "13. System K & Reading Kripke Graphs",
    system: msK,
    explanation: "System K is the baseline modal logic: arrows between worlds can be arranged in ANY way (even dead-ends or one-way streets). Its defining law is Axiom K: if (p → q) holds in all reachable worlds AND p holds in all reachable worlds, then q must hold in all reachable worlds too.",
    walkthrough: "Break Axiom K into 3 chunks:  outer C,  left LCpq = □(p → q),  right CLpLq = (□p → □q).   Together: CLCpqCLpLq.",
    whyItMatters: "When any modal formula is INVALID, the right panel draws a Kripke countermodel: circles are worlds (w0, w1...), arrows show accessibility, and the red circle is the world where φ is False (φ:F).",
    task: "Build Axiom K (□(p → q) → (□p → □q)): CLCpqCLpLq.",
    hint: "Click C, then L, C, p, q, then C, L, p, L, q. Every modal system (K, T, S4, S5) validates Axiom K.",
    palette: @[symC, symC, symC, symL, symL, symL, symP, symP, symQ, symQ],
    checkKind: lckExactPolish,
    targetPolish: "CLCpqCLpLq",
    targetLen: 10,
    examplePolish: "CLCpqCLpLq",
  ),
  LessonDef(
    id: 14,
    track: "Track 3: Modal Logic",
    title: "14. System T (Reflexivity): □p → p",
    system: msT,
    explanation: "In System K, □p → p ('if p is necessary, then p is true here') FAILS because world w0 might not have an arrow to itself — so □p ignores w0! System T adds Reflexivity: every world has a self-loop arrow (wRw), guaranteeing □p → p.",
    walkthrough: "CLpp = (□p → p).   Its dual CpMp = (p → ◇p) also characterizes T: since w0 can see itself, if p is true here, p is at least possible!",
    whyItMatters: "Look at the Kripke graph on the right after you build CLpp: it shows the K countermodel (w0 with p:F and NO self-loop) right beside the green T / S4 / S5 VALID badges!",
    task: "Build a modal formula valid in System T that FAILS in System K (e.g., Axiom T: CLpp).",
    hint: "Click C, L, p, p for □p → p (or C, p, M, p for p → ◇p).",
    palette: @[symC, symL, symM, symP, symP, symQ],
    checkKind: lckModalValidIn,
    targetLen: 4,
    requireModal: true,
    mustFailSystem: msK,
    hasFailCheck: true,
    examplePolish: "CLpp",
  ),
  LessonDef(
    id: 15,
    track: "Track 3: Modal Logic",
    title: "15. System S4 (Transitivity): □p → □□p",
    system: msS4,
    explanation: "System S4 adds Transitivity to T: if w0 sees w1 and w1 sees w2, then w0 must also see w2 directly. Without that shortcut, □p can be true at w0 while p is false two hops away at w2 — breaking □p → □□p.",
    walkthrough: "CLpLLp = (□p → □□p), called Axiom 4.   Think of □ as 'it is provable' or 'I know': if you know p, you know that you know p (positive introspection).",
    whyItMatters: "S4 is the standard logic of mathematical provability and knowledge. In the Proof Lab, S4 unlocks the 4-Intro rule (from □p, infer □□p).",
    task: "Build a modal formula valid in S4 that FAILS in System T (e.g., Axiom 4: CLpLLp).",
    hint: "Click C, L, p, L, L, p to form CLpLLp (□p → □□p). Notice K and T are INVALID while S4 and S5 are VALID.",
    palette: @[symC, symL, symL, symL, symM, symP, symP],
    checkKind: lckModalValidIn,
    targetLen: 5,
    requireModal: true,
    mustFailSystem: msT,
    hasFailCheck: true,
    examplePolish: "CLpLLp",
  ),
  LessonDef(
    id: 16,
    track: "Track 3: Modal Logic",
    title: "16. System S5 (Symmetry): ◇p → □◇p",
    system: msS5,
    explanation: "System S5 adds Symmetry to S4: if w0 sees w1, then w1 sees w0 back. That turns accessibility into an equivalence relation where every world in a cluster sees every other world — so what is possible never depends on which world you stand in.",
    walkthrough: "CMpLMp = (◇p → □◇p), called Axiom 5 ('if p is possible, it is necessarily possible').   Another S5 law is Axiom B: CpLMp (p → □◇p).",
    whyItMatters: "S5 is the strongest standard modal system (metaphysical necessity). You now have all the tools to play WFF Sprint, 3-Zone Proof Mat, and build Fitch proofs in the Proof & Kripke Lab!",
    task: "Build a modal formula valid in S5 that FAILS in S4 (e.g., Axiom 5: CMpLMp or B: CpLMp).",
    hint: "Click C, M, p, L, M, p to form CMpLMp (◇p → □◇p), or C, p, L, M, p for CpLMp.",
    palette: @[symC, symL, symM, symM, symP, symP],
    checkKind: lckModalValidIn,
    targetLen: 5,
    requireModal: true,
    mustFailSystem: msS4,
    hasFailCheck: true,
    examplePolish: "CMpLMp",
  ),
]

proc evaluateLesson*(lessonIdx: int; syms: openArray[Symbol]): (bool, string) =
  let lesson = Lessons[clamp(lessonIdx, 0, Lessons.high)]
  let parsed = parseWff(syms)
  if not parsed.isWff:
    let tr = polishSlotTrace(syms)
    return (false, fmt"{parsed.errorMsg}  ({tr.summary})")

  case lesson.checkKind
  of lckExactPolish:
    if parsed.polish == lesson.targetPolish:
      return (true, fmt"Correct! {parsed.polish} = {parsed.infix}. Ready for the next lesson!")
    return (false, fmt"Valid WFF ({parsed.polish} = {parsed.infix}), but this lesson asks for {lesson.targetPolish}. Check the Walkthrough or Toggle Hint.")
  of lckAnyWffMinLen:
    if syms.len >= lesson.targetLen:
      return (true, fmt"Great WFF of length {syms.len}: {parsed.polish} = {parsed.infix}!")
    return (false, fmt"Valid WFF ({parsed.polish}), but you need at least {lesson.targetLen} cubes (currently {syms.len}). Add a unary (N) or a binary + atom!")
  of lckPropTautology:
    if parsed.hasModal:
      return (false, "Use propositional cubes only (no L or M) for this lesson.")
    if syms.len < lesson.targetLen:
      return (false, fmt"Valid WFF, but need at least {lesson.targetLen} cubes (currently {syms.len}).")
    let tt = evalTruthTable(parsed.root)
    if tt.isTautology:
      return (true, fmt"Verified Tautology! {parsed.infix} is True in all {tt.rows.len} truth-table rows.")
    var failDesc = ""
    for row in tt.rows:
      if not row.value:
        for aIdx, a in tt.atoms:
          if aIdx > 0: failDesc.add(", ")
          let b = ((row.bits shr (tt.atoms.len - 1 - aIdx)) and 1) == 1
          let vStr = if b: "T" else: "F"
          failDesc.add(fmt"{a.polishChar()}={vStr}")
        break
    return (false, fmt"{parsed.infix} is not a tautology — it is False when {failDesc}. Check the Truth Table on the right!")
  of lckModalValidIn:
    if lesson.requireModal and not parsed.hasModal:
      return (false, "Include at least one modal operator (L = □ or M = ◇).")
    if syms.len < lesson.targetLen:
      return (false, fmt"Need at least {lesson.targetLen} cubes (currently {syms.len}).")
    let checkTarget = checkModalValidity(parsed.root, lesson.system)
    if not checkTarget.valid:
      return (false, fmt"Not valid in {systemShortName(lesson.system)}: {checkTarget.summary}")
    if lesson.hasFailCheck:
      let checkWeaker = checkModalValidity(parsed.root, lesson.mustFailSystem)
      if checkWeaker.valid:
        return (false, fmt"Valid in {systemShortName(lesson.system)}, but also valid in {systemShortName(lesson.mustFailSystem)}! Try a formula specific to {systemShortName(lesson.system)} like {lesson.examplePolish}.")
    return (true, fmt"Verified! {parsed.infix} is valid in {systemShortName(lesson.system)} and fails in {systemShortName(lesson.mustFailSystem)}!")
