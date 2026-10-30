/// The longest Stop may take, from the start of the stop routine until the
/// engine has stopped and the transcript is finalised (Unit 10 Amendment 06,
/// BR-U10-58).
///
/// It includes the 1 s drain of the last phrase (BR-U10-55). Past it the
/// notifier goes to Stopped anyway, releases the wake lock and reports the
/// transcript as not saved. The rule reads the value through
/// `stopFinaliseTimeoutProvider`, so tests can shorten it.
const defaultStopFinaliseTimeout = Duration(seconds: 5);
