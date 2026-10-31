# Functional Design Amendment 08: iOS segments at pauses, and punctuation on both platforms

**Unit**: 10, Mobile Platform Readiness (S-22). **Date**: 2026-10-30. **Revision**: 3. **Status**: APPROVED by James Petersen, 2026-10-30.
- **Revision 1:** approach B (split inside the session), `iosSegmentPause` = 1.5 s, and the rest as drafted.
- **Revision 2:** reset detection in BR-U10-69 (section 7), from CodeRabbit's review of `9b171cc`.
- **Revision 3:** tokens for languages written without spaces (section 8), from CodeRabbit's review of `0beea12`.

**Decisions recorded** (James Petersen, 2026-10-30, after the iOS Simulator pass):
- **iOS segments:** a pause in speech should start a new segment. Fix in Unit 10, before merge.
- **Punctuation and capitalisation:** in Unit 10.
- **A language selector:** Backlog, not Unit 10.

**Amendments 01 to 07 stand**, except where this one names them. No stable contract changes: `SttEngine`, `SttResult` and `RecordingState` are unchanged.

## 1. Why

- **iOS keeps a whole run as one segment.**
  - On the Simulator, a 2-minute run with pauses of up to 25 s stayed one block on screen. Its only `saveSegment` came at Pause or Stop (evidence, "Rerun of every microphone check after the fix").
  - `speech_to_text` 7.3.0 reports a final result only when the recognition task ends. Our iOS engine keeps one task open across pauses (Amendment 01).
  - **Consequences:**
    - the captions never break into phrases;
    - the transcript reaches storage only at Pause or Stop, so an app crash loses the whole run.
  - Android already splits at pauses: the recogniser's segmented session reports each phrase.
- **No punctuation, and few capitals.**
  - iOS: the engine listens with `SpeechListenOptions(onDevice: true)`, so `autoPunctuation` is false. The plugin sets Apple's `addsPunctuation` from that flag on iOS 16 and later (`SpeechToTextPlugin.swift:561-563`). The task hint is the default, `confirmation`, which is meant for short commands, not running speech.
  - Android: our recogniser intent sets no formatting extra, so formatting is left to the recogniser's own default.

## 2. Rules

| ID | Rule |
|---|---|
| BR-U10-68 | **iOS: a pause ends a segment, without ending the session.** While listening, when no new interim result has arrived for `iosSegmentPause` (a named constant in `SttListeningLimits`, proposed **1.5 s**), `PlatformSttEngine` delivers the pending interim text once **as a final result**. The plugin session keeps running: no stop, no restart, no gap in the audio. |
| BR-U10-69 | **iOS: later text starts after the committed words.** The plugin's results are cumulative for the whole session. After a pause commit, every later result (interim or final) is trimmed by the number of words already committed in this session, so only the new words are delivered. A result with no new words is not delivered. The count resets when a new plugin session starts (a restart, a resume or a new start). If Apple revises a committed word, the trim works by word count, so the boundary may repeat or drop a word. That is accepted, and recorded as a limitation. **Revision 2:** the trim applies only when the result continues the committed words. Otherwise the result is a reset (section 7). |
| BR-U10-70 | **iOS: the end of a session still flushes.** At Stop, Pause and the plugin's own session end, the drain rules (BR-U10-55, BR-U10-16) apply to the trimmed text only. Words already committed at a pause are never delivered twice. |
| BR-U10-71 | **iOS punctuation and capitalisation:** listen with `autoPunctuation: true` and `listenMode: ListenMode.dictation` (Apple's `taskHint = .dictation`, for running speech). On iOS 13 to 15 the plugin ignores the punctuation flag, so those versions show no punctuation. |
| BR-U10-72 | **Android punctuation and capitalisation:** the segmented-session intent adds `RecognizerIntent.EXTRA_ENABLE_FORMATTING = FORMATTING_OPTIMIZE_LATENCY` ("for real-time use cases") and `EXTRA_HIDE_PARTIAL_TRAILING_PUNCTUATION = true`, so interim text does not flicker a full stop. The formatted text is the first result in the list, which is the one the runner already reads. Android documents that the extra "may have no effect", so the device pass decides. |
| BR-U10-73 | **No new user setting.** Punctuation is always on, and the pause length is a constant. Both could become settings later; a future settings unit would own that. |

## 3. Interplay

- **The inactivity stop (Amendment 05):** a pause commit is a recognition result, so it restarts the inactivity timer exactly as a final result does today. The timer is unchanged.
- **The recovery (Amendment 06, BR-U10-57):** a committed segment has non-empty text, so it re-arms the recovery, the same as any result.
- **The transcript writer:** segments arrive as finals with gaps of at least 1.5 s. The writer's 2 s merge window (`_mergeWindowMs`) can join two finals less than 2 s apart into one stored segment. The on-screen captions split at 1.5 s, but storage merges anything under 2 s. That is accepted for Alpha 1 and recorded; the two values can be aligned later.
- **Log hygiene (SECURITY-03):** no text is logged by the new paths (TP-12 extended).

## 4. Testable properties

| ID | Property |
|---|---|
| TP-45 | Fake plugin and fake time: interim results, then `iosSegmentPause` with no new result, give exactly one final with that text, and the plugin is neither stopped nor cancelled. Further interim text gives finals with only the new words. A pause with no pending text delivers nothing. |
| TP-46 | Trim: across N pause commits, the concatenation of the delivered finals equals the plugin's last cumulative text, word by word. A plugin final at the session end delivers only the uncommitted words, and nothing if there are none. A new plugin session resets the count. |
| TP-47 | Drain (extends TP-34): Stop or Pause after a pause commit delivers only the new words, once. |
| TP-48 | The iOS engine listens with `onDevice: true`, `autoPunctuation: true` and `ListenMode.dictation`. The Android intent carries the two formatting extras, with an API-33 guard. |
| TP-12 (extended) | No log record on the new paths contains recognised text. |

## 5. QA

- **iOS Simulator:**
  - **pauses:** speech with pauses of about 3 s gives separate segments on screen, and a `saveSegment` at each pause;
  - **pause count:** History's segment count matches the number of pauses plus one;
  - **punctuation:** visible.
- **Android phone:**
  - **punctuation and capitals:** with the formatting extra, captions show them. If they don't, record it as "no effect on this recogniser";
  - **segments:** they still split at pauses as before.

## 6. Compliance

- **Security Baseline:** no new permission, and no text in logs.
- **PBT:** TP-45 and TP-46 are stateful properties over generated interim sequences (PBT-06).
- **No blocking finding.**

## 7. Revision 2: an iOS reset of the cumulative text

**Why:**
- On some iOS versions, the recogniser can start its cumulative text again after a pause, inside one `listen()` session (speech_to_text issue #552, "onResult words being reset while still listening").
- The iOS 26 Simulator did not do this in the device check.
- On a device that does, revision 1's trim by word count loses words:
  - a new phrase no longer than the committed count is dropped;
  - a longer one loses its first words.

**Rule (extends BR-U10-69):**
- The loop keeps the committed words, not only their count.
- A result **continues** the committed text when more than half of the committed positions match the result's words at the same positions. The comparison ignores case and punctuation.
- **A continuing result** is trimmed as before.
- **A result that does not continue is a reset:**
  - the committed words are cleared;
  - the whole result is delivered (an interim stays pending, as usual);
  - later results count from it.
- **Accepted trade-off:** if Apple rewrites more than half of the committed words in place, that looks like a reset, and the committed phrase appears again. Repeated words are preferred to lost words.
- No log line carries the words (SECURITY-03).

**Testable property TP-46 (extended):**
- After a commit, a result whose words don't continue the committed words is delivered whole, including one shorter than the committed count.
- Later results trim against the reset text.
- A result that changes fewer than half of the committed words is still trimmed.
- Across generated sequences with resets, no word of the plugin's text after a reset is lost.

## 8. Revision 3: languages written without spaces

**Why:**
- Chinese, Japanese, Thai, Lao, Khmer and Burmese are written without spaces between words.
- Splitting by whitespace makes a whole phrase one "word". So after "你好" is committed, the cumulative "你好世界" doesn't match it:
  - revision 2 delivers the whole phrase again, repeating "你好";
  - revision 1 dropped it.

**Rule (extends BR-U10-69):**
- **Tokens:** the trim compares tokens, not whitespace words. A token is either:
  - one character of the Han, Hiragana, Katakana, Thai, Lao, Khmer or Myanmar scripts; or
  - a run of other non-space characters.
- **Empty tokens:** a token that is empty once case and punctuation are removed, such as "，" or "。", is ignored, so punctuation the recogniser adds later doesn't shift the positions.
- **The cut:** the trimmed text starts at the first new token in the result's **original** text. Its punctuation and capitals are kept. Runs of whitespace collapse to one space, and leading and trailing spaces are removed, as in revision 2.
- **Unchanged:** the continuation test (more than half of the committed positions match) and the reset handling.
- **Languages with spaces:** the result is the same as revision 2. A word with punctuation attached ("there,") is one token.

**Testable property TP-46 (extended again):**
- Chinese: a commit, then cumulative text that continues it, delivers only the new characters, with the reset and revision rules applied per character.
- Japanese: the same, with mixed kanji and kana.
- English: the existing results are unchanged.
- Generated sequences in a no-space script lose and repeat no character.
