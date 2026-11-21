# Props & Proofs — Modern & Modal Logic (Nim + Godot 4)

An open-source Godot 4 + Nim (`gdext`) tabletop game and interactive tutor for **propositional logic**, **Łukasiewicz (Polish) prefix notation**, **Fitch natural deduction**, and **Modal Logic (Systems K, T, S4, and S5)** with live finite Kripke possible-worlds countermodels.

## Modes Included

1. **Academy (12 Lessons)** — Six lessons covering Polish notation, tautologies, and 3-zone mat strategy, followed by six lessons on Modal Logic (`L` = `□` Necessity, `M` = `◇` Possibility, Modal Duality, System K, System T, System S4, and System S5).
2. **WFF Game (Dice Sprint)** — Roll 12–14 logic cubes and assemble the longest valid Well-Formed Formula against the Logician AI.
3. **3-Zone Proof Mat** — Alternate placing Resource cubes into **Required**, **Permitted**, and **Forbidden** zones against the Logician AI, and call **Challenge: NOW!** or **Challenge: IMPOSSIBLE!**.
4. **Proof & Kripke Lab** — Test any Polish formula across `Prop`, `K`, `T`, `S4`, and `S5`, inspect live Kripke countermodel graphs, and build verified Fitch-style natural deduction and modal proofs.

## Quick Start (`mise` + `make`)

Toolchain is pinned via `mise.toml` (`nim 2.2.2`) and builds a project-local Godot 4 GDExtension in `.nimble`:

```bash
# Install project-local gdext dependency
mise run deps

# Run unit tests + gcov coverage gate (>= 85%)
mise run coverage

# Build the Nim GDExtension and launch Godot 4
mise run run

# Or run the headless Godot 4 integration smoke check
mise run smoke
```

## License & Attribution

Licensed under the **GNU General Public License v3.0** (`GPL-3.0-or-later`). See [LICENSE](LICENSE).

Props & Proofs is an independent open-source project inspired by classic educational logic dice games (including Layman E. Allen's 1962 game *WFF 'N PROOF*). It is not affiliated with, endorsed by, or sponsored by the Accelerated Learning Foundation.
