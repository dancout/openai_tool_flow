---
title: "ADR-0001: Dart Version Compatibility (3.8.1 vs 3.9.1)"
status: "Accepted"
date: "2024-12-19"
authors: ["AI Assistant", "Package Maintainer"]
tags: ["dart", "compatibility", "dependencies"]
supersedes: ""
superseded_by: ""
adr_references: []
used_as_resource_in: []
---

# ADR-0001: Dart Version Compatibility (3.8.1 vs 3.9.1)

## Status

**Accepted**

## Context

The repository owner is running Flutter v3.32.8 locally with Dart 3.8.1 installed, but the package was initially configured with Dart 3.9.1 as the minimum version. This creates a compatibility issue where the local development environment cannot run the package due to the version constraint mismatch.

The question arises whether this package requires Dart 3.9.1 features or can safely run on Dart 3.8.1. This decision affects:
- Local development compatibility
- CI/CD pipeline requirements  
- Package distribution and adoption
- Future feature implementation constraints

## Decision

**Maintain Dart 3.8.1 as the minimum supported version.**

After analyzing the current codebase, the package does not use any features specific to Dart 3.9.1. The core functionality relies on:
- Basic class definitions and inheritance
- Generic types and collections
- Async/await functionality
- JSON serialization
- Factory constructors

All of these features are stable and available in Dart 3.8.1.

## Consequences

### Positive

- **POS-001**: **Broader Compatibility**: Supports more development environments and Flutter versions
- **POS-002**: **Immediate Development**: Owner can develop locally without SDK upgrades
- **POS-003**: **Lower Barrier to Entry**: Package adoption is easier for teams on older but stable Flutter versions
- **POS-004**: **Stability Focus**: Encourages using well-tested, stable language features

### Negative

- **NEG-001**: **Feature Limitations**: Cannot use newer Dart language features introduced in 3.9.1
- **NEG-002**: **Technical Debt**: May need to refactor if future requirements demand newer Dart features
- **NEG-003**: **Maintenance Burden**: Need to test against multiple Dart versions for compatibility

## Alternatives Considered

### Keep Dart 3.9.1 Minimum Version

- **ALT-001**: **Description**: Maintain current 3.9.1 constraint and require local environment upgrade
- **ALT-002**: **Rejection Reason**: Creates immediate development friction and doesn't provide tangible benefits for current feature set

### Target Latest Dart Version (3.10+)

- **ALT-003**: **Description**: Upgrade to latest Dart version for cutting-edge features
- **ALT-004**: **Rejection Reason**: Unnecessary complexity and compatibility issues without clear technical benefits

## Implementation Notes

- **IMP-001**: **Current Setting**: Dart SDK constraint remains at `^3.8.1` in pubspec.yaml
- **IMP-002**: **Feature Monitoring**: Future features requiring Dart 3.9.1+ should be documented and version constraint updated accordingly
- **IMP-003**: **Testing Strategy**: Ensure CI/CD tests against Dart 3.8.1 to maintain compatibility guarantee

## References

- **REF-001**: Dart 3.8.1 release notes and feature set
- **REF-002**: Flutter v3.32.8 compatibility matrix
- **REF-003**: Package's current pubspec.yaml configuration