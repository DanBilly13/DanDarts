# Phase 15-A Investigation: Voice Startup Reliability

## Quick Start

This investigation aims to determine why voice startup works reliably after clean builds but fails on repeated runs.

### 1. Read the Context
- **Phase 15-A Rules:** `../.windsurf/rules/phase-15-a-current-context-investigation-remote-matches-voice-startup-reliability.md`
- **Instrumentation Summary:** `phase-15a-instrumentation-summary.md`
- **Test Scenarios Guide:** `phase-15a-test-scenarios.md`

### 2. Run Test Scenarios
Follow the scenarios in `phase-15a-test-scenarios.md`:
- Scenario A: Clean Build Baseline
- Scenario B: Repeated Run (No Clean Build)
- Scenario C: Force-Quit Relaunch
- Scenario D: Multiple Match Attempts

### 3. Capture Logs
Save console output to:
- `phase-15a-logs-clean-build.txt`
- `phase-15a-logs-repeated-run.txt`
- `phase-15a-logs-force-quit.txt`
- `phase-15a-logs-multiple-attempts.txt`

### 4. Analyze Results
Use `phase-15a-analysis-template.md` to structure your findings.

### 5. Make Decision
Choose Route A, B, or C based on evidence and plan Phase 15-B.

---

## Investigation Hypothesis

**The Problem:**
Voice startup becomes unreliable across repeated runs, but works after clean build.

**Possible Causes:**
1. **Stale voice state** surviving between runs
2. **Stale remote-flow state** not being cleaned up
3. **Duplicate owners** for services/views/subscriptions
4. **Bootstrap protocol races** (only after ruling out above)

**The Clue:**
Clean build success suggests **state contamination** rather than pure protocol issues.

---

## Log Categories Reference

| Emoji | Category | Purpose |
|-------|----------|---------|
| 🔵 | `[Lifecycle]` | Object/view creation and destruction |
| 🟢 | `[Subscribe]` | Subscription attach/detach operations |
| 🔴 | `[Cleanup]` | Cleanup operations and state verification |
| ⚪️ | `[Flow]` | Remote flow enter/exit |
| 🟡 | `[Voice]` | Voice session state changes |
| 🟣 | `[Signal]` | Signalling messages sent/received |

---

## Files in This Directory

| File | Purpose |
|------|---------|
| `README.md` | This file - quick start guide |
| `phase-15a-instrumentation-summary.md` | Complete instrumentation documentation |
| `phase-15a-test-scenarios.md` | Step-by-step test scenarios |
| `phase-15a-analysis-template.md` | Template for analyzing results |
| `phase-15a-logs-*.txt` | Captured console logs (create during testing) |
| `phase-15a-analysis.md` | Completed analysis (create after testing) |
| `phase-15a-decision.md` | Route decision and Phase 15-B plan (create after analysis) |

---

## Expected Timeline

1. **Instrumentation:** ✅ COMPLETE
2. **Testing:** ~1-2 hours (run all scenarios)
3. **Log Analysis:** ~1-2 hours (review and categorize)
4. **Decision:** ~30 minutes (choose route, plan next phase)
5. **Phase 15-B:** TBD (depends on route chosen)

---

## Success Criteria

Investigation is successful when:
- ✅ We can explain why clean build improves reliability
- ✅ We know whether issue is stale state, duplicate ownership, or protocol
- ✅ We have evidence-based decision for next phase
- ✅ We stop guessing and start proving

---

## Contact

For questions about this investigation, refer to:
- Phase 15-A context document in `.windsurf/rules/`
- Instrumentation summary in this directory
- Test scenarios guide in this directory
