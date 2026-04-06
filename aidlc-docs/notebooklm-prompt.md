# NotebookLM Video Explainer Prompt

## Audience

The audience is technically literate but not experienced with code or software development. They understand complex systems, interdependencies, and organizational dynamics. They may be familiar with Zip Captions v1 as users, contributors, or community members. Frame everything in terms of systems, roles, and workflows — not syntax, frameworks, or implementation details.

## Tone

Conversational, clear, and optimistic without being hype-driven. Treat the audience as intelligent adults who deserve a straight explanation. Avoid jargon. When a technical term is unavoidable, define it in plain language immediately.

## Video Structure

### 1. What is Zip Captions? (30–45 seconds)

Zip Captions is a free, open-source tool that turns speech into text in real time — live captions for deaf and hard-of-hearing people. It runs on phones, tablets, laptops, and desktops. It works offline. It is free and always will be for core accessibility features. Nobody — not even the people who build it — can read your transcripts. That is a technical guarantee, not a policy.

But Zip Captions is not just software. It is an accessibility solution that belongs to its community. The goal has always been to build something the people who depend on it can also help shape, improve, and own — not just use.

### 2. Why a v2? What motivated the rebuild? (60–90 seconds)

v1 worked. It helped real people in real situations. But it was built as a web app, and that created ceilings the project could not grow past:

- **Cross-platform compatibility.** v1 ran in a browser, which meant it was limited to what the browser could do. It could not tap into the more powerful speech recognition engines built into phones and computers — engines that are faster, more accurate, and work offline. Moving to native applications means Zip Captions can now run directly on the hardware, on every major platform, using each device's best capabilities.

- **Device-first accuracy and performance.** In v1, speech recognition happened through a browser API that was inconsistent and unreliable across platforms. v2 takes a device-first approach — the app uses each platform's native speech recognition engine directly. This means better accuracy, lower latency, and true offline support. The processing happens on your device, not in a cloud service you do not control.

- **A bigger step toward privacy and security.** v1 stored transcripts in the browser using a client-server shared key — a common approach, but not a truly secure one. Browser storage is inherently accessible to the application serving it. v2 secures transcripts on-device behind proper authentication. Transcripts never leave your device unless you choose to use the optional premium cross-device sync feature — and even then, they are encrypted on your device first with a key that only you hold. The server cannot decrypt them. This is not an incremental improvement; it is a fundamentally different security model.

- **Reducing technical bottlenecks.** As the project evolved and needs grew, availability changed, and individuals who deeply understood the custom backend and specific technology choices became bottlenecks. The pressure to meet evolving user needs in that environment made it clear the project needed an architecture that distributed knowledge more broadly — so that no single person's availability could stall progress.

v2 is a ground-up rebuild that addresses all of these — not by being "better code," but by being structured so that the project can grow and adapt regardless of who is available to work on it at any given time. And critically, by lowering the barrier to contribution so that the community this tool serves can actually participate in building it.

### 3. What is different about v2? (90–120 seconds)

Three structural changes:

**a) Native apps that use the full power of each device.** v2 builds real native applications for iOS, Android, macOS, Windows, Linux, and web. Each platform's best speech recognition engine is used directly — the one built into iPhones, the one built into Android devices, open-source models on desktops. The result is better accuracy, faster performance, and reliable offline support everywhere.

**b) Two apps, one shared brain.** Instead of one app trying to serve everyone, v2 splits into two applications:
- **Zip Captions** — the personal app for everyday users (phone, tablet, laptop)
- **Zip Broadcast** — the professional app for streamers, educators, and event captioners (desktop only, with streaming software integration, multi-output, remote viewing)

Both apps share a common core library that contains all the important logic — speech recognition, caption processing, encryption, settings. A fix or improvement to the core benefits both apps automatically.

**c) On-device security by default.** Transcripts are stored securely on your device behind proper authentication. They do not go to a server. Period. If you opt in to the premium cross-device sync feature, transcripts are encrypted on your device before they leave — using a key that only you control. The server stores only encrypted data it cannot read. This is architecture, not a promise.

The backend itself uses an open-source platform that provides authentication, database, file storage, and real-time communication out of the box — replacing the custom-built server from v1. This dramatically reduces the specialized knowledge someone needs to understand and contribute to the project.

### 4. What is AI-DLC and why does it matter? (120–150 seconds)

This is the part that makes v2 fundamentally different from most open-source projects.

AI-DLC stands for "Agentic Development Lifecycle." It is a structured workflow that AI coding assistants follow when building features for this project. Think of it as a recipe book that an AI agent reads before it writes any code.

**Why this matters for non-developers:**

Traditionally, contributing to an open-source project requires you to:
1. Understand the codebase (often thousands of files)
2. Understand the conventions and patterns the project uses
3. Figure out where your change should go
4. Write the code
5. Write tests
6. Get it reviewed and merged

Steps 1–3 are the hard part. They represent months of accumulated knowledge that typically lives in one or two people's heads. When those people's availability changes — new jobs, new priorities, less time — the project loses momentum. Features wait. Bugs wait.

AI-DLC changes this by making that knowledge explicit and machine-readable. The project's requirements, architecture decisions, design patterns, testing standards, security rules, and coding conventions are all written down in structured documents that an AI agent can read and follow.

**Here is what the workflow actually looks like:**

1. **Someone states an intent.** "I want to add support for saving transcripts as subtitle files." No code knowledge required — just describe what you want.

2. **The AI runs an Inception phase.** It reads the project's requirements, architecture, and user personas. It asks clarifying questions. It produces a design document that a human reviews and approves. This is collaborative — the human makes decisions, the AI does the research and drafting.

3. **The AI runs a Construction phase.** Once the design is approved, the AI writes a detailed plan, gets approval, then writes tests based on the acceptance criteria, and then writes the code to make those tests pass. It follows the project's conventions automatically because they are documented in files it reads.

4. **A human reviews and merges.** The AI proposes a change. A human reviews it, and only a human can approve and merge it into the project.

**The key insight:** The AI handles the parts that require deep codebase familiarity. The human handles the parts that require judgment, intent, and approval. This means someone who has never looked at the code can describe a feature they want, collaborate with an AI through the design process, and end up with a properly tested, convention-following contribution — without needing to become a software developer first.

### 5. What does this mean for someone who wants to contribute? (60–90 seconds)

Zip Captions exists for a specific community — people who rely on real-time captions to participate in conversations, classrooms, meetings, and events. Those people understand the problem better than any developer ever could. They know what works, what does not, and what is missing. The goal of v2 is to make it possible for that community to not just use the tool, but to help build and shape it.

Previously, adding a feature meant becoming deeply familiar with the specific technologies the project was built on. The barrier was high, and only a handful of people could realistically do it. The people who understood the problem best were locked out of the process of solving it.

With v2 and AI-DLC, the contribution path looks different:

- **You can contribute by describing what you need.** "I want Zip Captions to vibrate my phone when someone says my name." That is a valid starting point for the AI-DLC workflow.

- **The design phase is conversational.** The AI will ask you questions: "Should this work offline? Should it work during broadcast sessions? What happens if the name appears in a foreign language?" You answer in plain language. The AI drafts the technical design.

- **You review the design, not the code.** The design documents describe what the feature does, how it fits into the existing system, and what the acceptance criteria are — all in plain language with diagrams. You can meaningfully review this even if you have never written a line of code.

- **The code is generated to spec.** Once you approve the design, the AI writes code that follows the project's existing patterns, security rules, accessibility standards, and architecture. A maintainer reviews the code itself.

- **The project is resilient to change.** Because the knowledge is in the documents — not in someone's head — any AI agent (or any new human contributor) can pick up where the last one left off. No single person's availability determines whether the project moves forward.

### 6. Want to try it? (5–20 seconds)

If you have access to an AI coding tool, getting started is simpler than you might think. Clone the project repository, open it with your AI assistant, and describe what you want to build. The project's documentation guides the AI through the rest — from design questions to working code. You do not need to know how the code works. You just need an idea.

### 7. What is the current status? (30 seconds)

v2 is in Phase 0 — Foundation. The project structure is built. The shared core library has 81 passing tests. Both app shells exist. The local development infrastructure and automated testing pipeline are being built now. There are 9 phases total on the roadmap, with core captioning — the heart of the product — coming next. The project is open source.

### 8. Closing (15–20 seconds)

Zip Captions v2 is not just a rewrite. It is an attempt to build an accessibility tool the way accessibility tools should be built — by the community that needs them, with AI handling the parts that used to require a software engineering background. If you use Zip Captions, you already understand the problem better than most developers. That is the hardest part. The rest, we can help with.
