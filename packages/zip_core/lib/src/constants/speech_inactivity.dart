/// How long a session may run without any recognition result before it is
/// stopped (Unit 10 Amendment 05, BR-U10-51 and BR-U10-52).
///
/// The rule reads the value through `speechInactivityTimeoutProvider`, so a
/// future settings screen can override it without changing the rule.
const defaultSpeechInactivityTimeout = Duration(minutes: 5);
