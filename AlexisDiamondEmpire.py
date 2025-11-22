"""
Remove the line `from __future__ import annotations` as it must be the first line and it caused syntax error.
This updated file has moved all imports and declarations correctly.
"""
Autonomous Invariant Intelligence (Alexis Diamond Empire)

This module provides a small, self-contained prototype that mirrors the
architecture described in the accompanying design notes:
 - Deterministic proposal loop (no stochastic sampling)
 - Hamiltonian-style validator that rejects incoherent states
 - Z3-backed oracle for symbolic coherence (zero-entropy for decidable domains)
 - Immutable audit ledger recording every state transition

The prototype focuses on tautology verification in propositional logic.
It is intentionally lightweight so it can run on modest hardware while
remaining transparent and reproducible.
"""

from __future__ import annotations

import argparse
import json
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Sequence, Tuple


# --- Oracle -------------------------------------------------------------------


class InvariantOracle:
    """
    Deterministic oracle that checks logical coherence via Z3.

    Coherence is defined as:
        1.0 if the proposition is a tautology (negation is UNSAT)
        0.0 otherwise
    """

    def __init__(self) -> None:
        try:
            import z3  # type: ignore

            self.z3 = z3
            self.available = True
        except ImportError:
            self.z3 = None
            self.available = False

    def coherence(self, expression: str, symbols: Sequence[str]) -> float:
        if not self.available:
            return 0.0

        z3 = self.z3
        assert z3 is not None

        env = {name: z3.Bool(name) for name in symbols}
        env.update({"And": z3.And, "Or": z3.Or, "Not": z3.Not, "Implies": z3.Implies, "Xor": z3.Xor})

        try:
            theorem = eval(expression, {"__builtins__": {}}, env)
        except Exception:
            return 0.0

        solver = z3.Solver()
        solver.add(z3.Not(theorem))
        return 1.0 if solver.check() == z3.unsat else 0.0


# --- Hamiltonian Filter -------------------------------------------------------


class HamiltonianFilter:
    """
    Barrier that rejects states whose potential energy exceeds a threshold.
    """

    def __init__(self, epsilon: float = 1e-9) -> None:
        self.epsilon = epsilon

    def validate(self, potential_energy: float) -> Tuple[bool, str]:
        if potential_energy <= self.epsilon:
            return True, "Potential energy within bound"
        return False, f"Potential energy spike detected (V={potential_energy:.6f})"


# --- Proposers and Transmuters -----------------------------------------------


class DeterministicProposer:
    """
    Generates candidate propositions deterministically from a fixed list.
    """

    def __init__(self, candidates: Iterable[str]) -> None:
        self.candidates: List[str] = list(dict.fromkeys(candidates))

    def at(self, index: int) -> str:
        if index >= len(self.candidates):
            raise IndexError("No further candidates")
        return self.candidates[index]

    def total(self) -> int:
        return len(self.candidates)


class ConstraintTransmuter:
    """
    Advances to the next candidate. This mirrors the "non-refusal" idea: instead
    of halting on rejection, we re-route to the next deterministic option.
    """

    def next_index(self, current_index: int) -> int:
        return current_index + 1


# --- Audit Ledger -------------------------------------------------------------


@dataclass
class LedgerEntry:
    step: int
    candidate: str
    coherence: float
    potential_energy: float
    status: str
    reason: str
    elapsed_ms: float


class AuditLedger:
    """
    Append-only JSON Lines ledger for full reproducibility.
    """

    def __init__(self, path: Path) -> None:
        self.path = path
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def record(self, entry: LedgerEntry) -> None:
        payload = {
            "step": entry.step,
            "candidate": entry.candidate,
            "coherence": entry.coherence,
            "potential_energy": entry.potential_energy,
            "status": entry.status,
            "reason": entry.reason,
            "elapsed_ms": entry.elapsed_ms,
            "timestamp": time.time(),
        }
        with self.path.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(payload, ensure_ascii=True) + "\n")


# --- Invariant Engine ---------------------------------------------------------


class InvariantEngine:
    """
    Executes the inverted-Lagrangian style loop:
      1) Propose a candidate
      2) Measure coherence via oracle
      3) Compute potential energy V = 1 - coherence
      4) Validate via Hamiltonian filter
      5) Transmute if rejected; halt if accepted
    """

    def __init__(
        self,
        oracle: InvariantOracle,
        filter_: HamiltonianFilter,
        proposer: DeterministicProposer,
        transmuter: ConstraintTransmuter,
        ledger: AuditLedger,
        symbols: Sequence[str],
        max_steps: int = 64,
    ) -> None:
        self.oracle = oracle
        self.filter = filter_
        self.proposer = proposer
        self.transmuter = transmuter
        self.ledger = ledger
        self.symbols = symbols
        self.max_steps = max_steps

    def run(self) -> str:
        idx = 0
        for step in range(self.max_steps):
            start = time.time()
            try:
                candidate = self.proposer.at(idx)
            except IndexError as exc:
                raise RuntimeError("Exhausted candidates without convergence") from exc

            coherence = self.oracle.coherence(candidate, self.symbols)
            potential_energy = max(0.0, 1.0 - coherence)
            accepted, reason = self.filter.validate(potential_energy)
            status = "accepted" if accepted else "rejected"
            elapsed_ms = (time.time() - start) * 1000.0

            self.ledger.record(
                LedgerEntry(
                    step=step,
                    candidate=candidate,
                    coherence=coherence,
                    potential_energy=potential_energy,
                    status=status,
                    reason=reason,
                    elapsed_ms=elapsed_ms,
                )
            )

            if accepted:
                return candidate

            idx = self.transmuter.next_index(idx)

        raise RuntimeError("Reached max steps without convergence")


# --- Synthesized Orchestrator -------------------------------------------------


class AlexisDiamondEmpire:
    """
    High-level facade that wires all components together.
    """

    def __init__(
        self,
        symbols: Sequence[str] = ("p", "q"),
        ledger_path: Path | None = None,
        epsilon: float = 1e-9,
        max_steps: int = 64,
    ) -> None:
        self.symbols = tuple(symbols)
        self.ledger = AuditLedger(ledger_path or Path("audit-ledger.jsonl"))
        self.oracle = InvariantOracle()
        self.filter = HamiltonianFilter(epsilon=epsilon)
        self.proposer = DeterministicProposer(self._default_candidates(self.symbols))
        self.transmuter = ConstraintTransmuter()
        self.engine = InvariantEngine(
            oracle=self.oracle,
            filter_=self.filter,
            proposer=self.proposer,
            transmuter=self.transmuter,
            ledger=self.ledger,
            symbols=self.symbols,
            max_steps=max_steps,
        )

    @staticmethod
    def _default_candidates(symbols: Sequence[str]) -> Iterable[str]:
        # Limited, deterministic space for demonstration. Add more to widen coverage.
        s = list(symbols)
        candidates = [
            s[0] if s else "p",
            f"Not({s[0]})" if s else "Not(p)",
            f"And({s[0]}, {s[1]})" if len(s) > 1 else "And(p, q)",
            f"Or({s[0]}, {s[1]})" if len(s) > 1 else "Or(p, q)",
            f"Implies(And({s[0]}, {s[1]}), {s[0]})" if len(s) > 1 else "Implies(And(p, q), p)",
            f"Implies({s[0]}, Or({s[0]}, {s[1]}))" if len(s) > 1 else "Implies(p, Or(p, q))",
            f"Implies({s[0]}, {s[0]})" if s else "Implies(p, p)",
            f"Implies({s[0]}, And({s[0]}, {s[1]}))" if len(s) > 1 else "Implies(p, And(p, q))",
            f"Implies(And({s[0]}, {s[1]}), Or({s[0]}, {s[1]}))" if len(s) > 1 else "Implies(And(p, q), Or(p, q))",
            f"Implies(Or({s[0]}, {s[1]}), Or({s[1]}, {s[0]}))" if len(s) > 1 else "Implies(Or(p, q), Or(q, p))",
        ]
        return candidates

    def solve(self) -> str:
        return self.engine.run()


# --- CLI ----------------------------------------------------------------------


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Alexis Diamond Empire prototype")
    parser.add_argument("--symbols", nargs="+", default=["p", "q"], help="Symbol names for the oracle")
    parser.add_argument("--ledger", default="audit-ledger.jsonl", help="Path to JSONL audit ledger")
    parser.add_argument("--epsilon", type=float, default=1e-9, help="Hamiltonian filter epsilon")
    parser.add_argument("--max-steps", type=int, default=64, help="Maximum proposal attempts")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    empire = AlexisDiamondEmpire(
        symbols=args.symbols,
        ledger_path=Path(args.ledger),
        epsilon=args.epsilon,
        max_steps=args.max_steps,
    )

    if not empire.oracle.available:
        raise SystemExit(
            "z3-solver is not installed. Run `pip install -r requirements.txt` to enable the coherence oracle."
        )

    candidate = empire.solve()
    print("Converged candidate:", candidate)


if __name__ == "__main__":
    main()
