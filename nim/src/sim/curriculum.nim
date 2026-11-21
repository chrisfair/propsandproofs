## 12-lesson interactive Props & Proofs & Modal Logic Academy curriculum.

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

const Lessons*: array[12, LessonDef] = [
  LessonDef(
    id: 1,
    track: "Propositional Logic",
    title: "1. What Is a WFF? (Atoms & Negation)",
    system: msProp,
    explanation: "In Props & Proofs, formulas are written in Polish (prefix) notation without parentheses. Sentential variables p, q, r, s are WFFs on their own. Prefixing N ('not') before any WFF makes a new WFF: Np means ¬p, NNp means ¬¬p.",
    task: "Build the double negation of p (¬¬p) using the cubes below: NNp.",
    hint: "Click N, then N, then p — each unary operator expects 1 WFF immediately after it.",
    palette: @[symN, symN, symP, symQ],
    checkKind: lckExactPolish,
    targetPolish: "NNp",
    targetLen: 3,
    examplePolish: "NNp",
  ),
  LessonDef(
    id: 2,
    track: "Propositional Logic",
    title: "2. Binary Connectives Without Parentheses",
    system: msProp,
    explanation: "Binary operators C (→ if-then), K (∧ and), A (∨ or), and E (↔ iff) always come BEFORE their two operands. So Cpq is (p → q), and CKpqr is ((p ∧ q) → r) — completely unambiguous without parentheses!",
    task: "Build ((p ∧ q) → r) in Polish notation: CKpqr.",
    hint: "Start with the outer connective C (→), then its left operand Kpq (p ∧ q), then its right operand r.",
    palette: @[symC, symK, symA, symP, symQ, symR],
    checkKind: lckExactPolish,
    targetPolish: "CKpqr",
    targetLen: 5,
    examplePolish: "CKpqr",
  ),
  LessonDef(
    id: 3,
    track: "Propositional Logic",
    title: "3. The WFF Game: Longest Valid Formula",
    system: msProp,
    explanation: "Dice Sprint is pure WFF construction: from rolled cubes, assemble the longest Well-Formed Formula. Rule of thumb: every binary cube needs +1 extra atom (so 3 binaries need 4 atoms).",
    task: "Build any valid WFF of at least 7 cubes using the available dice.",
    hint: "Try chaining 3 binary operators and 4 atoms, e.g. CKCpqKrs (or CApqKrs).",
    palette: @[symC, symK, symA, symN, symP, symQ, symR, symS],
    checkKind: lckAnyWffMinLen,
    targetLen: 7,
    examplePolish: "CApqKrs",
  ),
  LessonDef(
    id: 4,
    track: "Propositional Logic",
    title: "4. Tautologies & Truth Tables",
    system: msProp,
    explanation: "A WFF that evaluates to True under every assignment of p, q, r, s is a Tautology (a logical theorem). The simplest conditional tautology is the Law of Identity: Cpp (p → p).",
    task: "Build any Propositional Tautology of at least 4 cubes (e.g., ApNp or CpCqp).",
    hint: "Excluded Middle is ApNp (p ∨ ¬p). Weakening is CpCqp (p → (q → p)).",
    palette: @[symC, symA, symK, symN, symP, symQ, symP],
    checkKind: lckPropTautology,
    targetLen: 4,
    examplePolish: "ApNp",
  ),
  LessonDef(
    id: 5,
    track: "Propositional Logic",
    title: "5. Contraposition & Conditional Chains",
    system: msProp,
    explanation: "Implication Cpq is logically equivalent to its contrapositive CNqNp (¬q → ¬p). In 3-Zone Proof Mat matches, recognizing equivalent forms lets you reach Goals even when key cubes are Forbidden.",
    task: "Build the Contraposition tautology ((p → q) → (¬q → ¬p)): CCpqCNqNp.",
    hint: "Outer C, left side Cpq, right side CNqNp.",
    palette: @[symC, symC, symC, symN, symN, symP, symP, symQ, symQ],
    checkKind: lckExactPolish,
    targetPolish: "CCpqCNqNp",
    targetLen: 9,
    examplePolish: "CCpqCNqNp",
  ),
  LessonDef(
    id: 6,
    track: "Propositional Logic",
    title: "6. Preparing for the 3-Zone Proof Mat",
    system: msProp,
    explanation: "In the full 3-Zone Proof Mat game, players place cubes into Required, Permitted, and Forbidden zones to constrain the Goal. Mastering De Morgan & Implication identities (like Cpq ↔ ANpq) is key!",
    task: "Build the equivalence (p → q) ↔ (¬p ∨ q) in Polish notation: ECpqANpq.",
    hint: "Start with E (↔), then Cpq (p → q), then ANpq (¬p ∨ q).",
    palette: @[symE, symC, symA, symN, symP, symP, symQ, symQ],
    checkKind: lckExactPolish,
    targetPolish: "ECpqANpq",
    targetLen: 8,
    examplePolish: "ECpqANpq",
  ),
  LessonDef(
    id: 7,
    track: "Modal Logic (K / T / S4 / S5)",
    title: "7. Modal Operators: Necessity (□) & Possibility (◇)",
    system: msK,
    explanation: "Modal logic extends propositional logic with two unary operators (Łukasiewicz notation): L = □ ('necessarily', true in ALL accessible possible worlds) and M = ◇ ('possibly', true in AT LEAST ONE accessible world).",
    task: "Build 'if necessarily p, then possibly p' (□p → ◇p): CLpMp.",
    hint: "C (→) takes two operands: Lp (□p) and Mp (◇p) → CLpMp.",
    palette: @[symC, symL, symM, symN, symP, symP, symQ],
    checkKind: lckExactPolish,
    targetPolish: "CLpMp",
    targetLen: 5,
    examplePolish: "CLpMp",
  ),
  LessonDef(
    id: 8,
    track: "Modal Logic (K / T / S4 / S5)",
    title: "8. Modal Duality (¬□p ↔ ◇¬p)",
    system: msK,
    explanation: "Necessity and Possibility are duals, just like ∀ and ∃: saying 'p is NOT necessary' (¬□p) means 'it is possible that NOT p' (◇¬p). This holds in EVERY normal modal system (even minimal System K)!",
    task: "Build the Modal Duality theorem ¬□p ↔ ◇¬p: ENLpMNp.",
    hint: "Start with E (↔), then NLp (¬□p), then MNp (◇¬p). Watch it pass Kripke validation in K!",
    palette: @[symE, symN, symN, symL, symM, symP, symP],
    checkKind: lckExactPolish,
    targetPolish: "ENLpMNp",
    targetLen: 7,
    examplePolish: "ENLpMNp",
  ),
  LessonDef(
    id: 9,
    track: "Modal Logic (K / T / S4 / S5)",
    title: "9. System K & Axiom K (Distribution)",
    system: msK,
    explanation: "System K imposes NO restrictions on the Kripke accessibility relation R. Its defining law is Axiom K: □(p → q) → (□p → □q). If (p → q) holds in all accessible worlds and p holds in all accessible worlds, q must too!",
    task: "Build Axiom K in Polish notation: CLCpqCLpLq.",
    hint: "Outer C, left operand LCpq (□(p→q)), right operand CLpLq (□p→□q).",
    palette: @[symC, symC, symC, symL, symL, symL, symP, symP, symQ, symQ],
    checkKind: lckExactPolish,
    targetPolish: "CLCpqCLpLq",
    targetLen: 10,
    examplePolish: "CLCpqCLpLq",
  ),
  LessonDef(
    id: 10,
    track: "Modal Logic (K / T / S4 / S5)",
    title: "10. System T (Reflexivity): □p → p",
    system: msT,
    explanation: "Why does □p → p FAIL in System K? Because in K, a world w0 might have NO arrow to itself (dead-end world)! Requiring Reflexivity (every world sees itself: wRw) gives System T, validating □p → p (CLpp).",
    task: "Build Axiom T (□p → p) and inspect why it holds in T but has a countermodel in K.",
    hint: "Build CLpp (or its dual CpMp: p → ◇p).",
    palette: @[symC, symL, symM, symP, symP, symQ],
    checkKind: lckModalValidIn,
    targetLen: 4,
    requireModal: true,
    mustFailSystem: msK,
    hasFailCheck: true,
    examplePolish: "CLpp",
  ),
  LessonDef(
    id: 11,
    track: "Modal Logic (K / T / S4 / S5)",
    title: "11. System S4 (Transitivity): □p → □□p",
    system: msS4,
    explanation: "Add Transitivity (if wRv and vRu then wRu) to System T and you get S4 — the logic of mathematical provability and epistemic introspection ('if I know p, I know that I know p'). It validates Axiom 4: □p → □□p.",
    task: "Build a modal formula valid in S4 that FAILS in System T (e.g., Axiom 4: CLpLLp).",
    hint: "Click C, L, p, L, L, p to form CLpLLp (□p → □□p).",
    palette: @[symC, symL, symL, symL, symM, symP, symP],
    checkKind: lckModalValidIn,
    targetLen: 5,
    requireModal: true,
    mustFailSystem: msT,
    hasFailCheck: true,
    examplePolish: "CLpLLp",
  ),
  LessonDef(
    id: 12,
    track: "Modal Logic (K / T / S4 / S5)",
    title: "12. System S5 (Equivalence): ◇p → □◇p",
    system: msS5,
    explanation: "Add Symmetry (if wRv then vRw) to S4 and R becomes an equivalence relation: every world in a cluster sees every other world. This is System S5 — metaphysical necessity — validating Axiom 5: ◇p → □◇p (CMpLMp).",
    task: "Build a modal formula valid in S5 that FAILS in S4 (e.g., Axiom 5: CMpLMp or B: CpLMp).",
    hint: "Click C, M, p, L, M, p to form CMpLMp (◇p → □◇p).",
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
    return (false, parsed.errorMsg)

  case lesson.checkKind
  of lckExactPolish:
    if parsed.polish == lesson.targetPolish:
      return (true, fmt"Correct! {parsed.polish} = {parsed.infix}.")
    return (false, fmt"Valid WFF ({parsed.infix}), but this lesson asks for {lesson.targetPolish}.")
  of lckAnyWffMinLen:
    if syms.len >= lesson.targetLen:
      return (true, fmt"Great WFF of length {syms.len}: {parsed.infix}!")
    return (false, fmt"Valid WFF ({parsed.polish}), need at least {lesson.targetLen} cubes (currently {syms.len}).")
  of lckPropTautology:
    if parsed.hasModal:
      return (false, "Use propositional cubes only for this lesson.")
    if syms.len < lesson.targetLen:
      return (false, fmt"Need at least {lesson.targetLen} cubes (currently {syms.len}).")
    let tt = evalTruthTable(parsed.root)
    if tt.isTautology:
      return (true, fmt"Verified Tautology! {parsed.infix} is True in all {tt.rows.len} rows.")
    return (false, fmt"{parsed.infix} is not a tautology — check the truth table!")
  of lckModalValidIn:
    if lesson.requireModal and not parsed.hasModal:
      return (false, "Include at least one modal operator (L = □ or M = ◇).")
    if syms.len < lesson.targetLen:
      return (false, fmt"Need at least {lesson.targetLen} cubes.")
    let checkTarget = checkModalValidity(parsed.root, lesson.system)
    if not checkTarget.valid:
      return (false, fmt"Not valid in {systemShortName(lesson.system)}: {checkTarget.summary}")
    if lesson.hasFailCheck:
      let checkWeaker = checkModalValidity(parsed.root, lesson.mustFailSystem)
      if checkWeaker.valid:
        return (false, fmt"Valid in {systemShortName(lesson.system)}, but also valid in {systemShortName(lesson.mustFailSystem)}! Try a formula specific to {systemShortName(lesson.system)} like {lesson.examplePolish}.")
    return (true, fmt"Verified! {parsed.infix} is valid in {systemShortName(lesson.system)} and fails in {systemShortName(lesson.mustFailSystem)}!")
