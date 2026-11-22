## Headless Nim unit test suite for WFF 'N PROOF (Polish logic, Modal Kripke semantics,
## Fitch proofs, 12-lesson Academy, 3-Zone Mat AI, and UI Presenter).

import std/unittest
import sim/[types, logic, proof, curriculum, game, presenter]

suite "Types & Symbol Metadata":
  test "arity, category, glyph, and char parsing":
    for s in Symbol:
      check s.modernGlyph().len > 0
      check s.symbolName().len > 0
      let col = s.cubeColor()
      check col.a == 1.0
      var parsed: Symbol
      check charToSymbol(s.polishChar(), parsed)
      check parsed == s
    check symP.arity() == 0
    check symN.arity() == 1
    check symL.arity() == 1
    check symC.arity() == 2
    check symL.isModalSymbol()
    check symM.isModalSymbol()
    check not symC.isModalSymbol()
    check symP.category() == scAtom
    check symN.category() == scUnaryProp
    check symK.category() == scBinaryProp
    check symM.category() == scModal
    var dummy: Symbol
    check not charToSymbol('Z', dummy)
    for ms in ModalSystem:
      check systemShortName(ms).len > 0
      check systemAxiomSummary(ms).len > 0

suite "Polish WFF Parser & Propositional Truth Tables":
  test "parses valid propositional and modal Polish formulas":
    let r1 = parseWffString("CKpqr")
    check r1.isWff
    check r1.polish == "CKpqr"
    check r1.infix == "(p ∧ q) → r"
    check not r1.hasModal
    check r1.depth == 3

    let r2 = parseWffString("CLCpqCLpLq")
    check r2.isWff
    check r2.hasModal
    check r2.infix == "□(p → q) → (□p → □q)"
    check describeFamousAxiom(r2.polish).len > 0

  test "rejects incomplete, trailing, and unknown formulas":
    check not parseWffString("").isWff
    check not parseWffString("Cp").isWff
    check not parseWffString("Cpq r").isWff
    check not parseWffString("N").isWff
    check not parseWffString("Cxq").isWff

  test "evaluates tautologies, contradictions, and contingencies":
    let taut = parseWffString("CCpqCNqNp")
    let tt1 = evalTruthTable(taut.root)
    check tt1.isTautology
    check not tt1.isContradiction
    check not tt1.isContingent

    let contra = parseWffString("KpNp")
    let tt2 = evalTruthTable(contra.root)
    check tt2.isContradiction
    check not tt2.isTautology

    let cont = parseWffString("Cpq")
    let tt3 = evalTruthTable(cont.root)
    check tt3.isContingent

suite "Modal Logic Kripke Semantics (K, T, S4, S5)":
  test "Axiom K and Modal Duality hold in K, T, S4, S5":
    let axK = parseWffString("CLCpqCLpLq").root
    let dual = parseWffString("ENLpMNp").root
    for ms in [msK, msT, msS4, msS5]:
      check checkModalValidity(axK, ms).valid
      check checkModalValidity(dual, ms).valid

  test "Axiom T (□p → p) fails in K with countermodel, holds in T, S4, S5":
    let axT = parseWffString("CLpp").root
    let cK = checkModalValidity(axT, msK)
    check not cK.valid
    check cK.hasCountermodel
    check checkModalValidity(axT, msT).valid
    check checkModalValidity(axT, msS4).valid
    check checkModalValidity(axT, msS5).valid

  test "Axiom 4 (□p → □□p) fails in T, holds in S4 and S5":
    let ax4 = parseWffString("CLpLLp").root
    check not checkModalValidity(ax4, msK).valid
    check not checkModalValidity(ax4, msT).valid
    check checkModalValidity(ax4, msS4).valid
    check checkModalValidity(ax4, msS5).valid

  test "Axiom 5 (◇p → □◇p) fails in S4, holds in S5":
    let ax5 = parseWffString("CMpLMp").root
    check not checkModalValidity(ax5, msT).valid
    check not checkModalValidity(ax5, msS4).valid
    check checkModalValidity(ax5, msS5).valid

suite "Fitch Natural Deduction & Modal Proof Verifier":
  test "verifies all 6 built-in propositional and modal sample proofs":
    for puz in ProofPuzzles:
      let res = verifyProof(puz.sampleProof, puz.goal, puz.system)
      check res.allValid
      check res.goalReached

  test "verifies Ki, Ai, Ao, Ni, No, Ei, Eo, R, and Nec":
    let steps = @[
      ProofStep(depth: 0, formula: "p", rule: prPremise),
      ProofStep(depth: 0, formula: "q", rule: prPremise),
      ProofStep(depth: 0, formula: "Kpq", rule: prKi, refs: @[1, 2]),
      ProofStep(depth: 0, formula: "Apq", rule: prAi, refs: @[1]),
      ProofStep(depth: 0, formula: "p", rule: prR, refs: @[1]),
      ProofStep(depth: 0, formula: "NNp", rule: prPremise),
      ProofStep(depth: 0, formula: "p", rule: prNo, refs: @[6]),
      ProofStep(depth: 0, formula: "Cpq", rule: prPremise),
      ProofStep(depth: 0, formula: "Cqp", rule: prPremise),
      ProofStep(depth: 0, formula: "Epq", rule: prEi, refs: @[8, 9]),
      ProofStep(depth: 0, formula: "Cpq", rule: prEo, refs: @[10]),
      ProofStep(depth: 0, formula: "Cpr", rule: prPremise),
      ProofStep(depth: 0, formula: "Cqr", rule: prPremise),
      ProofStep(depth: 0, formula: "r", rule: prAo, refs: @[4, 12, 13]),
    ]
    let res = verifyProof(steps, "r", msProp)
    check res.allValid
    check res.goalReached

    # Test Nec on pure theorem Cpp in System K
    let necSteps = @[
      ProofStep(depth: 1, formula: "p", rule: prAssump),
      ProofStep(depth: 0, formula: "Cpp", rule: prCi, refs: @[1, 1]),
      ProofStep(depth: 0, formula: "LCpp", rule: prNec, refs: @[2]),
    ]
    let necRes = verifyProof(necSteps, "LCpp", msK)
    check necRes.allValid
    check necRes.goalReached

    # Test Ni (Reductio)
    let niSteps = @[
      ProofStep(depth: 0, formula: "Nq", rule: prPremise),
      ProofStep(depth: 0, formula: "Cpq", rule: prPremise),
      ProofStep(depth: 1, formula: "p", rule: prAssump),
      ProofStep(depth: 1, formula: "q", rule: prCo, refs: @[2, 3]),
      ProofStep(depth: 1, formula: "Nq", rule: prR, refs: @[1]),
      ProofStep(depth: 0, formula: "Np", rule: prNi, refs: @[3, 5, 4]),
    ]
    let niRes = verifyProof(niSteps, "Np", msProp)
    check niRes.allValid
    check niRes.goalReached

  test "rejects invalid modal rules in weaker systems":
    let badT = @[
      ProofStep(depth: 0, formula: "Lp", rule: prPremise),
      ProofStep(depth: 0, formula: "p", rule: prTElim, refs: @[1]),
    ]
    check not verifyProof(badT, "p", msK).allValid
    let bad4 = @[
      ProofStep(depth: 0, formula: "Lp", rule: prPremise),
      ProofStep(depth: 0, formula: "LLp", rule: prFourIntro, refs: @[1]),
    ]
    check not verifyProof(bad4, "LLp", msT).allValid
    let bad5 = @[
      ProofStep(depth: 0, formula: "Mp", rule: prPremise),
      ProofStep(depth: 0, formula: "LMp", rule: prFiveIntro, refs: @[1]),
    ]
    check not verifyProof(bad5, "LMp", msS4).allValid

suite "16-Lesson Academy Curriculum & Didactic Helpers":
  test "every lesson has didactic text and its example solution passes evaluateLesson":
    check Lessons.len == 16
    for idx, lesson in Lessons:
      check lesson.explanation.len > 0
      check lesson.walkthrough.len > 0
      check lesson.whyItMatters.len > 0
      var syms: seq[Symbol] = @[]
      for ch in lesson.examplePolish:
        var s: Symbol
        check charToSymbol(ch, s)
        syms.add(s)
      let (ok, _) = evaluateLesson(idx, syms)
      check ok

  test "polishSlotTrace tracks empty, partial, complete, and trailing formulas":
    let t0 = polishSlotTrace(@[])
    check t0.openSlots == 1
    check t0.completeAt == -1

    let t1 = polishSlotTrace(@[symC, symK, symP])
    check t1.openSlots == 2
    check t1.completeAt == -1

    let t2 = polishSlotTrace(@[symC, symK, symP, symQ, symR])
    check t2.openSlots == 0
    check t2.completeAt == 5

    let t3 = polishSlotTrace(@[symN, symP, symQ])
    check t3.completeAt == 2

  test "evaluateLesson reports failing truth-table row on non-tautology":
    let (ok, msg) = evaluateLesson(5, @[symC, symP, symN, symQ])
    check not ok
    check msg.len > 0

  test "ruleHelp covers every ProofRule":
    for r in ProofRule:
      check ruleHelp(r).len > 0

suite "WFF Game, 3-Zone Mat, AI, and UI Presenter":
  test "WFF solver and Dice Sprint round":
    let g = newWffGame(123)
    g.modalSystem = msS4
    g.startSprintRound()
    let id1 = g.sprintPool[0].id
    g.sprintPickCube(id1)
    check g.sprintWorkspace.len == 1
    g.sprintReturnCube(id1)
    check g.sprintWorkspace.len == 0
    g.sprintPickCube(g.sprintPool[0].id)
    g.sprintClear()
    check g.sprintWorkspace.len == 0
    g.sprintSubmit()
    check g.sprintSubmitted
    check g.sprintAiBest.len > 0

  test "3-Zone Mat turns, AI step, and challenges":
    let g = newWffGame(99)
    g.mode = gmProofMat
    g.modalSystem = msT
    g.startMatRound()
    check g.matCubes.len == 14
    let firstId = g.matCubes[0].id
    check g.matMoveCube(firstId, mzRequired, byHuman = true)
    check g.matPhase == mpAiTurn
    g.stepMatAi(0.6)
    check g.matPhase in {mpYourTurn, mpRoundOver}
    if g.matPhase == mpYourTurn:
      g.matChallenge("now", byHuman = true)
    check g.matPhase == mpRoundOver

  test "Presenter layout, clicking, keyboard, and overlays across all 4 modes":
    let p = newWffPresenter(1680.0, 960.0, 77)
    p.resize(1440.0, 900.0)
    p.onMouseMove(100.0, 100.0)
    check p.onKeyChar('N')
    check p.onKeyChar('p')
    check p.game.academySolved
    check p.onKeyChar('\b')

    p.handleButton("acad:hint")
    p.handleButton("acad:step")
    p.handleButton("acad:example")
    p.handleButton("acad:next")
    p.handleButton("acad:clear")
    p.handleButton("acad:step")
    discard p.game.matZoneStats()

    p.handleButton("modal:rules")
    check p.overlay == moRules
    check p.onKeyChar('\x1b')
    check p.overlay == moNone

    p.handleButton("modal:modalref")
    check p.overlay == moModalRef
    p.handleButton("modal:close")

    # Switch to WFF Game
    p.handleButton("mode:1")
    check p.game.mode == gmWffGame
    if p.cubeHits.len > 0:
      let rc = p.cubeHits[0].rc
      check p.onMouseClick(rc.x + 10.0, rc.y + 10.0)
    p.handleButton("sprint:submit")
    p.handleButton("sprint:new")

    # Switch to 3-Zone Mat
    p.handleButton("mode:2")
    check p.game.mode == gmProofMat
    if p.cubeHits.len > 0:
      let rc = p.cubeHits[0].rc
      check p.onMouseClick(rc.x + 10.0, rc.y + 10.0)
    p.handleButton("mat:place:perm")
    p.step(0.6)
    p.handleButton("mat:chal:imp")
    p.handleButton("mat:new")

    # Switch to Proof & Kripke Lab
    p.handleButton("mode:3")
    check p.game.mode == gmProofLab
    p.handleButton("sys:3")
    p.handleButton("lab:puz:4")
    p.handleButton("lab:depth")
    p.handleButton("lab:refA")
    p.handleButton("lab:refB")
    p.handleButton("lab:rule:16")
    p.handleButton("lab:addstep")
    p.handleButton("lab:undo")
    p.handleButton("lab:sample")
    p.handleButton("lab:back")
    p.handleButton("lab:clear")
