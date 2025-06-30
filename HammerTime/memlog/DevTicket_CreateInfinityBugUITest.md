# Dev Ticket: Create Reliable UI Test for InfinityBug Reproduction

## Goal
Develop an automated UI test that reliably reproduces the InfinityBug, based on analysis of successful and unsuccessful manual reproduction attempts.

## Background
Analysis of log files from manual attempts shows that the InfinityBug is triggered by:
- A specific, methodical input pattern (navigation using DPAD/remote)
- Sustained directional inputs (e.g., repeated Right and Down arrows)
- Clear pauses between input events
- Severe runloop stalls (e.g., `RunLoop stall 5179 ms`)

Unsuccessful attempts typically feature:
- Rapid, erratic, or mixed input patterns
- No severe runloop stalls
- Normal event flow and process termination by debugger/system

## Requirements
- Implement a UI test in the `HammerTimeUITests` target.
- The test should:
  1. Launch the app and wait for initial UI to stabilize.
  2. Simulate a sequence of remote/DPAD inputs that matches the successful manual reproduction:
     - Multiple Right arrow presses (with short pauses between each)
     - Multiple Down arrow presses (with short pauses between each)
     - Repeat or combine with Up/Left as needed, based on successful log patterns
     - Ensure each input is followed by a brief delay to mimic human timing
  3. Monitor for signs of the InfinityBug:
     - Detect excessive runloop stalls or unresponsive UI
     - Optionally, check for a burst of repeated events or app hang
  4. Fail the test if the bug is not triggered within a reasonable time window.

## Acceptance Criteria
- The test reliably triggers the InfinityBug in local and CI environments (at least 80% of runs).
- The test logs or asserts when the bug is detected (e.g., by monitoring for a long runloop stall or UI unresponsiveness).
- The test is documented with comments explaining the input sequence and timing rationale.

## References
- See `memlog/LogComparison.md` for detailed analysis and log excerpts.
- Successful reproduction log: `SuccessfulRepro3.txt`
- Unsuccessful reproduction log: `unsuccessfulLog2.txt`

---
**Priority:** High
**Owner:** UI Automation/QA
**Tags:** UI Test, InfinityBug, Reproduction, Automation
