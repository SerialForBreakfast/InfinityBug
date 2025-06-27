# Unreliable Tests Analysis

**Project Issue Discovered: 2025-01-22**

## Build Configuration Problem

**Issue**: `memlog/UnreliableTests.md` is incorrectly included in the Sources build phase of the HammerTime target, causing compilation error:
```
no rule to process file '/path/to/UnreliableTests.md' of type 'net.daringfireball.markdown' for architecture 'arm64'
```

**Root Cause**: Markdown files in memlog folder should not be compiled as source code.

**Fix Required**: Remove `UnreliableTests.md` from Sources build phase in project.pbxproj (requires user approval to modify project settings).

## Test Selection Pressure Analysis

This document tracks tests that have been marked for elimination due to poor reproduction performance or resource conflicts.

### Selection Pressure Criteria

Tests are evaluated based on:
1. **InfinityBug Reproduction Rate**: Primary success metric
2. **Resource Efficiency**: Memory/CPU impact on subsequent tests  
3. **System Stress Contribution**: Measurable impact on RunLoop stalls
4. **Interference Factor**: Whether test prevents others from succeeding

### Tests Under Evaluation

*Content to be added as tests are analyzed*
