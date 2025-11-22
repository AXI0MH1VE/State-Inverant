# Alexis Diamond Empire Prototype

Deterministic, auditable prototype of the "Autonomous Invariant Intelligence" loop. It targets decidable domains (propositional logic) to guarantee zero-entropy outputs via a Z3 oracle.

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
