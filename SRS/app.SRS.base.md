# Software Requirements Specification
## For [Project Name – TBD]
This specification is aligned with **IEEE 830** and **ISO/IEC/IEEE 29148:2011/2017**.
**Version 1.0**
Prepared by [Your Name]  
[Your Organization]  
2026-06-12

## Table of Contents
<!-- TOC -->
* [1. Introduction](#1-introduction)
    * [1.1 Document Purpose](#11-document-purpose)
    * [1.2 Product Scope](#12-product-scope)
    * [1.3 Definitions, Acronyms, and Abbreviations](#13-definitions-acronyms-and-abbreviations)
    * [1.4 References](#14-references)
    * [1.5 Document Overview](#15-document-overview)
    * [1.6 Business Context](#16-business-context)
* [2. Product Overview](#2-product-overview)
    * [2.1 Product Perspective](#21-product-perspective)
    * [2.2 Product Functions](#22-product-functions)
    * [2.3 Product Constraints](#23-product-constraints)
    * [2.4 User Characteristics](#24-user-characteristics)
    * [2.5 Assumptions and Dependencies](#25-assumptions-and-dependencies)
    * [2.6 Apportioning of Requirements](#26-apportioning-of-requirements)
* [3. Requirements](#3-requirements)
    * [3.1 External Interfaces](#31-external-interfaces)
    * [3.2 Functional](#32-functional)
    * [3.3 Quality of Service](#33-quality-of-service)
    * [3.4 Compliance](#34-compliance)
    * [3.5 Design and Implementation](#35-design-and-implementation)
* [4. Verification](#4-verification)
* [5. Appendixes](#5-appendixes)
    * [Appendix A: Informative Data Schema Example](#appendix-a-informative-data-schema-example)
    * [Appendix B: Derived Feeds Definition (Normative)](#appendix-b-derived-feeds-definition-normative)
<!-- TOC -->

## Revision History

| Name | Date | Reason For Changes | Version |
|------|------|--------------------|---------|
| Initial release | 2026-06-12 | First complete SRS | 1.0 |

## 1. Introduction

### 1.1 Document Purpose
This Software Requirements Specification (SRS) defines the functional and non‑functional requirements for a specialized social media platform that eternalizes a person’s finalized life work. The primary audiences are the two‑person development team and any future contributors. The SRS defines *what* the system must do (discovery rules, subscription, immutability, derived feeds) and the constraints that shape its design, not *how* it will be implemented.

### 1.2 Product Scope
The product (name TBD) is a concept social media platform that addresses the overabundance of careless writing by enforcing a strict discovery mechanism. Each author publishes a single prime text or a prime set (up to 4 images). Each viewer receives exactly one discovery chance per author. After an explicit choice (subscribe, next, or mark to read later), the author is permanently removed from that viewer’s discovery feed – even if the author later changes their prime content. Subscribers see all works in a separate subscribe feed. The database is fully immutable (no hard deletes). The project is a proof of design with expected <100 users initially. All feeds are derived from a single relation that tracks per‑(viewer, author) state.

### 1.3 Definitions, Acronyms, and Abbreviations

| Term | Definition |
|------|-------------|
| Prime text | The single text or hyperlink that represents an author for discovery. |
| Prime set | Up to 4 images (with names) shown simultaneously for visual artists; no mixing with text. |
| Discovery chance | The one‑time presentation of an author’s prime content to a specific viewer. |
| Discovery feed | A derived feed showing authors whose prime content has not yet been judged by the viewer. |
| Subscribe feed | A derived feed showing all works from authors the user has subscribed to. |
| Read later feed | A derived feed showing prime content of authors marked “read later”. |
| Viewed authors feed | A derived feed showing all authors whose discovery chance has been consumed, with action type and timestamp. |
| Relation | The logical record that stores per‑(viewer, author) state: discovery consumed, action type, subscription status, read later flag, etc. |
| Immutable data | Data that is never physically deleted; only logically marked as deleted. |

### 1.4 References
- (None external; design decisions are internal.)

### 1.5 Document Overview
Section 2 provides product overview, user characteristics, and constraints. Section 3 details all requirements (functional, QoS, design, compliance). Section 4 maps requirements to verification methods. Appendixes contain normative derived feed definitions and an informative data schema example.

### 1.6 Business Context (Informative)
**Problem** – Existing social media platforms incentivize high‑volume, low‑effort writing. Readers are overwhelmed by careless content, and creators have no motivation to finalize and refine their work before publishing. Meaningful, eternalized contributions are drowned.

**Solution Concept** – This project builds a proof‑of‑concept platform where each author gets exactly one discovery chance per viewer, enforced by a single prime text or prime set. The mechanism forces creators to finalize their best work before seeking attention, and viewers are never shown the same creator twice (unless they subscribe). This scarcity is intended to elevate worthy, finished work.

**Success Criteria for the Concept Phase** – The discovery‑chance mechanism works as specified (Section 3.2). A small group (<100 users) can successfully navigate discovery, subscription, and feeds. The system demonstrates technical feasibility. No external funding required; operates within minimal cost constraints.

**Constraints (Business)** – Two‑person development team. No legal or compliance obligations beyond user disclaimer. No expectation of revenue or user growth during concept phase.

## 2. Product Overview

### 2.1 Product Perspective
This is a new product, built from scratch as a two‑person concept project. It is not part of a larger system but may integrate email verification services and optionally content filtering bots. The product is standalone, with its own user identity mechanism and immutable storage. All feeds are derived from a single relation that ensures consistency and simplicity.

### 2.2 Product Functions
- User registration and email verification.
- Author profile creation, including setting a prime text or prime set (up to 4 images).
- **Single logical relation** that tracks per (viewer, author):
  - Whether discovery chance has been consumed
  - The consuming action (Subscribe, Next, Mark to read later) if any
  - Subscription status
  - Read later flag
  - (Optional) Like flag
- **All feeds are derived views** from this relation:
  - Discovery Feed → authors where discovery not consumed
  - Subscribe Feed → authors where subscribed = true
  - Read Later Feed → authors where read later = true
  - Viewed Authors Feed → authors where discovery consumed = true
  - (Optional) Liked Authors Feed → authors where liked = true
- Immutable storage (no hard deletes) with logical deletion.
- Tracking of user‑author relations sufficient to enforce one‑chance rule.

### 2.3 Product Constraints
- Technology stack: Flutter for front‑end (multi‑platform). Back‑end must support immutable storage and the defined relation model.
- Storage quota: 100 MB per user (free tier, subject to change).
- Scalability: Architecture must be *proof of design* scalable; actual expected load <100 users.
- Data immutability: No physical deletion. Logical deletion only.
- No “right to be forgotten”. Users accept that subscribers retain access to content as it existed at subscription time.
- Legal liability for content rests with the user; the app is not responsible.

### 2.4 User Characteristics
- **Viewer**: General user, browses discovery feed, makes choices (subscribe/next/read later). May also become an author.
- **Author**: A user who has published a prime text or prime set. Accepts the stake that changing prime content does not grant new discovery chances to viewers who have already judged.
- **Administrator** (the two developers): May perform logical deletion or review reports (future moderation).

### 2.5 Assumptions and Dependencies
- Availability of an email verification service.
- Storage system with quota enforcement (e.g., cloud storage).
- Immutable data capability (append‑only or soft‑delete with audit trail).
- Users will comply with the agreement that they are solely responsible for content legality.

### 2.6 Apportioning of Requirements
| Requirement Area | Planned Release | Notes |
|------------------|----------------|-------|
| Core discovery & subscription, derived feeds | v0.1 (concept) | All functional requirements. |
| Bot moderation extension | v0.2+ | Optional. |
| Performance optimization | v0.2+ | As needed for >100 users. |

## 3. Requirements

### 3.1 External Interfaces

#### 3.1.1 User Interfaces
- The system shall provide graphical user interfaces for mobile, web, and desktop (Flutter‑based).
- Discovery feed: presents prime content (text or up to 4 images simultaneously). Action buttons: Subscribe, Next, Mark to read later, Like, View Profile.
- Caching for accidental exit: if a discovery card is shown but no choice made, the same author’s prime content must be presented again in the next session.
- Subscribe feed: shows all works (prime and non‑prime) from subscribed authors.
- Read later feed: shows prime content of authors marked read later.
- Viewed authors feed: shows list of authors whose discovery chance has been consumed, optionally with action type and timestamp.
- Profile view: shows all works (including non‑prime). Browsing profile does NOT consume discovery chance.

#### 3.1.2 Hardware Interfaces
None.

#### 3.1.3 Software Interfaces
- Email verification service (e.g., SMTP or third‑party API).
- Persistent storage system with immutable characteristics (append‑only or soft‑delete).
- Local storage on client for accidental exit cache.

### 3.2 Functional

- **REQ-FUNC-001: User registration**  
  Statement: The system shall allow a user to register using an email address and shall record an IP address as an additional identifier.  
  Rationale: Basic identity for discovery tracking.  
  Acceptance Criteria: Email verification is required before becoming an author or subscribing.  
  Verification Method: Test.

- **REQ-FUNC-002: Prime content creation**  
  Statement: An author may publish either a single prime text (plain text or hyperlink) OR a prime set of up to 4 images (each with a name). Text and images cannot be mixed.  
  Rationale: Fairness between text and visual creators.  
  Acceptance Criteria: Author selects content type; system validates limits.  
  Verification Method: Test.

- **REQ-FUNC-003: Prime content modification**  
  Statement: An author may modify or withdraw prime content at any time. Viewers who already received a discovery chance based on the previous prime content shall never receive a new chance for that author.  
  Rationale: Author’s stake; finality of the discovery chance.  
  Acceptance Criteria: Changing prime content does not re‑expose author to viewers who have already judged.  
  Verification Method: Test.

- **REQ-FUNC-004: Discovery chance consumption**  
  Statement: The system shall maintain a logical relation for each (viewer, author). Initially, discovery consumed = false. After the viewer takes any of the consuming actions (Subscribe, Next, Mark to read later), the system shall set discovery consumed = true and record the action type. Once consumed, the author shall never appear again in that viewer’s Discovery Feed.  
  Rationale: Single chance enforcement.  
  Acceptance Criteria: Relation updated correctly; Discovery Feed excludes consumed authors.  
  Verification Method: Test.

- **REQ-FUNC-005: Viewer actions**  
  Statement: The system shall support three consuming actions (Subscribe, Next, Mark to read later) that set discovery consumed = true and record the action. Ancillary actions (Like, View Profile, click hyperlink) shall not change discovery consumed status.  
  Rationale: Clear separation.  
  Acceptance Criteria: Actions affect relation as specified.  
  Verification Method: Test.

- **REQ-FUNC-006: Mark to read later**  
  Statement: When a viewer chooses “Mark to read later”, the system shall set discovery consumed = true, action type = read later, and read later flag = true in the relation. The prime content shall be saved for later retrieval.  
  Rationale: Postponement without re‑exposure.  
  Acceptance Criteria: Relation updated; author removed from Discovery Feed; appears in Read Later Feed.  
  Verification Method: Test.

- **REQ-FUNC-007: Subscription**  
  Statement: When a viewer chooses “Subscribe”, the system shall set discovery consumed = true, action type = subscribe, and subscribed = true. Subscription does **not** re‑enable discovery for that author.  
  Rationale: Subscription is separate channel.  
  Acceptance Criteria: Subscribed authors appear in Subscribe Feed; never in Discovery Feed again.  
  Verification Method: Test.

- **REQ-FUNC-008: Profile browsing**  
  Statement: A viewer may visit an author’s profile and browse all works without consuming the discovery chance. Profile visits shall be recorded in raw history (no effect on discovery).  
  Rationale: Allows informed decision before committing.  
  Acceptance Criteria: After profile browse, the author’s prime content still appears in discovery feed (unless a consuming action was taken elsewhere).  
  Verification Method: Test.

- **REQ-FUNC-009: Accidental exit handling**  
  Statement: If a discovery card is presented but the viewer exits the app or session without making any consuming action, the system shall cache that author locally and present the same prime content again in the next session (still the same discovery chance).  
  Rationale: Avoids unintentional loss of chance due to technical issues.  
  Acceptance Criteria: After restart, same author appears again; no second chance is counted.  
  Verification Method: Test.

- **REQ-FUNC-010: Immutability and deletion**  
  Statement: The system shall never physically delete any data. Logical deletion (soft delete) shall hide a profile from discovery and prevent new subscribers, but existing subscribers shall retain access to all works.  
  Rationale: Eternalization and subscriber trust.  
  Acceptance Criteria: After logical deletion, profile not shown in discovery; subscribers still see content; no data loss.  
  Verification Method: Inspection and test.

- **REQ-FUNC-011: Relation tracking**  
  Statement: The system shall persist at least the following fields per (viewer, author): discovery consumed (boolean), action type (subscribe, next, read later, or null), subscribed (boolean), read later (boolean).  
  Rationale: Required to derive all feeds and enforce rules.  
  Acceptance Criteria: Fields update atomically on actions.  
  Verification Method: Analysis.

- **REQ-FUNC-012: Discovery Feed (derived)**  
  Statement: The Discovery Feed shall be derived as the set of authors where discovery consumed = false AND the author has published prime content. The feed presents each such author’s prime content.  
  Rationale: Only unseen authors appear.  
  Acceptance Criteria: Feed matches the derived set.  
  Verification Method: Test.

- **REQ-FUNC-013: Subscribe Feed (derived)**  
  Statement: The Subscribe Feed shall be derived as the set of authors where subscribed = true. It shall display **all works** (prime and non‑prime) from those authors.  
  Rationale: Subscription feed.  
  Acceptance Criteria: Feed includes all works from subscribed authors.  
  Verification Method: Test.

- **REQ-FUNC-014: Read Later Feed (derived)**  
  Statement: The Read Later Feed shall be derived as the set of authors where read later = true. It shall display the prime content of those authors.  
  Rationale: Dedicated feed for postponed content.  
  Acceptance Criteria: Feed includes authors marked read later.  
  Verification Method: Test.

- **REQ-FUNC-015: Viewed Authors Feed (derived)**  
  Statement: The Viewed Authors Feed shall be derived as the set of authors where discovery consumed = true. It may display action type and timestamp for each.  
  Rationale: Allows users to review authors they have already judged.  
  Acceptance Criteria: Feed includes all consumed authors.  
  Verification Method: Test.

- **REQ-FUNC-016: (Optional) Liked Authors Feed**  
  Statement: If the system records a liked flag in the relation, a Liked Authors Feed may be derived as authors where liked = true. Liking does **not** consume discovery chance.  
  Rationale: Optional engagement.  
  Verification Method: Test if implemented.

- **REQ-FUNC-017: Search**  
  Statement: The system shall provide a search function that allows a user to find any author by name (or handle). Search results are **not** filtered by discovery status – even authors marked “next” or “read later” appear.  
  Rationale: Provides a recovery path for accidental clicks and enables direct navigation.  
  Acceptance Criteria: Search returns authors regardless of discovery_consumed or action_type.  
  Verification: Test.

### 3.3 Quality of Service

#### 3.3.1 Performance
- **REQ-PERF-001**: Discovery feed load time < 2 seconds for up to 100 users.  
- **REQ-PERF-002**: Storage per user ≤ 100 MB.  
  Verification: Test under expected load.

#### 3.3.2 Security
- **REQ-SEC-001**: Email verification required before publishing or subscribing (prevents bot accounts).  
- **REQ-SEC-002**: User authentication credentials must be protected (e.g., hashed and salted if passwords are used).  
  Verification: Analysis and test.

#### 3.3.3 Reliability
- **REQ-REL-001**: The system shall handle accidental exit by caching the discovery state per user on the client.  
  Verification: Test.

#### 3.3.4 Availability
- **REQ-AVAIL-001**: Target 99% uptime for concept phase (≤7 hours downtime/month).  
  Verification: Monitoring.

#### 3.3.5 Observability
- **REQ-OBS-001**: The system shall log each consuming action (Subscribe/Next/Read later) with timestamp and user‑author pair.  
  Verification: Inspection.

### 3.4 Compliance
- **REQ-COMP-001**: User agreement must state that the user is solely responsible for content legality; the app disclaims liability.  
- **REQ-COMP-002**: No GDPR “right to be forgotten” – users are informed that data is immutable and subscribers retain access.  
  Verification: Inspection of legal text.

### 3.5 Design and Implementation

These requirements constrain *how* the system is built without specifying particular technologies.

#### 3.5.1 Installation
- **REQ-INST-001**: The application must run on iOS, Android, web, and at least one desktop operating system (Windows, macOS, or Linux).  
  Verification: Demonstration.

#### 3.5.2 Build and Delivery
- **REQ-BUILD-001**: Source code must be reproducible from a single repository. Build artifacts must be versioned.  
  Verification: Inspection.

#### 3.5.3 Distribution
- **REQ-DIST-001**: No multi‑region deployment required for concept phase.  
  Verification: Analysis.

#### 3.5.4 Maintainability
- **REQ-MAINT-001**: Code must be modular with separation between UI, business logic, and data storage.  
  Verification: Inspection.

#### 3.5.5 Reusability
None specified.

#### 3.5.6 Portability
- **REQ-PORT-001**: The system shall not rely on platform‑specific features that would prevent running on the target platforms (iOS, Android, web, desktop).  
  Verification: Demonstration.

#### 3.5.7 Cost
- **REQ-COST-001**: Monthly operating costs (hosting, storage, verification service) shall stay within free tiers or under $50 USD during concept phase.  
  Verification: Analysis.

#### 3.5.8 Deadline
- **REQ-DEAD-001**: Concept prototype milestone: to be determined.  

#### 3.5.9 Proof of Concept
- **REQ-POC-001**: The entire project is a proof of concept with <100 users, demonstrating the discovery scarcity mechanism and immutability.  
  Verification: Demonstration.

#### 3.5.10 Change Management
- **REQ-CM-001**: Changes to requirements shall be recorded in the Revision History of this SRS.  
  Verification: Inspection.S

## 4. Verification

| Requirement ID | Verification Method | Test/Artifact Link | Status | Evidence |
|----------------|---------------------|--------------------|--------|----------|
| REQ-FUNC-001 | Test | tests/registration_test | Planned | |
| REQ-FUNC-002 | Test | tests/prime_creation_test | Planned | |
| REQ-FUNC-003 | Test | tests/prime_modification_test | Planned | |
| REQ-FUNC-004 | Test | tests/discovery_consumption_test | Planned | |
| REQ-FUNC-005 | Test | tests/actions_test | Planned | |
| REQ-FUNC-006 | Test | tests/read_later_test | Planned | |
| REQ-FUNC-007 | Test | tests/subscription_test | Planned | |
| REQ-FUNC-008 | Test | tests/profile_browse_test | Planned | |
| REQ-FUNC-009 | Test | tests/accidental_exit_test | Planned | |
| REQ-FUNC-010 | Inspection + Test | tests/immutability_test | Planned | |
| REQ-FUNC-011 | Analysis | docs/relation_schema | Planned | |
| REQ-FUNC-012 | Test | tests/discovery_feed_derivation_test | Planned | |
| REQ-FUNC-013 | Test | tests/subscribe_feed_derivation_test | Planned | |
| REQ-FUNC-014 | Test | tests/read_later_feed_derivation_test | Planned | |
| REQ-FUNC-015 | Test | tests/viewed_authors_feed_test | Planned | |
| REQ-FUNC-016 | Test | tests/liked_feed_test (optional) | Planned | |
| REQ-PERF-001 | Test | performance/load_test | Planned | |
| REQ-SEC-001 | Test | tests/email_verification_test | Planned | |
| REQ-COMP-001 | Inspection | legal/user_agreement | Planned | |

## 5. Appendixes
(Optional supporting material that aids understanding without being normative.)

### Appendix A: Informative Data Schema Example

- **User**  
  - email (string, verified)  
  - ip_address (string, optional)  
  - created_at (timestamp)

- **AuthorProfile**  
  - prime_content_type: "text" | "images"  
  - prime_text: string (if text)  
  - prime_images: list of image references (max 4)  
  - image_names: list of strings (max 4)  
  - logically_deleted: boolean (default false)  
  - other_works: list of content items (each with type, content, timestamps)

- **ViewerAuthorRelation**  
  - viewer_id (reference to User)  
  - author_id (reference to AuthorProfile)  
  - discovery_consumed: boolean  
  - action_type: "subscribe" | "next" | "read_later" | null  
  - subscribed: boolean  
  - read_later: boolean  
  - liked: boolean (optional)  
  - consumed_at: timestamp  
  - updated_at: timestamp

**Immutability enforcement**: The storage system must never physically delete any record. Logical deletion is performed by setting `logically_deleted = true` on the author profile.

### Appendix B: Derived Feeds Definition (Normative)

Let `R(viewer, author)` be the relation with fields as defined in REQ-FUNC-011. Then:

- **DiscoveryFeed**(viewer) = { author | R.discovery_consumed = false AND author has published prime content }
- **SubscribeFeed**(viewer) = { author | R.subscribed = true } – then include all works of that author
- **ReadLaterFeed**(viewer) = { (author, prime_content) | R.read_later = true }
- **ViewedAuthorsFeed**(viewer) = { (author, R.action_type, R.consumed_at) | R.discovery_consumed = true }
- **LikedAuthorsFeed**(viewer) = { author | R.liked = true } (optional)

---

**End of SRS Version 1.0**