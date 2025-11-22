"""
RunExperiment.py

Driver script to execute the AlexisDiamondEmpire symbolic logic experiment
validating the deterministic collapse to a true theorem state.

Demonstrates steps from the Symbolic Logic Runbook, generating audit ledger output.
"""

from AlexisDiamondEmpire import AlexisDiamondEmpire

def main():
    empire = AlexisDiamondEmpire()

    print("Starting Autonomous Invariant Intelligence Experiment...")
    result = empire.sell(client_id="test_client_001")

    if result["status"] == "success":
        print("Prediction Successful!")
        print("Candidate Theorem:", result["prediction"])
        print("Coherence (Lambda):", result["coherence"])
        print("Potential Energy (V):", result["potential_energy"])
        print("Audit Ledger File:", result["audit_ledger_file"])
    else:
        print("Prediction Failed:", result.get("message", "Unknown error"))

if __name__ == "__main__":
    main()
