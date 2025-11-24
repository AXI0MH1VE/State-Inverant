# Alexis Diamond Empire Prototype

Deterministic, auditable prototype of the "Autonomous Invariant Intelligence" loop. It targets decidable domains (propositional logic) to guarantee zero-entropy outputs via a Z3 oracle.

---

## Constitutional Framework

![CDA Compliant](https://img.shields.io/badge/CDA-v1.0%20Compliant-brightgreen)
[![Constitution](https://img.shields.io/badge/Constitution-Read-blue)](https://github.com/AXI0MH1VE/CDA-Constitution)

This project operates under the **[Constitution of a Deterministic Assistant (CDA-v1.0)](https://github.com/AXI0MH1VE/CDA-Constitution)**, establishing transparent operational boundaries for AI systems.

**Core Principles:**
- 🔍 **Transparency**: Glass Box Mandate - All operations are auditable
- ⚙️ **Determinism**: Predictable Tool Mandate - No autonomous agency
- 🤝 **Subservience**: Tool-in-Hand Mandate - Human authority paramount

See [.github/CONSTITUTION.md](.github/CONSTITUTION.md) for full constitutional text and [.github/COMPLIANCE.md](.github/COMPLIANCE.md) for implementation details.

---

## Features
- Deterministic proposal loop (no sampling)
- Hamiltonian-style barrier on potential energy (V = 1 - coherence)
- Z3-backed coherence oracle for tautology checking
- Immutable JSONL audit ledger of every state transition

## Quickstart
```bash
pip install -r requirements.txt
python AlexisDiamondEmpire.py --symbols p q
```

Outputs the converged candidate and writes an audit log to `audit-ledger.jsonl`.

## How it works
1. Propose a candidate formula deterministically from a fixed list.
2. Evaluate coherence via the oracle (1.0 if tautology; 0.0 otherwise).
3. Compute potential energy `V = 1 - coherence`.
4. Hamiltonian filter accepts if `V <= epsilon`; otherwise transmute to the next candidate.
5. Every step is written to the append-only ledger for reproducibility.

## Extending
- Add more candidates in `AlexisDiamondEmpire._default_candidates`.
- Adjust `epsilon` or `max_steps` via CLI flags.
- Swap the oracle to another decidable domain by implementing `InvariantOracle.coherence`.

## Dependencies
- Python 3.11+
- z3-solver (see `requirements.txt`)