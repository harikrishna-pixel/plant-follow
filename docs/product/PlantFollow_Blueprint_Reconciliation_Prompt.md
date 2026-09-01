# PlantFollow Blueprint Reconciliation — Final Pre-Implementation Pass

The full approved `PlantFollow_Product_Blueprint` is now available in this repository.

You previously completed a PlantFollow Flutter codebase audit and produced a gap analysis.

Do NOT repeat the entire audit.

Do NOT write implementation code yet.

Your task is to reconcile your existing audit against the actual Product Blueprint and correct only the areas where the complete specification changes or clarifies your previous conclusions.

## 1. Read the Complete Blueprint

Read the entire `PlantFollow_Product_Blueprint`.

Treat it as the approved product source of truth for Sections 1–15.

The existing Flutter codebase remains the source of truth for what is currently implemented.

---

## 2. Validate the Previous Gap Matrix

Review every capability from your previous audit and confirm whether its classification remains:

- A — Already implemented and aligned
- B — Implemented but requires modification
- C — Missing
- D — Intentionally deferred

Change classifications where the actual Blueprint requires it.

Do not classify something as “Keep” merely because it already exists.

Distinguish:

**technically existing**

from:

**strategically important to PlantFollow.**

Existing features may remain in the codebase without being current implementation priorities.

---

## 3. Confirm Navigation

Compare the existing navigation directly against the Blueprint.

Specifically identify:

- existing bottom navigation
- Blueprint-required bottom navigation
- center camera behaviour
- Identify entry points
- Diagnose entry points
- Plant detail entry points
- Today
- Plants
- Me
- Community timing if specified

Do not modify navigation yet.

Return the exact navigation changes required, if any.

---

## 4. Confirm the Core Product Loop

Validate the implementation gap against the approved PlantFollow loop:

**Notice → Answer → Act → Check Back → Record**

Pay particular attention to:

**Diagnosis → Treatment → Recovery Case → Day 3 → Day 7 → Outcome**

Confirm which existing Flutter components can be reused and which new domain objects are actually required.

---

## 5. Validate Product Priorities

Re-check the Blueprint's phase/roadmap decisions for:

- Identification
- Today
- Plant collection
- Care tasks
- Diagnosis
- Recovery
- Plant timeline
- Grow plans
- Weather intelligence
- Growth milestones
- Harvest
- AI chat
- Search
- Light meter
- Community

Do not infer roadmap status.

Use the actual Blueprint.

---

## 6. Validate Existing Features Against Strategy

For existing features such as:

- AI Botanist
- generic plant search
- light meter
- folders
- wallet
- ads
- scan quota

label each as one of:

### KEEP — CURRENTLY IMPORTANT
Part of the approved current product experience.

### KEEP — LOW PRIORITY
May remain, but should receive no major development effort while core PlantFollow gaps remain.

### MODIFY
Existing feature conflicts with the Blueprint.

### RETIRE / HIDE LATER
Blueprint explicitly makes the feature unnecessary or strategically harmful.

Do not delete anything in this pass.

---

## 7. Check the 10-Plant Storage Limit

Determine from the code whether the 10-item Hive limit is:

- a deliberate business rule, or
- only an implementation/storage convenience.

The Product Blueprint is the authority on intended product limits.

Do not remove the limit yet.

State exactly what migration will be required if it must change.

---

## 8. Persistence Recommendation

Based on both the existing architecture and Blueprint, make a recommendation for V1 recovery persistence:

### Option A
Local-first using the existing Hive / local architecture.

### Option B
New backend/cloud persistence immediately.

Recommend one.

Do not build either yet.

Explain the tradeoff briefly, considering:

- current app architecture
- user migration risk
- development complexity
- offline use
- future account sync
- recovery reliability

---

# FINAL OUTPUT

Return only:

## A. Corrections to Previous Audit

Only items whose conclusions changed after reading the Blueprint.

## B. Final P0 Implementation Scope

The minimum work needed to turn the existing app into the approved PlantFollow core experience.

## C. Final P1 Scope

Important work that follows the P0 core.

## D. Deferred / Low-Priority Existing Features

Features that should not consume development effort yet.

## E. Navigation Changes Required

Exact changes only.

## F. Data / Migration Work Required

Especially stable plant IDs, Hive migration, reminders, diagnosis, recovery and timeline.

## G. Recommended Persistence Approach

Local-first or backend-first, with rationale.

## H. Implementation Sequence

Dependency-aware order.

---

# CRITICAL RULE

Do NOT write code.

Do NOT install packages.

Do NOT migrate data.

Do NOT modify navigation.

Do NOT change RevenueCat.

Do NOT change scan quotas or wallet logic yet.

Do NOT implement Section 16 growth rules yet.

This is the final reconciliation pass before engineering begins.