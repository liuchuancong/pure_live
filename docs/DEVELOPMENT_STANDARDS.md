# DEVELOPMENT_STANDARDS.md

> This document defines the unified standards for code submissions, commit messages, and comments.
> Goal: Ensure all code is **readable, maintainable, reviewable, and traceable**.

---

## 1. Scope

This standard applies to:

- New files, functions, and modules
- Modifications, refactors, and completions of existing code
- Comments, documentation, and test cases
- Git commits (commit / MR / PR)

All submissions must comply with this standard.

---

## 2. Core Principles

| Principle | Description |
| --- | --- |
| Reviewable | Every change must let reviewers quickly understand "what changed and why" |
| Traceable | Commit messages and comments must clearly describe intent and context |
| Minimal Change | Do not introduce unrelated formatting, renames, or dependency changes |
| Explicit over Implicit | Comments, naming, and type annotations must express intent clearly |
| Accountability | The committer bears final responsibility for the submitted code |

---

## 3. Code Standards

### 3.1 General Requirements

- Follow the project's existing language style (PEP8 / Google Style / Airbnb, etc.). Do not introduce conflicting formatting.
- Indentation, line breaks, quotes, and semicolons must match the file being edited.
- Do not leave placeholders, sample code, or empty TODO stubs (unless explicitly marked as a TODO linked to an issue).
- Do not commit debug code: `print` / `console.log` / `debugger` / temporary blocks.
- Do not commit commented-out dead code (version control preserves history).

### 3.2 Naming

- Variable / function / class names must be semantically clear. Names like `data1`, `temp`, `foo`, `aaa` are forbidden (except idiomatic short-scope names like `i`, `e`).
- Naming style must match the project: `snake_case` / `camelCase` / `PascalCase` / `kebab-case`.
- Booleans should start with `is` / `has` / `can` / `should`.

### 3.3 Structure and Complexity

- A single function should not exceed 50 lines; cyclomatic complexity should not exceed 10.
- Avoid deep nesting (max 3 levels); prefer early returns.
- Extract logic repeated more than 3 times into a function / constant / utility.
- No hardcoded magic numbers or strings; use constants or configuration.

### 3.4 Error Handling

- Do not swallow exceptions (empty `catch` / `except: pass`).
- Error messages must include context (operation, parameters, cause).
- External input, network, file, and database operations must handle failure branches.
- Do not use exceptions to control normal flow.

### 3.5 Dependencies and Security

- Do not introduce unapproved new dependencies. If required, justify them in the commit message.
- Do not write secrets, tokens, passwords, internal addresses, or personal data.
- Do not generate insecure code (e.g., string-concatenated SQL, `eval`, disabled certificate validation).

---

## 4. Comment Standards

> **All comments MUST be written in English.**

### 4.1 Basic Principles

- Comments explain **Why**, while code expresses **What**.
- No meaningless comments: `i++ // increment i`.
- Comments must be updated together with code; stale comments are forbidden.
- Use the project's unified comment language. **For this project: English only.**

### 4.2 File Header Comment

Every new file must begin with:

```python
"""
Module: <module name>
Purpose: <one-sentence description of what this module does>
Author: <committer>
Created: YYYY-MM-DD
"""
```

### 4.3 Function / Method Comments

Public functions and complex logic must document:

- Purpose
- Parameters (type, meaning)
- Return value
- Exceptions / side effects
- Examples when necessary

Example (Python):

```python
def calc_discount(price: float, level: str) -> float:
    """Calculate the discounted price for a user.

    Args:
        price: Original price in yuan. Must be >= 0.
        level: User level. One of 'normal' | 'vip' | 'svip'.

    Returns:
        Discounted price, rounded to two decimal places.

    Raises:
        ValueError: If price is negative or level is invalid.
    """
```

Example (TypeScript):

```ts
/**
 * Calculate the discounted price for a user.
 * @param price Original price in yuan. Must be >= 0.
 * @param level User level: 'normal' | 'vip' | 'svip'.
 * @returns Discounted price, rounded to two decimal places.
 * @throws If price is negative or level is invalid.
 */
```

### 4.4 Inline Comments

- Use to explain non-obvious logic, algorithm sources, boundary conditions, or compatibility reasons.
- When referencing business rules, protocols, or algorithms, cite the source (doc link / issue ID).

```python
# round() must be used instead of int truncation
# to comply with financial rounding rules (see PRD-2024-031, Section 3.2).
```

### 4.5 TODO / FIXME

- Must include an owner and an issue ID.
- Format: `TODO(owner): description (#issue)`

```python
# TODO(zhangsan): Support multi-currency settlement (#1234)
# FIXME(zhangsan): Race condition under concurrency; needs a lock (#5678)
```

---

## 5. Git Commit Standards

> **All commit messages MUST be written in English.**

### 5.1 Commit Message Format

Use Conventional Commits:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Allowed types**:

| type | Meaning |
| --- | --- |
| feat | New feature |
| fix | Bug fix |
| refactor | Refactor without behavior change |
| perf | Performance improvement |
| docs | Documentation |
| test | Tests |
| chore | Build / tooling / dependencies |
| style | Formatting (no logic change) |

**Example**:

```
feat(order): support discount by membership level

- Add calc_discount function supporting normal/vip/svip tiers
- Add unit tests covering invalid level and negative price

Reviewed-by: zhangsan
Refs: #1234
```

### 5.2 Commit Granularity

- One commit should do one thing. Do not mix unrelated changes.
- Do not bundle massive formatting changes with functional changes.
- Split commits by module for easier review.

### 5.3 Prohibited Actions

- Do not commit code that fails to build / pass tests.
- Do not commit code containing secrets or credentials.
- Do not paste large conversation transcripts into commit messages.

---

## 6. Testing Standards

- New or modified logic must include corresponding unit tests.
- Tests must cover: normal path, boundary values, and error paths.
- Do not modify test assertions just to make tests pass (unless business rules changed, and document the reason).
- Test names must be clear: `test_<function>_<scenario>_<expected>`.

---

## 7. Review Requirements

- Every commit must be reviewed by at least one reviewer.
- Reviewers must focus on:
  - Logical correctness and business consistency
  - Boundaries and error handling
  - Security and permissions
  - Nonexistent APIs, dependencies, or fields
  - Consistency between comments and code
- Merging is allowed only after review passes.

---

## 8. Pre-Commit Checklist

- [ ] Code style matches the project
- [ ] No debug code, no commented-out dead code
- [ ] Naming is clear, no magic values
- [ ] Key functions are documented; comments match code
- [ ] Error branches are handled; no empty catch
- [ ] No secrets or sensitive information
- [ ] New / modified logic has tests, and they pass
- [ ] Commit message follows the convention
- [ ] **All comments and commit messages are written in English**

---

## 9. Appendix: Code Template

```python
"""
Module: discount
Purpose: Membership discount calculation
Author: zhangsan
Created: 2026-01-15
"""

from decimal import Decimal, ROUND_HALF_UP

# Discount rate per membership level
DISCOUNT_RATE = {
    "normal": Decimal("1.00"),
    "vip": Decimal("0.90"),
    "svip": Decimal("0.80"),
}


def calc_discount(price: float, level: str) -> float:
    """Calculate the discounted price for a user.

    Args:
        price: Original price in yuan. Must be >= 0.
        level: Membership level. One of 'normal' | 'vip' | 'svip'.

    Returns:
        Discounted price, rounded to two decimal places.

    Raises:
        ValueError: If price is negative or level is invalid.
    """
    if price < 0:
        raise ValueError(f"price must not be negative: {price}")
    if level not in DISCOUNT_RATE:
        raise ValueError(f"invalid membership level: {level}")

    # Use Decimal to avoid floating-point error,
    # as required for financial calculations.
    amount = Decimal(str(price)) * DISCOUNT_RATE[level]
    return float(amount.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP))
```

---

**Version**: v1.0
**Effective Date**: 2026-01-01
**Maintainer**: <team / owner>
**Revision History**: Register version, date, author, and changes for any updates.