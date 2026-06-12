## Recommended Stack (Concept Phase)

| Layer | Technology | Why |
|-------|------------|-----|
| **Frontend** | Flutter | Multi‑platform from one codebase. |
| **Backend** | Firebase (Firestore + Authentication) | Free tier generous (Spark plan: 1 GiB Firestore, 10 GB storage, 50k reads/day). Email verification included. No server management. |
| **Database** | Firestore (NoSQL) + immutability via logic | Supports soft deletes (set `deleted` flag). No physical deletes. Relation table fits naturally. |
| **User Authentication** | Firebase Auth (email + password or magic link) | Built‑in email verification, session handling, works with Flutter. IP address recorded separately. |
| **File Storage** | Firebase Storage | Store prime set images (up to 4 per author). Free tier: 5 GB storage, 50k downloads/day. 100 MB/user quota is easy to enforce. |
| **Backend Logic** | Direct Firestore queries from Flutter (optional Cloud Functions later) | For <100 users, direct queries + security rules suffice. Cloud Functions add cost/complexity; avoid unless needed. |
| **Immutability Enforcement** | App‑level + Firestore rules | Never call `delete()`; only write `deleted: true`. Firestore rules block physical deletes. Audit via timestamps. |
| **Local Caching (Accidental Exit)** | SharedPreferences or Hive | Store small map of `authorId: primeContentId` for current session. Cleared after choice or next session. |
| **Email Verification** | Firebase Auth | Automatic. |
| **Optional Bot Moderation** | Future – call free API (e.g., Perspective API) from Cloud Function | Not needed for v0.1. |

## Cost Estimate (Firebase Free Tier + Low Usage)

| Service | Free tier | Your usage (<100 users, low image uploads) |
|---------|-----------|--------------------------------------------|
| Firestore | 1 GiB storage, 50k reads/day | <0.5 GiB, <10k reads/day → free |
| Storage | 5 GiB, 50k downloads/day | <2 GiB, <1k downloads/day → free |
| Auth | 50k monthly active users | <100 → free |
| Cloud Functions (if used) | 2M invocations/month | Not needed → $0 |

**Total monthly cost: $0** (until you exceed free tier, unlikely in concept phase).