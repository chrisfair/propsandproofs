## Shared domain types, cube symbols, modal systems, and UI geometry for WFF 'N PROOF.

type
  Symbol* = enum
    symP = "p"
    symQ = "q"
    symR = "r"
    symS = "s"
    symN = "N" # Negation (¬)
    symC = "C" # Conditional / Implication (→)
    symK = "K" # Conjunction (∧)
    symA = "A" # Disjunction (∨)
    symE = "E" # Equivalence / Biconditional (↔)
    symL = "L" # Modal Necessity (□)
    symM = "M" # Modal Possibility (◇)

  SymbolCategory* = enum
    scAtom
    scUnaryProp
    scBinaryProp
    scModal

  ModalSystem* = enum
    msProp = "Classical Propositional"
    msK = "System K (Normal)"
    msT = "System T (Reflexive)"
    msS4 = "System S4 (Reflexive + Transitive)"
    msS5 = "System S5 (Equivalence)"

  GameMode* = enum
    gmAcademy = "Academy (12 Lessons)"
    gmWffGame = "WFF Game (Dice Sprint)"
    gmProofMat = "3-Zone Proof Mat"
    gmProofLab = "Proof & Kripke Lab"

  MatZone* = enum
    mzResources = "Resources"
    mzGoal = "Goal"
    mzRequired = "Required"
    mzPermitted = "Permitted"
    mzForbidden = "Forbidden"

  ModalOverlay* = enum
    moNone
    moRules
    moModalRef

  Rgba* = object
    r*, g*, b*, a*: float

  UiRect* = object
    x*, y*, w*, h*: float

  LogicCube* = object
    id*: int
    sym*: Symbol
    zone*: MatZone

proc rgba*(r, g, b: float; a: float = 1.0): Rgba {.inline.} =
  Rgba(r: r, g: g, b: b, a: a)

proc uiRect*(x, y, w, h: float): UiRect {.inline.} =
  UiRect(x: x, y: y, w: w, h: h)

proc contains*(rc: UiRect; px, py: float): bool {.inline.} =
  px >= rc.x and px <= rc.x + rc.w and py >= rc.y and py <= rc.y + rc.h

proc arity*(s: Symbol): int {.inline.} =
  case s
  of symP, symQ, symR, symS: 0
  of symN, symL, symM: 1
  of symC, symK, symA, symE: 2

proc category*(s: Symbol): SymbolCategory {.inline.} =
  case s
  of symP, symQ, symR, symS: scAtom
  of symN: scUnaryProp
  of symC, symK, symA, symE: scBinaryProp
  of symL, symM: scModal

proc isModalSymbol*(s: Symbol): bool {.inline.} =
  s in {symL, symM}

proc polishChar*(s: Symbol): char {.inline.} =
  case s
  of symP: 'p'
  of symQ: 'q'
  of symR: 'r'
  of symS: 's'
  of symN: 'N'
  of symC: 'C'
  of symK: 'K'
  of symA: 'A'
  of symE: 'E'
  of symL: 'L'
  of symM: 'M'

proc modernGlyph*(s: Symbol): string {.inline.} =
  case s
  of symP: "p"
  of symQ: "q"
  of symR: "r"
  of symS: "s"
  of symN: "¬"
  of symC: "→"
  of symK: "∧"
  of symA: "∨"
  of symE: "↔"
  of symL: "□"
  of symM: "◇"

proc symbolName*(s: Symbol): string {.inline.} =
  case s
  of symP: "Atom p"
  of symQ: "Atom q"
  of symR: "Atom r"
  of symS: "Atom s"
  of symN: "Not (¬)"
  of symC: "If-Then (→)"
  of symK: "And (∧)"
  of symA: "Or (∨)"
  of symE: "Iff (↔)"
  of symL: "Necessarily (□)"
  of symM: "Possibly (◇)"

proc cubeColor*(s: Symbol): Rgba {.inline.} =
  case s
  of symP, symQ, symR, symS: rgba(0.18, 0.48, 0.30, 1.0)  # Emerald green (classic sentential vars)
  of symN: rgba(0.18, 0.19, 0.23, 1.0)                    # Charcoal (negation)
  of symC: rgba(0.68, 0.19, 0.17, 1.0)                    # Crimson (implication)
  of symK: rgba(0.16, 0.45, 0.46, 1.0)                    # Deep teal (conjunction)
  of symA: rgba(0.72, 0.48, 0.12, 1.0)                    # Ochre gold (disjunction)
  of symE: rgba(0.20, 0.38, 0.58, 1.0)                    # Steel blue (biconditional)
  of symL: rgba(0.18, 0.31, 0.68, 1.0)                    # Sapphire (necessity □)
  of symM: rgba(0.45, 0.22, 0.62, 1.0)                    # Amethyst (possibility ◇)

proc charToSymbol*(ch: char; sym: var Symbol): bool =
  case ch
  of 'p': sym = symP; true
  of 'q': sym = symQ; true
  of 'r': sym = symR; true
  of 's': sym = symS; true
  of 'N', '~': sym = symN; true
  of 'C': sym = symC; true
  of 'K': sym = symK; true
  of 'A': sym = symA; true
  of 'E': sym = symE; true
  of 'L': sym = symL; true
  of 'M': sym = symM; true
  else: false

proc systemShortName*(ms: ModalSystem): string {.inline.} =
  case ms
  of msProp: "Prop"
  of msK: "K"
  of msT: "T"
  of msS4: "S4"
  of msS5: "S5"

proc systemAxiomSummary*(ms: ModalSystem): string {.inline.} =
  case ms
  of msProp: "Propositional logic (no modal operators □/◇)."
  of msK: "All frames. Axiom K: □(p→q)→(□p→□q) + Necessitation."
  of msT: "Reflexive frames (wRw). Adds Axiom T: □p → p."
  of msS4: "Reflexive + Transitive frames. Adds Axiom 4: □p → □□p."
  of msS5: "Equivalence frames (Refl+Sym+Trans). Adds Axiom 5: ◇p → □◇p."
