# Knowledge_PlantFollow

**Project:** PlantFollow  
**Company:** Marberx Technologies Pvt Ltd  
**Document Type:** Canonical Product + UX + Implementation Knowledge  
**Status:** ACTIVE — SOURCE OF TRUTH  
**Knowledge Version:** 1.0  
**Updated:** 1 September 2026  
**Implementation Baseline:** Phases 1–6 complete; TestFlight Core Product QA pending  

---

# 0. AUTHORITY & PRECEDENCE

This file is the approved project-specific Knowledge source for PlantFollow.

For future PlantFollow product, UI/UX, Cursor, Claude, developer, QA, ASO, growth, or monetization work, use this precedence:

1. Latest explicit instruction from the product owner
2. `Knowledge_PlantFollow.md`
3. Final corrected Section 16 Growth Orchestration specification
4. PlantFollow Product Blueprint — Sections 1–15
5. Approved implementation decisions from completed development phases
6. PlantFollow Feature Dossier / Grow Plan research
7. Older Marberx generic roadmap, monetization, ASO, or competitor documents

If an older Marberx document conflicts with this Knowledge file, this Knowledge file wins.

## Explicitly superseded rules

The following older PlantFollow rules are RETIRED:

- 3 free identification scans per day
- visible scan counters
- “upgrade to scan more”
- automatic paywall immediately after the first successful recovery
- treating PlantFollow primarily as a plant identifier
- Home as a feature-launcher dashboard
- Ask Me / AI Botanist as a primary navigation destination
- global Tasks as the main care experience
- folders being treated as Locations
- crop/grow UI being shown to every user
- forcing a houseplant/grower user mode
- referral as an escape route from a plant-cap paywall
- generic promotional push notifications
- social/community engagement mechanics such as streaks, followers, likes, or engagement bait

---

# 1. PRODUCT IDENTITY

## Core product promise

**PlantFollow is the plant app that checks back.**

Expanded product definition:

**PlantFollow tells the user what to do and then checks back to see whether it worked.**

External acquisition/message direction:

**Identify it. Fix it. We’ll check back.**

## Strategic territory

PlantFollow owns:

**FOLLOW-THROUGH / OUTCOMES**

Identification gets the user in.

Follow-through is why the product should retain them.

## PlantFollow must NOT become

- another plant identifier with a care calendar attached
- a generic reminder app
- a vegetable garden planner that excludes houseplant owners
- a social plant feed
- an AI chatbot with plant features around it
- a feature dashboard containing every utility Marberx has built

## Primary differentiator

The Recovery Loop:

**Diagnosis → Treatment → Day 3 → Day 7 → Outcome**

This is one continuous product loop, not separate features.

## Secondary differentiator

Adaptive Grow Plan:

**Confirmed event → derived next stage → updated plan → harvest record**

Grow plans are secondary to the recovery/follow-through promise.

## Acquisition hook

**Unlimited plant identification for normal users.**

No visible scan counter.

Identification is the door into PlantFollow, not the business model.

## Daily retention surface

**Today**

Today shows only the small number of decisions that matter now.

## Long-term moat

The longitudinal outcome dataset:

- plant
- problem
- context
- treatment
- care actions
- climate
- check-ins
- result
- growth milestones
- harvest

---

# 2. UNIVERSAL PRODUCT LOOP

The universal PlantFollow loop is:

**Notice → Answer → Act → Check back → Record**

Examples:

### Identification

Notice:
User sees an unknown plant.

Answer:
PlantFollow identifies it.

Act:
User saves it / sets context.

Check back:
Future care, recovery, growth, or milestone actions surface.

Record:
Identification becomes part of the Plant Event Log.

### Recovery

Notice:
Something is wrong.

Answer:
Diagnosis + confidence + first aid.

Act:
Treatment begins.

Check back:
Day 3 and Day 7.

Record:
Outcome becomes permanent plant history.

### Care

Notice:
A believable care action is due.

Answer:
PlantFollow explains what needs attention.

Act:
User completes care.

Check back:
Next due state recalculates.

Record:
`care_completion` event.

### Grow

Notice:
A meaningful crop stage/action is approaching.

Answer:
PlantFollow shows what is next.

Act:
User confirms a stage or takes action.

Check back:
Future stages re-derive.

Record:
Milestone / harvest event.

---

# 3. NAVIGATION — LOCKED

## V1–V3 primary navigation

**Today · Plants · [Camera] · Me**

Camera is the center primary action.

Camera is NOT a persistent selected tab.

### Today

Decision surface.

Not a feature launcher.

### Plants

Saved plant collection and longitudinal plant records.

### Camera

Opens:

- Identify
- Diagnose

### Me

Account/settings plus secondary tools.

## Secondary tools

These currently remain available but are strategically lower priority:

- AI Botanist
- Search
- Light Meter
- Weather
- Scan History
- older reminder/history utilities
- Wallet
- account/subscription utilities

Do not delete these without a separate decision.

Do not promote them into the primary navigation.

## AI Botanist

Current location:

**Me → Tools → AI Botanist**

AI Botanist is KEEP — LOW PRIORITY.

It must not displace the recovery loop.

## Future Community navigation

Community may become a fifth primary destination only in the later Community phase after useful answer density exists.

Potential mature structure:

**Today · Plants · [Camera] · Community · Me**

Do not add Community to the primary bar prematurely.

---

# 4. TODAY — LOCKED BEHAVIOUR

Today answers:

**What actually needs my attention now?**

Today must never become:

- a feature dashboard
- a calendar dump
- an overdue wall
- an unlimited task feed
- a promotional feed

## Card limit

Maximum:

**3 primary action cards**

One may be visually dominant.

## Current priority direction

1. Valid critical plant/weather action
2. Recovery check-in due
3. Credible care due
4. Meaningful Grow Plan / harvest action
5. Recent milestone/outcome when space remains
6. Empty state

Recovery must outrank normal routine care.

Grow actions must not displace urgent plant health.

## Weather eligibility

Weather cards require actual plant context.

Currently outdoor-exposed contexts:

- `outdoorPotted`
- `gardenBed`

Not outdoor-exposed:

- `unknown`
- `indoor`
- `greenhouseCovered`

Do not infer exposure from species or folder.

If context is uncertain, suppress weather action.

## Empty state

Approved direction:

**Nothing needed today**  
**Your plants are on track.**

An empty Today screen is a valid success state.

Do not invent work to create engagement.

---

# 5. PLANT RECORD — FOUNDATION

The saved Plant is the central longitudinal object.

Every Plant has a durable business ID.

Do not use plant name as identity.

Do not use image-path hash as future business identity.

Legacy identifiers may remain for migration compatibility only.

## Durable fields implemented

Current additive Plant fields include:

- durable `id`
- placement/context
- `locationId`
- `isHarvestable`
- optional `cropId`

Legacy fields must remain migration-safe.

## Historical 10-plant deletion behaviour

RETIRED.

Saving more plants must not automatically delete the oldest plant.

---

# 6. PLANT EVENT LOG — SOURCE OF TRUTH

PlantFollow uses one append-only Plant Event Log for longitudinal activity.

Do NOT create separate competing history systems for new product capabilities.

Implemented/reserved event categories include:

- identification
- diagnosis
- treatment
- care completion
- recovery check-in
- plant photo
- outcome
- milestone
- harvest

Timeline, diary, care history, health history, and future statistics should be views over this event model wherever appropriate.

## Current event architecture

Events include conceptually:

- id
- plantId
- eventType
- timestamp
- payload
- source

The event log is local-first.

---

# 7. PLANT DETAIL — LOCKED PRODUCT HOME

Plant Detail is the longitudinal home for one saved plant.

Current primary structure:

**Care · Health · Timeline · About**

The existing screen was extended rather than replaced.

## Header

May surface:

- plant name
- plant image
- scientific identity
- placement
- Location
- concise current-state summary
- active recovery banner
- Something’s wrong

Avoid dense dashboard treatment.

The primary question is:

**How is this plant doing?**

---

# 8. CARE

Care must become believable and plant-linked.

It must not simply be arbitrary reminders.

## CareRule model

Current CareRule contains conceptually:

- id
- plantId
- careType
- baseIntervalDays
- lastCompletedAt
- nextDueAt
- enabled
- reminderId
- metadata

Rules use the durable `plant.id`.

## Existing reminders

Legacy reminder JSON remains supported.

Do not destructively migrate old reminder data.

New CareRule state may coexist with existing reminders.

Do not schedule duplicate notifications for one action.

## Completion

Completing care must:

1. update last completion
2. derive next due point
3. append `care_completion`
4. keep linked reminder compatible
5. refresh Today from the same shared state

## Care tone

Calm.

Examples:

**Water Snake Plant**

**Dry for 8 days.**

Only show explanations supported by real data.

Never invent:

- soil moisture
- weather effects
- root condition
- biological stress
- environmental causes

unless the app actually knows them.

Avoid guilt language.

Approved overdue direction:

**Still on the list — mark it when you can.**

---

# 9. PLANT CONTEXT & LOCATIONS

Plant placement and Location are different concepts.

## Plant placement

Implemented states:

- `unknown`
- `indoor`
- `outdoorPotted`
- `gardenBed`
- `greenhouseCovered`

Existing plants default safely to:

`unknown`

Never infer placement from species.

Never infer placement from folders.

## Context question

Approved contextual setup question:

**Where does this one live?**

Keep it lightweight.

Do not force old users through a migration questionnaire.

## Location

Location is a climate/property context object.

Current model includes conceptually:

- id
- name
- city
- postcode
- latitude
- longitude
- createdAt

A default Home Location may exist.

Plant can reference:

`locationId`

## Relationship

Conceptually:

**User → Location → Plant**

Example:

Location:
Home

Plant A:
indoor

Plant B:
outdoorPotted

## Folders

Folders remain organizational.

**Folders are NOT Locations.**

Do not automatically convert folders into Locations.

---

# 10. IDENTIFICATION

Identification is an acquisition hook and entry point.

It is not the core retention product.

## Locked product rule

**Unlimited identification for normal users.**

No visible scan counter.

No:

- “2 scans left”
- “3 scans/day”
- “upgrade to identify more”
- quota meter

If engineering cost becomes material, invisible fair-use protections may be considered.

Any safeguard that becomes visible to normal users requires product approval.

## Engineering assumption — NOT product fact

On-device or near-zero-cost identification has NOT been established as a guaranteed technical fact.

Engineering must validate:

- current model architecture
- accuracy
- latency
- cloud fallback percentage
- API cost
- caching
- perceptual image hashing
- rate limiting
- App Attest / API abuse protection
- battery/thermal impact

Do not write “on-device identification is already solved” into product copy unless validated.

## Identification quality direction

Future identification should support:

- confidence
- alternatives when uncertain
- safe refusal / uncertainty
- structured toxicity/safety information

Do not claim certainty when confidence is low.

---

# 11. DIAGNOSIS

Diagnosis entry points:

### Global

**Camera → Diagnose**

### Plant-linked

**Plant Detail → Something’s wrong**

Diagnosis must not become a permanent primary navigation item.

## Diagnosis model

Existing implementation supports:

- structured diagnosis
- confidence tier
- issue summary
- first aid
- treatment plan
- raw payload where required

Confidence:

- high
- medium
- low

## Tone

Use plant-care language.

Avoid unnecessarily medicalized or alarming language such as:

- critical prognosis
- patient
- severe medical metaphors
- catastrophic language

Communicate uncertainty clearly.

---

# 12. RECOVERY LOOP — PRIMARY DIFFERENTIATOR

Recovery is the most strategically important PlantFollow feature.

## Flow

**Diagnosis → First aid → Treatment → Recovery Case → Day 3 → Day 7 → Outcome**

## Case promise

Direction:

**I’ll check back.**

The product name “PlantFollow” only becomes meaningful when the application actually returns to the case.

## Day 3

Current implemented behaviour:

### Better
Proceed toward Day 7.

### Same
Allow limited additional check-in logic, then progress.

### Worse
Offer alternative treatment path and continue to Day 7.

### Haven’t done treatment
Allow deferment.

### Missed
One gentle reminder, then resolve safely rather than endless nagging.

## Day 7

Current flow can resolve toward:

- recovered
- improved
- unresolved
- lost
- unknown

Do not create endless recovery loops.

## Outcome

Outcome is first-class data.

Supported user-facing states include:

- Recovered
- Improved
- Unresolved
- Did not make it
- Outcome unknown

## Negative experience rule

Plant loss and worsening are sensitive moments.

Do not combine them with commercial interruption.

---

# 13. HEALTH SURFACE

Health reads the existing recovery domain.

Do not build another health state machine.

## Active recovery

May show:

- issue
- confidence
- stage
- next check-in
- treatment progress
- continue/check-in CTA

## Closed recovery

Show outcome.

## No active case

Approved neutral state:

**No active recovery**

Do not automatically claim:

**Your plant is healthy**

unless the app has sufficient evidence.

---

# 14. TIMELINE

Timeline is rendered from Plant Events for the selected plant.

Newest-first is current behaviour.

Current lightweight filters:

- All
- Care
- Health

Do not overengineer filtering.

## Readable event labels

Examples:

- Identified
- Diagnosis recorded
- Treatment started
- Watered
- Recovery check-in
- Photo added
- Recovery completed
- Sowed
- Sprouted
- Transplanted
- Flowering started
- First fruit
- Harvest recorded
- Grow plan completed

Never expose raw event wire names or JSON.

## Unknown event types

Fail gracefully.

Do not crash the Timeline because a future event type is unknown.

## Performance note

Current event storage scans the local event box then filters by `plantId`.

Acceptable at current scale.

If event volume becomes large, consider a per-plant index/partition.

Not currently a blocker.

---

# 15. HARVESTABLE PLANTS

Harvestability belongs to the Plant.

Current field:

`Plant.isHarvestable`

Optional:

`cropId`

## Critical rule

Do NOT create:

- Grower Mode
- Houseplant Mode
- account-level crop mode

Houseplants and crops coexist.

## Existing/default plants

Missing field defaults safely to not harvestable.

Do not infer harvestable status from folders.

## User opt-in

Current Plant Detail flow allows user to mark:

**Grown for harvest**

Current basic profiles include:

- General crop
- Tomato
- Leafy greens

Grow UI appears only when harvestable.

Houseplants should not see:

- sowing
- transplant stages
- harvest countdowns
- crop terminology

---

# 16. ADAPTIVE GROW PLAN

Grow Plan is PlantFollow’s secondary differentiator.

It must remain subordinate to the broader follow-through promise.

## Principle

Plans derive from confirmed anchors.

Do NOT treat a static generic calendar as truth.

## Current GrowPlan model

Conceptually:

- id
- plantId
- cropId
- createdAt
- status
- harvestRepeat
- anchors
- optional locationId
- optional notes
- completedAt

Derived future dates are not stored as independent truth.

## Confirmed anchor types currently implemented

- sowed
- germinated
- transplanted
- flowering started
- first fruit
- first harvest

## Confirmation

Stage changes come from user-confirmed facts.

Current natural controls include:

- I sowed it
- It sprouted
- I transplanted it
- Flowers appeared
- First fruit

Do not silently turn a prediction into a confirmed fact.

## Prediction language

If uncertain/predicted:

**Likely flowering soon**

Not:

**Flowering**

unless confirmed.

## Derived stages

Future plan stages should recalculate from latest confirmed anchors.

Past confirmed facts remain historical facts.

## AI stage recognition

NOT IMPLEMENTED.

Do not introduce it without explicit approval.

If added later, it should suggest, not silently confirm.

## Weather-driven plan adaptation

Future direction.

Not implemented as advanced intelligence yet.

Weather must not arbitrarily move stages without defined credible rules.

---

# 17. HARVEST

Harvest logging is implemented for harvestable Plants.

Current HarvestRecord can hold:

- plantId
- timestamp/date
- optional quantity
- optional unit
- optional note
- optional photo path

Photo capture is not yet wired into the harvest flow.

## Event behaviour

Harvest creates a `harvest` Plant Event.

First harvest also creates the appropriate first-harvest anchor/milestone.

## Quantity

Optional.

Never force yield tracking.

## Repeated harvest

Supported structurally.

Example:

Tomato = repeated harvest.

First harvest does NOT automatically close the plan.

## Season completion

Explicit:

**Season is done**

Do not automatically close a crop on an arbitrary date.

---

# 18. HOUSEPLANT MILESTONES — FUTURE

The milestone system must remain general.

Future houseplant examples may include:

- new leaf
- repotted
- flowering
- propagated

Do not couple `milestone` exclusively to agriculture.

Full houseplant milestone UX is not yet implemented.

---

# 19. COMMUNITY — FUTURE / V4+

Community must not begin as a generic feed.

Primary role:

**Recovery escalation**

Potential escalation triggers:

- low diagnosis confidence
- disagreement
- Day 3 worse
- repeated treatment failure
- unresolved case
- local/climate-specific question
- explicit user request

Community should not be promoted into Today merely to increase browsing.

## Community success gate

Answer density is load-bearing.

If Community cannot reliably produce useful answers, do not promote it as a primary destination.

Avoid:

- followers
- likes
- streaks
- XP engagement loops
- empty social feed behaviour

Contributor recognition should reward useful help, not vanity engagement.

---

# 20. MONETIZATION — FINAL LOCKED DIRECTION

Section 16 overrides older PlantFollow monetization documents and any conflicting earlier Blueprint paywall example.

## Unlimited identification

Identification remains unlimited for normal users.

Do not monetize scanning through visible quotas.

## Free tracked plants

Launch configuration:

**3 actively tracked plants free**

Capacity trigger:

Attempt to save **plant #4**.

This is a launch configuration, not proven optimum.

Later test:

3 vs 5 plants after enough retention/conversion data exists.

## First diagnosis

Free.

## First complete recovery

The entire first recovery is free:

- diagnosis
- treatment
- Day 3
- Day 7
- outcome

## CRITICAL MONETIZATION RULE

**The first recovery proves value. The next premium-intent action monetises that proof.**

The first successful recovery is NOT an automatic paywall trigger.

At first successful recovery:

- show outcome
- before/after where available
- passive Share may exist
- rating may happen only if eligible
- continue normally

No system-initiated commercial ask.

## Subscription-qualified

First successful recovery makes the user:

**subscription-qualified**

It does not automatically expose a paywall.

## Legitimate premium-intent triggers

Examples:

### Repeat recovery
Starting a second recovery case.

Primary monetization moment.

Care must never be blocked while a plant is worsening.

### Capacity
Attempt to save plant #4.

Free alternative:

Archive an existing plant.

### Grow intelligence
Second crop / adaptive grow functionality.

Free alternative should remain genuinely useful where specified.

### Advanced intelligence
Advanced weather explanations / multi-season comparison when eligibility conditions are met.

### Win-back
A lapsed subscriber intentionally returns to a Pro surface.

## Never monetize a sick plant

No commercial interruption:

- during worsening recovery
- while critical care is due
- immediately after plant loss
- during diagnosis/check-in
- inside frost/critical plant action

---

# 21. ASK ORCHESTRATOR — SECTION 16 LOCK

All proactive asks eventually route through one central arbiter.

No feature independently decides to interrupt.

## Flow

Candidate asks  
→ hard suppression  
→ Ask Ledger  
→ priority resolution  
→ maximum one prompted ask

Losing asks are:

**dropped**

not queued.

## Ledger

Starting rules:

- maximum 1 growth ask per 72 hours
- maximum 3 growth asks per rolling 30 days
- zero growth asks during first 72 hours after install
- 14-day suppression after major negative events

Negative events include examples such as:

- plant lost
- worsening recovery
- repeated identification failure
- payment failure
- support contact
- subscription cancellation

## Passive action

User intentionally chooses an existing control.

Examples:

- Share
- Upgrade
- View Pro
- Ask Community
- Restore Purchases

Passive actions do not consume the Ask Ledger.

## Prompted ask

App proactively asks.

Examples:

- rating request
- referral invitation
- system-initiated upgrade sheet
- permission dialog
- feedback request

Normally:

**one prompted ask per positive emotional moment**

Never chain them.

Forbidden example:

Recovery complete  
→ Rating  
→ Paywall  
→ Referral

---

# 22. ASK PRIORITY

Future Ask Orchestrator priority:

1. Critical plant action
2. Recovery action due
3. Core-loop permission
4. Product education
5. Monetization
6. Rating
7. Referral
8. Prompted share
9. Feedback survey

Critical plant/recovery work always outranks commercial requests.

---

# 23. ACTIVATION

Primary activation event:

**First completed care action or check-in on a saved plant.**

Saving a plant alone is not activation.

Identification alone is not activation.

The product is activated when the user follows PlantFollow’s guidance and completes an action.

Conceptual lifecycle:

Installed  
→ Identified  
→ Saved  
→ Activated  
→ Engaged  
→ Retained  
→ Subscription-qualified / High-intent

---

# 24. RATINGS

Do not ask for ratings based only on:

- app open
- scan completion
- session count
- arbitrary timer

No sentiment gate such as:

**Are you enjoying the app?**

before the native rating prompt.

Rating should require genuine positive behaviour/outcome.

Current Section 16 starting eligibility includes:

- activated
- at least 3 sessions
- at least 7 days since install
- positive resolution recently
- no negative event in previous 14 days

Native review-request frequency must remain conservative.

---

# 25. SHARING

Sharing should celebrate the user’s plant.

It should not look like an advertisement.

Best natural moments:

- before/after recovery
- first harvest
- season summary
- meaningful plant milestone

## Share-card principle

User’s plant is the hero.

PlantFollow attribution is subtle.

Direction:

- wordmark allowed
- no QR code
- no badge clutter
- no URL by default
- no location by default

Do not force sharing.

---

# 26. REFERRAL

Referral comes after success.

Never as desperation at a paywall.

## Launch experiment

Starting experiment:

**7 days Pro for inviter + invitee**

Reward occurs after invitee:

**activation**

not install.

The 7-day value is experimental.

The activation-based reward mechanism is the more important locked rule.

Permanent plant-slot rewards are not part of the initial test.

## Capacity paywall

Do not show referral as an alternative to upgrading when plant #4 is attempted at launch.

Use:

- Upgrade
- Archive a plant

Referral experiments at this moment require later controlled evidence.

---

# 27. NOTIFICATIONS

Notifications exist to preserve useful follow-through.

They must not become an engagement weapon.

## Product principles

- one-push-per-day philosophy remains load-bearing
- Section 16 starting budget: approximately 1/day and 4/week
- critical weather may be treated separately
- quiet hours should be respected
- no guilt language

## Promotional push

Forbidden:

- generic “we miss you”
- random discount
- generic sale
- unrequested feature promotion
- repeated subscription push
- engagement bait

## Contextual lifecycle messaging

Rare, contextual, relevant lifecycle notifications may be permitted under Section 16 rules.

Do not translate “no promotional spam” into “PlantFollow may never send any lifecycle notification.”

---

# 28. PERMISSIONS

Permission requests must occur when user value is clear.

## Camera

Request contextually when Camera is needed.

## Photos

Use system picker.

Do not request broad/full photo-library permission unnecessarily.

## Notifications

Ask in context of the follow-through promise.

## Location

Ask only when location-dependent value is clear.

A manual fallback must exist.

Weather functionality must not require GPS as the only path.

## ATT

Only relevant if paid acquisition/tracking requirements justify it.

---

# 29. UX TONE

PlantFollow should feel:

- calm
- useful
- intelligent
- supportive
- confident
- non-alarming
- outcome-focused

Avoid:

- guilt
- shame
- panic
- fake urgency
- streak pressure
- gamified plant neglect
- theatrical paywall animation
- excessive red
- excessive badges
- engagement manipulation

Examples of desired tone:

**Whenever you’re ready.**

**No active recovery.**

**Nothing needed today.**

**Your plants are on track.**

---

# 30. MOTION & HAPTICS

Motion should be semantic.

Do not use animation simply for decoration.

Respect Reduce Motion.

Avoid:

- confetti by default
- sound effects for ordinary success
- vibration during scroll
- theatrical commercial animations

Haptics should support meaningful interaction, not create noise.

---

# 31. CURRENT IMPLEMENTED STATE — PHASE 1

## Durable Plant Record

Implemented:

- durable UUID plant ID
- legacy-ID compatibility
- migration/backfill
- safe folder remapping
- removal of 10-plant FIFO deletion
- append-only Plant Event foundation
- reminder optional `plantId`

Local-first.

Existing architecture preserved.

---

# 32. CURRENT IMPLEMENTED STATE — PHASE 2

## Recovery Domain

Implemented:

- persistent structured diagnosis
- confidence
- first aid
- TreatmentPlan
- RecoveryCase
- Day 3
- Day 7
- RecoveryOutcome
- recovery persistence
- recovery notifications
- plant-linked diagnosis
- Something’s wrong
- active-case banner
- event writes for health lifecycle

No duplicate recovery state machine should ever be introduced.

---

# 33. CURRENT IMPLEMENTED STATE — PHASE 3

## Core navigation

Implemented:

**Today · Plants · [Camera] · Me**

Camera action:

- Identify
- Diagnose

Ask Me removed from primary navigation.

AI Botanist retained under Me → Tools.

## Today

Implemented:

- testable priority resolver
- maximum 3 cards
- recovery integration
- care integration
- calm empty state
- conservative weather eligibility

Phase 3 simulator smoke was not completed.

Status:

**Deferred to TestFlight Core Product QA — not failed.**

---

# 34. CURRENT IMPLEMENTED STATE — PHASE 4

Implemented:

- Plant placement/context
- first-class Location
- Plant → Location relationship
- CareRule
- durable plant-linked care
- care completion events
- existing reminder compatibility
- Today use of care rules
- conservative outdoor eligibility

Existing plants remain `unknown` until context is explicitly set.

Default Home Location exists.

Plants are not automatically assigned to Home.

---

# 35. CURRENT IMPLEMENTED STATE — PHASE 5

Plant Detail now provides:

- Care
- Health
- Timeline
- About

Implemented:

- shared Care completion
- shared Recovery health presentation
- outcome presentation
- Timeline mapper
- per-plant event history
- lightweight Timeline filters
- Today synchronization

Legacy Scan History / Chat History remain for compatibility.

Plant Event Log is future source of truth for per-plant longitudinal history.

---

# 36. CURRENT IMPLEMENTED STATE — PHASE 6

Implemented:

- `isHarvestable`
- optional `cropId`
- opt-in crop behaviour
- local GrowPlan
- confirmed anchors
- deterministic stage derivation
- Grow Plan card
- natural stage confirmation
- milestone events
- HarvestRecord
- repeated harvest support
- explicit season completion
- Grow Today actions
- Timeline Grow/Harvest rendering

No AI stage recognition.

No weather-driven stage movement.

Harvest photo path exists but capture is not wired.

---

# 37. CURRENT ENGINEERING CONSTRAINTS

PlantFollow is an existing Flutter app.

Do not treat it as greenfield.

Current broad architecture includes:

- Flutter
- Provider for core state
- GetX retained for navigation where already used
- Hive/local storage
- SharedPreferences for some legacy state
- Gemini/AI integrations
- existing weather service
- RevenueCat
- AdMob
- Mixpanel
- existing wallet/quota implementation still present in legacy code until Section 16 implementation changes it

## Architecture rule

Do not introduce:

- new state management framework
- new routing framework
- new database framework
- unnecessary backend
- cloud sync

without explicit architectural approval.

Prefer additive migration-safe changes.

---

# 38. CURRENT AUTOMATED TEST BASELINE

After Phase 6:

**81 automated tests passed**

covering Phases 1–6.

No analyzer errors were reported in the Phase 6 completion report.

This does NOT replace real-device QA.

---

# 39. TESTFLIGHT QA CHECKPOINT — CURRENT NEXT STEP

Before starting another major product feature phase, run the planned TestFlight Core Product QA.

Test combined Phases 1–6 on a real iPhone.

Critical journeys:

### Navigation

Today  
→ Plants  
→ Camera  
→ Me

### Identification

Camera  
→ Identify  
→ Result  
→ Save Plant  
→ Context

### Diagnosis / Recovery

Plant  
→ Something’s wrong  
→ Diagnosis  
→ Treatment  
→ Recovery  
→ Day 3  
→ Day 7  
→ Outcome

### Care

CareRule  
→ Today  
→ Mark done  
→ next due  
→ Timeline

### Grow

Harvestable plant  
→ Grow Plan  
→ anchor confirmation  
→ Today action  
→ Harvest  
→ Timeline

### Persistence

Force close / relaunch and verify all local state.

---

# 40. KNOWN ISSUES / DEFERRED ITEMS

## Manual Phase 3 smoke

Deferred to TestFlight QA.

## Restore Purchase

Known old route:

`Get.offAll(HomeScreen)`

may bypass the current bottom navigation shell.

RevenueCat logic itself must not be casually modified.

During TestFlight QA, navigation-only correction may be made if issue reproduces.

## Placement

Old plants remain `unknown` until user updates them.

Correct behaviour.

## Timeline performance

Current event store lacks plant-ID indexing.

Acceptable for current scale.

Revisit only if real event volume creates performance issues.

## Harvest photo

Model supports photo path.

Capture flow not implemented.

## Advanced weather

Not implemented.

## Weather-driven Grow Plan

Not implemented.

## AI stage inference

Not implemented.

## Community

Not implemented.

## Section 16 orchestration

Product rules are approved but implementation has NOT started.

---

# 41. FUTURE PHASE BOUNDARIES

Do not automatically build a feature simply because it exists in the Blueprint.

After TestFlight QA, decide the next phase based on actual product quality.

Future domains include:

### Advanced care/weather intelligence

Context + season + weather with credible reasons.

### Community

Recovery escalation first.

### Section 16

Ask Orchestrator, activation instrumentation, rating, sharing, referral, monetization orchestration, permissions/lifecycle behaviour.

### Multi-season intelligence

Later premium intelligence.

### Outcome statistics

Collect before publishing.

Do not show statistically weak “success rates” prematurely.

### Cloud/shared garden

Later.

Requires deliberate account/sync architecture.

---

# 42. METRICS

Important metrics include:

## Activation

First completed care action or check-in.

## Recovery

Day 3 completion is especially important.

Day 7 is secondary.

## Grow

Season-two return rate is critical long-horizon evidence.

## Community

If/when launched:

24-hour answer rate is the main viability metric.

## Avoid vanity optimization

Do not treat these alone as proof of product success:

- total scans
- total downloads
- DAU alone
- total AI messages
- total posts

The question is whether PlantFollow creates useful follow-through and outcomes.

---

# 43. BIGGEST PRODUCT RISK

**The check-back becomes a nag.**

The name requires PlantFollow to return.

If it returns too often or with irrelevant tasks, the product promise destroys itself.

Therefore these are load-bearing:

- maximum 3 Today cards
- conservative notification budget
- relevance before engagement
- quiet recovery handling
- no guilt
- no overdue wall
- no fake tasks
- no forced growth asks

---

# 44. BIGGEST PRODUCT OPPORTUNITY

The category gives users answers.

PlantFollow can own:

**what happened after the answer.**

The durable advantage is not:

“we identified your plant.”

It is:

**“We helped you act, checked what happened, and remembered the result.”**

---

# 45. ASO / MARKET MESSAGE SUPPORT

Existing useful PlantFollow keyword territories include:

### Identification

- plant identifier
- plant ID
- identify plant
- scan plant

### Plant care

- plant care
- garden care
- watering reminders

### Health

- plant disease
- plant health
- plant doctor / diagnosis-related intent

### Emotional/outcome

- healthy plants
- fix plant issues
- save dying plant

These keywords support acquisition.

They do NOT override the product positioning.

Avoid reducing store creative to:

“Plant Identifier + Care Tips.”

The stronger benefit story is follow-through.

Potential screenshot territory:

**Know What It Is**

**Know What To Do**

**We Check Back**

**See If It Worked**

**Grow With Confidence**

Final store creative must be designed separately and tested.

---

# 46. UI/UX DESIGN PRINCIPLES

For PlantFollow:

**Benefit > feature**

**Outcome > activity**

**Clarity > density**

**Calm > gamified**

**Relevant > frequent**

**Plant > app branding**

**Follow-through > identification**

Use:

- strong hierarchy
- clean spacing
- premium iOS-first presentation
- natural plant imagery
- concise text
- contextual explanation

Avoid:

- crowded cards
- excessive feature icons
- multiple competing CTAs
- dashboard mentality
- red warning everywhere
- large generic AI branding
- constant subscription badges

---

# 47. NON-NEGOTIABLE “NEVER DO” LIST

PlantFollow must never:

1. Show visible scan quotas to normal users.
2. Automatically paywall the first complete recovery.
3. Interrupt a worsening plant with monetization.
4. Ask rating + referral + paywall after one success.
5. Chain prompted asks.
6. Use fake urgency or scarcity.
7. Send guilt notifications.
8. Send generic promotional push spam.
9. Make users choose a permanent Grower/Houseplant mode.
10. Show crop UI to non-harvestable plants.
11. Turn Today into a feature dashboard.
12. Exceed the three-primary-card Today principle without explicit redesign approval.
13. Treat folders as Locations.
14. Create a duplicate Recovery state machine.
15. Create a duplicate longitudinal history database.
16. Silently infer important grow-stage facts.
17. Treat AI prediction as confirmed fact.
18. Reintroduce Ask Me as a primary tab without a new product decision.
19. Introduce Community as an empty generic feed.
20. Optimize short-term monetization at the expense of plant care or user trust.

---

# 48. PRODUCT DECISION TEST

Whenever a new PlantFollow idea is proposed, ask:

### Does it improve the loop?

Notice  
→ Answer  
→ Act  
→ Check back  
→ Record

### Does it create a better outcome?

If not, it is probably secondary.

### Does it deserve Today?

Only if the user needs to decide something now.

### Does it deserve primary navigation?

Only if it is a persistent top-level job.

### Does it deserve a notification?

Only if missing it would materially reduce user value.

### Does it deserve a paywall?

Only at a legitimate premium-intent moment after value has been proven.

### Does it respect the plant's current emotional state?

A worsening or lost plant overrides growth/conversion goals.

---

# 49. SOURCE TRACEABILITY

This Knowledge file consolidates and supersedes PlantFollow-specific decisions from:

- `plantfollow-blueprint.html`
  - Product Blueprint Sections 1–15
  - 30 August 2026

- `plantfollow-growth-addendum.html`
  - Section 16
  - Final approved specification
  - v2 lock pass
  - 1 September 2026

- PlantFollow Feature Dossier

- PlantFollow Grow Plan research

- approved Blueprint reconciliation

- implementation reports for Phases 1–6

Older references such as:

`Marberx Technologies – Monetization Strategy & Pricing.docx`

remain company historical context but are NOT authoritative where they conflict with this file.

In particular, the old PlantFollow:

**3 free scans/day**

rule is retired.

---

# 50. CURRENT PROJECT STATUS

## COMPLETE

**Phase 1**  
Durable Plant Record + Event Log

**Phase 2**  
Diagnosis + Treatment + Recovery + Outcomes

**Phase 3**  
Today + V1 Navigation + Camera Identify/Diagnose

**Phase 4**  
Plant Context + Locations + CareRule Foundation

**Phase 5**  
Plant Detail + Care + Health + Unified Timeline

**Phase 6**  
Adaptive Grow Plan + Milestones + Harvest Foundation

## CURRENT CHECKPOINT

**TestFlight Core Product QA**

No major new product phase should begin until the integrated Phase 1–6 experience has been reviewed on a real device unless the product owner explicitly overrides this checkpoint.

## NOT YET IMPLEMENTED

- Section 16 Ask Orchestrator
- new Section 16 monetization
- unlimited-scan product migration from legacy quota code
- 3-active-plant capacity monetization
- rating orchestration
- referral
- share-card system
- Community
- advanced weather intelligence
- multi-season intelligence
- cloud sync/shared gardens
- AI growth-stage recognition

---

# FINAL PRODUCT LOCK

PlantFollow is not successful because it recognizes a plant.

PlantFollow is successful when the user can say:

**“It told me what to do, came back to check, and I know whether it worked.”**

Every major future product, UX, growth, monetization, and engineering decision must preserve that promise.