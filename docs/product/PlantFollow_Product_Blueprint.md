# PlantFollow Product Blueprint

**Product:** PlantFollow  
**Platform:** iOS / Flutter  
**Company:** Marberx Technologies  
**Blueprint date:** 30 August 2026  
**Purpose:** Approved product direction before implementation  
**Scope:** Sections 1–15

> This Markdown edition removes presentation-only HTML, CSS, fonts, and SVG diagrams from the original Claude blueprint while preserving the product decisions and implementation-relevant logic.

---

# Executive Product Direction

## Core Positioning

**PlantFollow is the plant app that checks back.**

Store-line direction:

**Identify it. Fix it. We’ll check back.**

Grower direction:

**From seed to harvest — and we check in along the way.**

Internally, the strategic territory is **Outcomes**.

Externally, the user-facing promise is:

**We check back.**

PlantFollow must not become another plant identifier with care features attached.

Identification is the acquisition door.

The differentiated product begins after the answer.

## Universal Product Loop

**Notice → Answer → Act → Check Back → Record**

Houseplant example:

Brown leaf  
→ diagnosis  
→ treatment  
→ Day 3 / Day 7 check  
→ recovered / unresolved / lost

Food-growing example:

Sowing  
→ grow plan  
→ action  
→ stage check  
→ harvest

Identification is not one of the five core beats.

It is the entry point into the loop.

---

# 01 — Positioning

## Product Territory

The word **Follow** only has product meaning when PlantFollow actually returns to the user after an action.

Without scheduled check-ins and recorded outcomes, “Follow” is only branding.

The product must therefore make the second visit real.

The differentiated mental slot is not:

- “What plant is this?”
- “When should I water it?”
- “Give me generic plant advice.”

It is:

**“Did what I did actually work?”**

## Positioning Risks

### Do not imply continuous monitoring

PlantFollow does not continuously monitor plants with hardware or sensors.

The app checks back **with the user** and relies on user input/photos.

### Do not become a nagging app

The check-back promise depends on notifications.

Poor frequency management can destroy the positioning.

Notification restraint is therefore a core product rule, not polish.

### First diagnosis must prove the promise

If the user's first diagnosis has no check-back experience, the product promise is broken immediately.

The recovery loop cannot be unavailable from the first meaningful case.

### “Follow” applies to plants only

Never use “Follow” socially for people, profiles, creators, or feeds.

---

# 02 — Product Model

## Architectural Principle

Everything that happens to a plant should append to **one plant event log**.

Do not create independent disconnected histories for:

- care history
- health history
- photo diary
- diagnosis history
- recovery history
- completed tasks
- harvest history

These should be different views over the same event system.

## Core Object Relationship

Conceptually:

**User → Locations → Plant Record**

Each Plant Record connects to:

- care rules / tasks
- diagnoses / recovery cases
- growth stage / photos
- harvests / milestones
- community questions later

All of them append to:

**Plant Event Log**

That event log ultimately produces:

**Outcome Records**

The outcome dataset is the long-term data asset.

---

## Plant Record — Required Foundation

### Identity

Recommended concepts:

- `id`
- `species_id`
- `species_confidence`
- `common_name`
- `nickname`
- `identified_at`
- `id_source`

Identification confidence must be persisted, not merely displayed.

### Placement

Recommended concepts:

- `location_id`
- `context`
- `light`
- `under_cover`

`context` examples:

- indoor
- outdoor_potted
- garden_bed
- greenhouse

Weather logic must understand plant context.

### Timeline Anchors

Nullable, user-confirmable anchors:

- `acquired_at`
- `sown_at`
- `germinated_at`
- `transplanted_at`

Grow plans should derive schedules from anchors.

Do not make a fixed calendar the source of truth.

### Classification

Recommended:

- `is_harvestable`
- `crop_id`

`is_harvestable` determines whether crop-specific modules appear.

Audience is a property of the plant—not a separate app mode.

### Derived State

Examples:

- `growth_stage`
- `stage_source`
- `health_state`
- `open_case_id`

Derived state may be cached for rendering but should remain reconstructable from underlying events.

### Care

Store **care rules**, not only fixed dates.

Possible concepts:

- care type
- base interval
- seasonal modifier
- dormancy window

### Media

Photos require purpose metadata:

- identification
- progress
- diagnosis
- check-in
- harvest

This enables proper before/after comparison and timeline rendering later.

### Notes

Notes are optional.

They attach to events.

The app should auto-create useful history without forcing the user to maintain a manual diary.

---

## Separate First-Class Objects

### Outcome

Outcome must be queryable as a first-class record.

Possible fields:

- `case_id`
- `result`
- `closed_at`
- `close_reason`

Possible result states:

- recovered
- improved
- unresolved
- lost
- unknown

### Location

Location owns climate context rather than duplicating climate data across every plant.

### Milestone

Houseplant users need payoff events even when they never harvest anything.

Examples:

- new leaf
- first flower
- one year alive
- recovery completed

---

# 03 — Recovery Loop

The recovery loop is PlantFollow's primary differentiator.

It is not three unrelated features.

It is one continuous system.

## Core State Flow

**Diagnosis**

→ **Recovery Case Opened**

→ **Treatment**

→ **Day 3 Check-In**

→ Better / Same / Worse

→ **Day 7 Check-In**

→ **Outcome**

Every case eventually produces an outcome record.

Unknown and unsuccessful outcomes must be recorded honestly.

Do not create a dataset containing only successful recoveries.

---

## Step 1 — Entry

Diagnosis can begin from:

- center camera → Diagnose
- “Something’s wrong” inside an existing plant

If the plant already exists in My Plants, avoid unnecessary species re-identification.

Capture guidance should focus on the affected area.

Example:

**“Get close to the affected leaf.”**

---

## Step 2 — Narrowing

Ask only questions that materially change the answer.

Target approximately two contextual questions, not a long questionnaire.

Examples:

- How long has it looked like this?
- Has anything changed recently?

Possible changes:

- moved
- repotted
- fertilized
- weather change

Questions should be skippable.

Use existing plant context whenever possible.

---

## Step 3 — Diagnosis

Diagnosis UX depends on confidence.

### High Confidence

Name the likely organism or condition specifically.

Avoid vague outputs such as:

“Pest problem.”

Prefer:

“Spider mites.”

Explain what visible evidence supports the conclusion.

### Medium Confidence

Show:

- primary diagnosis
- one credible alternative

Both can be inspected.

### Low Confidence

Do not pretend certainty.

Give:

- two likely explanations
- one safe action that works under both possibilities
- a future check-back step

Uncertainty becomes useful when the follow-up helps resolve it.

---

## Step 4 — First Aid

Before complicated plans or commercial interruption, show **one safe thing the user can do now**.

The action should ideally:

- be possible today
- use common materials
- avoid irreversible damage

Trust is built before complexity.

---

## Step 5 — Treatment Plan

Typically:

- 2–3 steps
- date / timing
- plain-language method
- rationale/source

Use **gentle-first ordering**.

Irreversible actions require explicit warning.

Examples:

- chemical treatment
- heavy pruning
- repotting a stressed plant

---

## Step 6 — Commitment

After starting the plan, create a Recovery Case.

Critical product sentence:

**“I’ll check back on Tuesday.”**

This is where the brand promise becomes a product behavior.

A check-in is then scheduled.

---

## Step 7 — Day 3 Check-In

Target interaction:

1. Take one new photo
2. Compare against original
3. User chooses:

- Better
- About the same
- Worse

The user's judgment leads.

Computer/AI comparison can support the judgment but should not silently overrule it.

### Better

Continue treatment and schedule the next check.

### Same

Adjust treatment and check again.

### Worse

Offer:

- alternative treatment
- escalation path
- Community later when available

---

## Step 8 — Day 7

Potential outcomes:

### Better again

Close as:

**Recovered**

### Same

Adjust once and optionally extend.

Extensions should not continue indefinitely.

Eventually close as unresolved/improved-but-unresolved.

### Worse

Offer alternative treatment or escalation.

---

## Step 9 — Outcome Record

When the case closes, the permanent plant history should contain:

- original problem
- treatment
- before photo
- after photo
- number of days
- final result

This is both:

1. valuable history for the user
2. the foundation of PlantFollow's outcome dataset

---

## Failure Branches

### Missed Day-3 Check

Send one gentle reminder.

Do not repeatedly nag.

Keep the check-in accessible from Today for a limited period.

Eventually close abandoned cases as:

**Unknown**

Never assume recovery.

### Treatment Not Completed

Offer:

**“I haven’t got to it yet.”**

Do not treat this as failure.

Allow:

- rescheduling
- easier alternative treatment

### Plant Gets Worse

Change the advice.

Do not repeat the same recommendation more aggressively.

Explain why the initial approach may not have worked.

### Low-Confidence Diagnosis

Use the follow-up as part of the diagnostic process.

The response to treatment can help distinguish competing hypotheses.

### Conflicting Diagnoses

Do not average conflicting diagnoses.

Do not silently choose one.

Ask the best discriminating question.

Keep both hypotheses available for later outcome analysis.

### Plant Dies

Use a calm, dignified flow.

Avoid:

- red alarms
- failure language
- guilt
- broken streaks

Offer:

- optional reflection
- archive instead of delete
- what to try differently next time

Record outcome as:

**Lost**

---

## Tone Rules

PlantFollow is about plants, not patients.

Avoid medicalized user-facing language such as:

- symptoms
- prognosis
- critical

Do not use survival percentages.

Do not use fear-driven countdowns.

When uncertain, always end with:

**what the user can do next.**

---

# 04 — Today

## Core Rule

**Today shows what needs a decision, not everything that is true.**

Today is not an analytics dashboard.

Maximum:

**3 primary action cards**

One can be visually dominant.

---

## Priority Order

### 1. Critical Weather

Examples:

- frost tonight
- dangerous heat

Only when relevant to actual outdoor plants.

### 2. Recovery Check Due

Recovery check-ins outrank routine care.

This is the core brand promise.

### 3. Today's Care

Show a manageable number of plants/tasks.

Each task should explain **why**.

Example:

“4 dry days, 31° forecast.”

### 4. Harvest Ready

Only when a real harvest window is active.

### 5. Milestone / Growth Event

Celebratory, not demanding.

### 6. Weather Handled It

Example:

“We skipped watering — 12mm rain.”

This acts as a receipt proving that PlantFollow adapts intelligently.

### 7. This Month

Grower-only seasonal information.

Only show for relevant users/plants.

### 8. Nothing Needed

This is a deliberate state.

Example:

**“Nothing needed today — everything’s on track.”**

Do not invent tasks just to make the screen look busy.

---

## Overdue Tasks

Never show an intimidating overdue wall.

Old tasks can collapse into one summary.

Example:

**“3 things slipped while you were away.”**

Possible actions:

- Done them
- Skip these

Skipping is useful behavioral data.

Do not punish it.

---

## Notification Principle

The original Blueprint establishes strict notification restraint.

The general product principle is:

**PlantFollow should never feel like a nagging task manager.**

Recovery and genuinely time-critical plant events outrank routine messages.

Detailed growth and notification orchestration is handled later in Section 16.

---

# 05 — Navigation

## V1–V3

Primary navigation:

**Today · Plants · [Camera] · Me**

Three actual tabs plus center camera action.

The camera is an action, not a persistent destination.

Camera opens modes:

- Identify
- Diagnose

It may remember the last-used mode.

---

## V4+

When Community has sufficient answer density:

**Today · Plants · [Camera] · Community · Me**

Do not add a Community tab before the community is genuinely useful.

An empty social destination damages perceived product quality.

---

## Feature Placement

### Identification

Center camera → Identify.

Also available from:

- Plants empty state
- first-run CTA

### Diagnosis

Center camera → Diagnose.

Also:

**Something’s wrong**

inside Plant Detail.

Diagnosis is not a dedicated tab.

### Plants

Tab 2.

Group by location by default.

Possible flat-list alternative.

### Care Tasks

Appear in:

- Today for action
- Plant Detail for schedule/history

Avoid adding another global tasks destination unless required.

### Recovery Cases

Recovery belongs **inside a plant**.

A due recovery check surfaces on Today.

Open recovery state may appear on the plant card/detail.

Do not create a separate global “Recovery” workspace.

### Grow Plans

Inside the plant.

Seasonal actions can surface through Today.

### Growth Timeline

Inside Plant Detail.

Conceptual segments:

**Care · Health · Timeline**

### Harvest

Logged from:

- plant
- Today harvest card

Season summaries belong to the relevant garden/location context.

### Community

V4 onward as primary navigation only when answer density exists.

Before that, community escalation can exist contextually inside difficult recovery cases.

### Me

Contains:

- profile
- settings
- subscription management
- notification controls
- data/export controls

---

# 06 — Houseplants and Food Growers

Do not build two separate products or modes.

The audience distinction belongs to each plant.

Core concept:

`is_harvestable`

determines whether grower-specific modules appear.

---

## Shared Product Spine

Both audiences use:

- plant record
- locations
- photos
- event log
- care tasks
- diagnosis
- recovery
- outcomes
- Today
- notifications

---

## Houseplant Emphasis

Examples:

- watering
- light
- humidity
- repotting
- toxicity
- milestones

Payoff:

**Milestone**

---

## Grower Emphasis

Examples:

- growth stage
- feeding by stage
- transplanting
- support/pruning
- planting calendar
- harvest window
- succession

Payoff:

**Harvest**

---

## Critical Personalization Rule

**No crop-specific UI appears until a harvestable plant exists.**

Do not show houseplant users:

- sowing calendars
- frost dates
- bed layouts
- harvest tools

even as disabled upsell cards.

For irrelevant users, these surfaces should be absent.

---

## Onboarding Timing

Do not force an audience survey before the user's first plant scan.

Preferred first sequence:

**Camera → Identification → Save → contextual setup**

Example contextual question:

**“Where does this one live?”**

Explicit broader audience selection can happen later.

---

# 07 — Adaptive Grow Plan

## Core Principle

The grow plan is not a fixed stored calendar.

It is derived from **confirmed anchor events**.

When an anchor changes, future dates are recalculated.

---

## Deterministic Planning

Potential inputs:

- sow date
- species timing
- germination date
- transplant date
- frost dates
- stage confirmation

Example:

If germination happens six days later than expected, downstream dates move approximately six days.

---

## Weather Adjustments

Examples:

### Rain

Postpone or reconsider watering.

### Heat

Shift watering earlier and increase check frequency where necessary.

### Frost

Surface plant protection actions.

### Sustained Cold

Widen growth/germination expectations rather than falsely declaring failure.

---

## Inference Rules

Photo-based stage detection may suggest:

**“Looks like it’s flowering — is that right?”**

Do not assert uncertain stages as fact.

### Do Not Ship Early

Yield prediction should not be presented before reliable data supports it.

Health-trend inference should support recovery check-ins rather than becoming a standalone absolute verdict.

---

## Plan Change UX

Whenever the plan changes:

- explain what changed
- explain why
- show important changed dates
- allow correction/undo
- batch changes

Never silently rewrite a user's garden plan.

---

# 08 — Weather-Aware Care

Forecasts describe an area, not a specific pot.

PlantFollow must adjust confidence based on placement.

---

## Indoor

Rain:

No direct schedule effect.

Frost:

Suppress irrelevant warnings.

Heat:

Only contextual advice where indoor conditions may genuinely be affected.

---

## Outdoor Potted

Rain:

Consider whether the plant is covered.

Pots often behave differently from beds.

Heat:

Higher drying risk.

Frost:

Concrete action may be:

**bring it inside**

---

## Garden Bed

Rain:

Meaningful measured rainfall can replace watering.

Heat:

Adjust timing and transplant advice.

Frost:

Recommend protection for relevant tender plants.

---

## “We Skipped Watering” Rule

Only make this strong claim when evidence supports it.

Prefer acting automatically when:

- plant context is known
- rain actually occurred
- rainfall crossed the selected threshold

Otherwise suggest checking.

Example:

**“It rained here yesterday — check the top 2cm before watering.”**

Being appropriately uncertain is better than confidently giving harmful advice.

---

# 09 — Growth and Harvest

## Growth Tracking

Growth tracking is expected category functionality.

Minimum credible implementation:

- dated plant photos
- optional size measurement
- growth stage
- auto-logged care events
- unified timeline

PlantFollow should improve this by making the app maintain the diary automatically.

Do not require users to manually write a journal for the product to become useful.

---

## Harvest

Harvest is strategically more differentiated.

### Use Harvest Windows

Do not pretend a crop has one exact harvest date.

Use a window.

### Multiple Harvests

One plant can create multiple harvest entries.

Important for crops that produce repeatedly.

### Fast Logging

Allow:

- weight
- count

Remember unit preference.

### Aggregation

Totals can ladder:

**Plant → Crop → Garden/Bed → Season**

### Season Summary

Create a meaningful end-of-season artifact.

This supports:

- retention
- sharing
- return next season

### Year-Two Comparison

Once history exists, show comparisons across seasons.

This becomes increasingly valuable because competitors generally lack longitudinal outcome history.

### Succession

When appropriate, help users decide what to sow next.

---

# 10 — Community Direction

Community is not an early product priority.

It should initially exist as an **escalation path from unresolved plant problems**, not as a generic social-feed strategy.

Community earns primary navigation only when there is enough answer density.

## Community Principle

**Answers matter more than feeds.**

A social destination containing unanswered posts damages trust.

Community should ultimately help with cases where:

- AI confidence is low
- treatments disagree
- recovery gets worse
- repeated attempts fail
- local climate knowledge matters
- the user explicitly asks for a person

The community case should inherit useful context from the plant/recovery case instead of forcing the user to rewrite everything.

---

# 11 — Free vs Premium Product Principle

The Blueprint's strategic acquisition principle is:

**Identification stays free and uncapped.**

Plant identification is the acquisition door.

PlantFollow should monetize continued plant intelligence and outcomes rather than blocking users from identifying plants.

The first meaningful diagnosis/recovery experience must demonstrate the check-back promise.

Detailed monetization, caps, rating, referrals and paywall orchestration are governed by the later **Section 16 Growth & UX Orchestration specification**.

Therefore, engineering must not finalize monetization behavior using Sections 1–15 alone when Section 16 is available.

---

# 12 — Product Roadmap Principle

Implementation must follow dependencies rather than visual attractiveness.

The core sequence is:

### Foundation

Create the durable Plant Record and event-log foundation.

### Recovery

Implement the recovery loop end to end.

### Today

Create the surface through which recovery and care become actionable.

### Credible Care

Improve care rules so users can trust them.

### Grower Intelligence

Add:

- garden setup
- adaptive grow planning
- growth stages
- harvest tracking

### Community Later

Community comes after core product value and answer-density readiness.

Do not build social infrastructure just to make the app appear larger.

---

# 13 — Build Priority

## Build These First

### 1. Event-Log Plant Record

This is the most expensive foundation to retrofit later.

### 2. Recovery Loop End to End

Must include:

- diagnosis
- treatment
- check-ins
- failure states
- outcome

Do not ship half of the loop while marketing “we check back.”

### 3. Today

Needed to expose relevant recovery/care actions without turning the product into a dashboard.

### 4. Credible Care Tasks

Tasks must understand plant context.

Avoid:

- huge overdue lists
- blind watering intervals
- generic one-size-fits-all reminders

### 5. Adaptive Grow Plan + Harvest

This completes the grower side of the product promise.

---

## Deliberately Lower Priority

### Community

Later, after product value and answer density.

### Camera Light Meter

Not a priority relative to the recovery loop.

Basic light context can be collected more cheaply through setup questions.

### General AI Chat

Do not prioritize generic AI chat merely because competitors have it.

If retained, plant-specific contextual AI is strategically stronger than generic conversation.

### Shared Gardens

Valuable but dependent on account/sync infrastructure.

Not the first-month retention differentiator.

### Outcome Statistics

Collect outcomes early.

Do not publish impressive-looking statistics until sample sizes support credible claims.

---

# 14 — Metrics

Do not optimize PlantFollow around vanity activity.

## Important Metrics

### Recovery Progress

Day-3 behavior is especially important because it proves whether users participate in the check-back loop.

### Season-Two Return

Critical long-term measure for growers.

This measures whether PlantFollow becomes part of someone's real gardening cycle.

### Community Answer Rate

Critical when Community launches.

Low answer density is a reason to withdraw or rethink the feature.

### Solved Question Rate

Useful after answer-rate health is established.

---

## Secondary / Weak Metrics

### Day-1 Retention

Watch it, but do not over-optimize it in a naturally lower-frequency category.

### Day-7 Check-In

Useful, though Day 3 is an earlier and stronger behavior signal.

---

## Vanity When Isolated

Do not treat the following as success without outcome/retention context:

- total plant identifications
- total downloads
- DAU by itself
- posts per day
- AI messages sent

A large number of scans without meaningful plant outcomes is not the product thesis.

---

# 15 — Final Decision

## PlantFollow Should Be

**The plant app that tells you what to do and then checks back to see whether it worked.**

## PlantFollow Should Not Become

Another plant identifier with a care calendar bolted on.

It should also not become a vegetable-garden planner that makes houseplant owners feel excluded.

---

## Primary Differentiator

**Recovery**

Diagnosis  
→ recovery plan  
→ Day 3 check  
→ Day 7 check  
→ recorded outcome

One connected system.

---

## Secondary Differentiator

**Adaptive growing**

A grow plan that changes when confirmed plant events change and eventually creates a harvest record.

---

## Acquisition Hook

**Unlimited free plant identification**

with:

- confidence
- toxicity/safety information

Identification should not be treated as the premium product itself.

---

## Daily Retention Hook

**Today**

Maximum three meaningful cards.

Every task should explain why it exists.

A designed “nothing needed” state is acceptable and desirable.

---

## Long-Term Moat

**Outcome data**

Core dataset shape:

**Problem · Treatment · Climate/Context · Result**

Over time, this enables PlantFollow to learn:

- what treatments actually worked
- for which plants
- in which conditions
- over what time period

This dataset becomes increasingly difficult for a competitor to copy because it requires real longitudinal user outcomes.

---

# Locked Product Principles from Sections 1–15

1. **PlantFollow is the plant app that checks back.**

2. **Outcomes are the strategy; “we check back” is the user promise.**

3. **Identification is the acquisition door, not the product loop.**

4. **Universal loop: Notice → Answer → Act → Check Back → Record.**

5. **Diagnosis must lead into treatment and a recovery case.**

6. **Recovery requires real follow-up and recorded outcomes.**

7. **Everything important that happens to a plant belongs in one event-driven history.**

8. **Today shows decisions/actions, not dashboard statistics.**

9. **Today remains intentionally small and calm.**

10. **Navigation for V1–V3: Today · Plants · [Camera] · Me.**

11. **Recovery belongs inside the plant, not in its own tab.**

12. **Community does not become primary navigation until V4/readiness.**

13. **Houseplants and food crops remain one product.**

14. **Audience-specific experiences are controlled by plant context, especially `is_harvestable`.**

15. **Do not expose crop-specific UI to irrelevant houseplant users.**

16. **Adaptive grow plans derive from confirmed events instead of storing rigid calendars as truth.**

17. **Weather-aware actions must respect indoor/outdoor/covered context.**

18. **The app should automatically build useful history rather than demanding manual diary work.**

19. **Harvest and milestones are outcome/payoff events.**

20. **General AI chat and light-meter enhancement are not priorities over recovery.**

21. **The outcome dataset is PlantFollow's long-term defensibility.**

---

# Developer Source-of-Truth Rule

For implementation:

1. This document defines **PlantFollow Product Blueprint Sections 1–15**.
2. The existing Flutter codebase defines what currently exists.
3. The separate **PlantFollow Growth & UX Orchestration — Section 16** defines final growth, monetization, rating, sharing, referral, permission and prompt rules.
4. When Section 16 explicitly changes a commercial/growth behavior implied by Sections 1–15, **Section 16 is newer and takes precedence for that behavior**.
5. Existing working Flutter architecture should be extended rather than replaced unless a product requirement genuinely requires structural change.
6. Do not redesign or delete existing functionality solely because it is low priority. First classify it as keep, modify, defer or retire-later.

---

**End of PlantFollow Product Blueprint — Sections 1–15**