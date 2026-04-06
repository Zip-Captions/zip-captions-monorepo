# Unit of Work Dependencies — Phase 1: Core Captioning

## Dependency Graph

```
Spike 1.1 ──► Spike 1.3 ─┐
                           ├──► Unit 1: Core Abstractions
                           │
Spike 1.2 ─ ─ ─ ─ ─ ─ ─ ─│─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
  (parallel with Unit 1)   │                               │
                           │                               │
                    Unit 1: Core Abstractions               │
                           │                               │
              ┌────────────┼────────────┐                  │
              ▼            ▼            │                   │
     Unit 2: STT+Audio  Unit 3: Outputs│                   │
     (needs Spike 1.2)◄─ ─ ─ ─ ─ ─ ─ ─┘                   │
              │            │                               │
              └──────┬─────┘                               │
                     ▼                                     │
              Unit 4: UI Prototypes                        │
              ════════════════════                         │
              (HUMAN REVIEW GATE)                          │
                     │                                     │
              ┌──────┴──────┐                              │
              ▼             ▼                              │
     Unit 5: Zip     Unit 6: Zip                          │
     Captions        Broadcast                             │
     (Proto-01..05)  (Proto-06..09)                        │
              │             │                              │
              └──────┬──────┘                              │
                     ▼                                     │
        Unit 7: Integration Milestones                     │
        (Build & Test + Doc Refinement)                    │
```

**Legend**: Solid arrows (──►) = hard dependency. Dashed arrows (─ ─ ►) = timing constraint (can overlap). Double line (════) = human gate.

---

## Dependency Matrix

| Unit | Depends On | Blocks |
|------|-----------|--------|
| Spike 1.1 | (none) | Spike 1.3 |
| Spike 1.2 | (none) | Unit 2 |
| Spike 1.3 | Spike 1.1 | Unit 1 |
| Unit 1 | Spike 1.1, Spike 1.3 | Unit 2, Unit 3 |
| Unit 2 | Unit 1, Spike 1.2 | Unit 4 |
| Unit 3 | Unit 1 | Unit 4 |
| Unit 4 | Unit 2, Unit 3 | Unit 5 (Proto-01..05), Unit 6 (Proto-06..09) |
| Unit 5 | Units 1-3, Proto-01..05 approved | Unit 7 |
| Unit 6 | Units 1-3, Proto-06..09 approved | Unit 7 |
| Unit 7 | Units 1-6 | (none — final unit) |

---

## Parallelization Opportunities

| Parallel Group | Units | Condition |
|---------------|-------|-----------|
| Spikes | Spike 1.1 + Spike 1.2 | Independent; can run simultaneously |
| Spike 1.2 + Unit 1 | Spike 1.2, Unit 1 | Spike 1.2 only blocks Unit 2, not Unit 1 |
| Post-Unit 1 | Unit 2 + Unit 3 | Both depend only on Unit 1 (Unit 2 also needs Spike 1.2) |
| Post-Prototypes | Unit 5 + Unit 6 | Independent apps; can run in parallel once their respective prototypes are approved |

---

## Sequencing Timeline (Linear Path)

If executed sequentially (worst case):

```
1. Spike 1.1          ─────
2. Spike 1.3          ─────  (after 1.1)
3. Spike 1.2          ─────  (can overlap with 1.1, 1.3, or Unit 1)
4. Unit 1             ═══════════  (after 1.1 + 1.3)
5. Unit 2             ═══════════  (after Unit 1 + Spike 1.2)
6. Unit 3             ═══════════  (after Unit 1; can parallel with Unit 2)
7. Unit 4             ═══════  (after Units 2+3)
   ── HUMAN GATE ──
8. Unit 5             ═══════════  (after prototypes approved)
9. Unit 6             ═══════════  (can parallel with Unit 5)
10. Unit 7            ═══════  (after Units 1-6)
```

## Critical Path

```
Spike 1.1 → Spike 1.3 → Unit 1 → Unit 2 → Unit 4 → Unit 5/6 → Unit 7
                                 → Unit 3 ↗
```

The critical path runs through the STT spikes, core abstractions, platform STT (longest component unit), prototypes, and app UI. Unit 3 (Output Targets) is off the critical path if it completes before or during Unit 2.
