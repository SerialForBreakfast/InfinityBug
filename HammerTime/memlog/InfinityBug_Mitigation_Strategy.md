# InfinityBug Mitigation Strategy

## Overview
The InfinityBug is a tvOS focus system performance degradation that manifests as exponentially slower accessibility queries, leading to UI unresponsiveness. This document provides essential mitigation strategies based on successful reproduction analysis.

## Root Cause
- **Primary Issue**: Accessibility tree corruption causing focus queries to become 26x slower than normal
- **Trigger**: Complex UI layouts with multiple focus stressors operating simultaneously
- **Manifestation**: `Elements matching predicate 'hasFocus == 1'` queries degrade from <0.1s to 2-4s each

## Critical Mitigation Strategies

### 1. Avoid Problematic Layout Patterns
**DON'T:**
- Triple-nested collection view groups (`Cell → Horizontal Group → Vertical Group → Section`)
- Overlapping invisible focusable elements with `alpha = 0.01`
- Multiple hidden/visible focusable elements scattered throughout cells (8+ per cell)

**DO:**
- Use simple, flat layout hierarchies
- Minimize nested compositional layout groups
- Keep focusable elements clearly visible and non-overlapping

### 2. Focus Guide Best Practices
**DON'T:**
- Create circular focus guide references
- Rapidly change `preferredFocusEnvironments` (every 0.1s)
- Use focus guides with tiny frames (<6x6 points)

**DO:**
- Use static, well-defined focus guide configurations
- Ensure focus guides have reasonable frame sizes
- Test focus guide logic thoroughly before deployment

### 3. Accessibility Identifier Management
**DON'T:**
- Use duplicate `accessibilityIdentifier` values across multiple elements
- Generate identifiers that change frequently during runtime

**DO:**
- Ensure unique identifiers for all focusable elements
- Use stable, predictable identifier patterns
- Validate identifier uniqueness during development

### 4. Layout Timing Controls
**DON'T:**
- Invalidate layout at high frequency (every 0.03s)
- Combine multiple layout stressors simultaneously
- Use constant micro-animations that affect layout

**DO:**
- Batch layout updates when possible
- Use reasonable timing intervals for layout changes
- Minimize unnecessary layout invalidations

### 5. Performance Monitoring
**IMPLEMENT:**
- Monitor focus query performance in production
- Alert when accessibility queries exceed 0.5s
- Track focus state transitions for anomalies

**CODE EXAMPLE:**
```swift
// Monitor focus query performance
let startTime = CACurrentMediaTime()
let focusedElement = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == 1")).firstMatch
let queryTime = CACurrentMediaTime() - startTime

if queryTime > 0.5 {
    // Log potential InfinityBug condition
    NSLog("WARNING: Focus query took \(queryTime)s - potential InfinityBug")
}
```

## Development Guidelines

### Testing Requirements
- Run focus stress tests during development
- Validate performance under complex UI scenarios
- Test with multiple simultaneous focus stressors

### Code Review Checklist
- [ ] No circular focus guide references
- [ ] Unique accessibility identifiers
- [ ] Reasonable layout nesting depth (<3 levels)
- [ ] No high-frequency layout invalidations
- [ ] Focus query performance monitoring in place

## Emergency Detection
If InfinityBug is suspected in production:

1. **Immediate Check**: Monitor focus query timing
2. **Symptom**: UI becomes unresponsive to directional input
3. **Confirmation**: Focus queries taking >1 second consistently
4. **Mitigation**: Simplify layout hierarchy, remove focus stressors

## Key Metrics
- **Normal Performance**: Focus queries <0.1s
- **Warning Threshold**: Focus queries >0.5s  
- **Critical Threshold**: Focus queries >1.0s (InfinityBug likely)
- **System Failure**: Focus queries >2.0s (UI effectively frozen)

---
*Based on successful InfinityBug reproduction analysis - HammerTime Project 2025-06-20* 