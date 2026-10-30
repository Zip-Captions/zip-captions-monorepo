// Unit 10, Amendment 03 (silent continuous captioning on Android): the
// Android side of `SegmentedRecognizerBridge`.
//
// The runner holds one on-device `SpeechRecognizer` and exposes it on
// `app.zipcaptions/segmented_speech` (methods) and
// `app.zipcaptions/segmented_speech/events` (the `RecognitionListener`
// callbacks). The segmented intent makes the recogniser keep listening for
// `EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS` and deliver each phrase through
// `onSegmentResults`, so Android's per-session chime sounds only on a user
// action or a renewal (BR-U10-43). The minimum length crosses as an `Int`:
// the service ignores the segmented session when it receives a Long
// (Amendment 03 section 1). The existing `app.zipcaptions/speech_support`
// channel answers the on-device check, whose floor is Android 13 / API 33
// (decision D-1) and which is locale-level since BR-U10-46a (Amendment 04
// revision 1c): the locale must be an installed on-device language.
//
// Every `result.success(...)` argument must be something Flutter's
// StandardMessageCodec can encode (null, Boolean, Int, String, List, Map).
// `kotlin.Unit` is not one of them: it fails with "Unsupported value:
// 'kotlin.Unit'", the Dart side sees a PlatformException, and a start looks
// refused (Step 30 QA finding Q-6). Reply `null` for "no value".
//
// SECURITY-03: no `Log` line, and no `result.error` message, ever carries
// recognised text — only event names, integer codes and exception class
// names.
package app.zipcaptions.captions

import android.annotation.SuppressLint
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.speech.ModelDownloadListener
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.SpeechRecognizer
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val recogniserTag = "ZipCaptionsSegmented"

    /** The recogniser holder: touched on the main thread only. */
    private var recogniser: SpeechRecognizer? = null

    /** Set by the event channel's StreamHandler, cleared on cancel. */
    private var eventSink: EventChannel.EventSink? = null

    /** The language-pack event channel's sink (Amendment 04). */
    private var languagePackSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // Unit 10, Amendment 02 section 3.1: answers the on-device support
        // question the speech_to_text plugin does not expose. The engine owns
        // the fail-closed rule (including its timeout); this only reports the
        // platform's answer, which since BR-U10-46a is locale-level.
        MethodChannel(
            messenger,
            "app.zipcaptions/speech_support",
        ).setMethodCallHandler { call, result ->
            if (call.method == "isOnDeviceSupported") {
                isOnDeviceSupported(call.arguments, result)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call,
            result ->
            when (call.method) {
                "start" -> start(call.arguments, result)
                "stop" -> {
                    runCatching { recogniser?.stopListening() }
                        .onFailure { logFailure("stop", it) }
                    result.success(null)
                }
                "cancel" -> {
                    runCatching { recogniser?.cancel() }
                        .onFailure { logFailure("cancel", it) }
                    result.success(null)
                }
                "recreate" -> {
                    // O-3: destroy and forget, so the next start builds a
                    // fresh recogniser against a restarted system service.
                    destroyRecogniser()
                    Log.i(recogniserTag, "recogniser recreated")
                    result.success(null)
                }
                "dispose" -> {
                    destroyRecogniser()
                    result.success(null)
                }
                "supportedLocales" -> supportedLocales(result)
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(
                    arguments: Any?,
                    events: EventChannel.EventSink?,
                ) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            },
        )

        // Unit 10, Amendment 04 (a missing on-device language): a dedicated
        // channel pair for the language-pack status and download, so the
        // speech event stream above stays unchanged.
        MethodChannel(messenger, LANGUAGE_PACK_CHANNEL).setMethodCallHandler {
                call, result ->
            when (call.method) {
                "status" -> languagePackStatus(call.arguments, result)
                "download" -> languagePackDownload(call.arguments, result)
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, LANGUAGE_PACK_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(
                    arguments: Any?,
                    events: EventChannel.EventSink?,
                ) {
                    languagePackSink = events
                }

                override fun onCancel(arguments: Any?) {
                    languagePackSink = null
                }
            },
        )
    }

    /** The intent that names a language for the support check and download. */
    private fun languagePackIntent(localeId: String): Intent =
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, localeId)
        }

    /** Tags compare case-insensitively, with '-' and '_' the same. */
    private fun normaliseTag(tag: String): String =
        tag.replace('_', '-').lowercase(Locale.ROOT)

    private fun containsTag(tags: List<String>, localeId: String): Boolean {
        val wanted = normaliseTag(localeId)
        return tags.any { normaliseTag(it) == wanted }
    }

    /**
     * Amendment 04: the state of the language's on-device model.
     *
     * `SpeechRecognizer.checkRecognitionSupport(Intent, Executor,
     * RecognitionSupportCallback)` (API 33) reports the installed, pending
     * ("scheduled for download") and supported-but-not-downloaded on-device
     * languages: developer.android.com/reference/android/speech/RecognitionSupport.
     * Below API 33, an error, or any throw, the answer is "unknown".
     */
    @SuppressLint("NewApi")
    private fun languagePackStatus(arguments: Any?, result: MethodChannel.Result) {
        val localeId = (arguments as? Map<*, *>)?.get("localeId") as? String
        if (localeId == null) {
            result.error("bad_arguments", null, null)
            return
        }
        val displayName = Locale.forLanguageTag(localeId)
            .getDisplayName(Locale.getDefault())
        var replied = false
        fun reply(status: String) {
            if (replied) return
            replied = true
            Log.i(recogniserTag, "language pack status: $localeId $status")
            result.success(
                mapOf("status" to status, "displayName" to displayName),
            )
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            reply("unknown")
            return
        }
        val recognizer = ensureRecogniser()
        if (recognizer == null) {
            reply("unknown")
            return
        }
        runCatching {
            recognizer.checkRecognitionSupport(
                languagePackIntent(localeId),
                mainExecutor,
                object : RecognitionSupportCallback {
                    override fun onSupportResult(support: RecognitionSupport) {
                        reply(
                            when {
                                containsTag(
                                    support.installedOnDeviceLanguages,
                                    localeId,
                                ) -> "installed"
                                containsTag(
                                    support.pendingOnDeviceLanguages,
                                    localeId,
                                ) -> "downloading"
                                containsTag(
                                    support.supportedOnDeviceLanguages,
                                    localeId,
                                ) -> "downloadable"
                                else -> "unsupported"
                            },
                        )
                    }

                    override fun onError(error: Int) {
                        Log.w(recogniserTag, "language pack check error $error")
                        reply("unknown")
                    }
                },
            )
        }.onFailure {
            Log.w(
                recogniserTag,
                "language pack check failed: ${it.javaClass.simpleName}",
            )
            reply("unknown")
        }
    }

    /**
     * Amendment 04: starts the model download for a language.
     *
     * API 34 and above: `SpeechRecognizer.triggerModelDownload(Intent,
     * Executor, ModelDownloadListener)` reports progress, success, a
     * scheduled download and errors as events. API 33:
     * `triggerModelDownload(Intent)` fires and the Dart side re-checks the
     * status. Below API 33 the reply is an error. The system may ask the user
     * to approve the download; the app does not suppress that (BR-U10-48).
     * Pages: developer.android.com/reference/android/speech/SpeechRecognizer
     * and .../ModelDownloadListener.
     */
    @SuppressLint("NewApi")
    private fun languagePackDownload(
        arguments: Any?,
        result: MethodChannel.Result,
    ) {
        val localeId = (arguments as? Map<*, *>)?.get("localeId") as? String
        if (localeId == null) {
            result.error("bad_arguments", null, null)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            Log.w(recogniserTag, "language pack download refused: os below 33")
            result.error("unsupported_os_version", null, null)
            return
        }
        val recognizer = ensureRecogniser()
        if (recognizer == null) {
            result.error("create_failed", null, null)
            return
        }
        val intent = languagePackIntent(localeId)
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                recognizer.triggerModelDownload(
                    intent,
                    mainExecutor,
                    modelDownloadListener(localeId),
                )
            } else {
                recognizer.triggerModelDownload(intent)
            }
        }.onSuccess {
            Log.i(recogniserTag, "language pack download requested: $localeId")
            result.success(null)
        }.onFailure {
            Log.w(
                recogniserTag,
                "language pack download failed: ${it.javaClass.simpleName}",
            )
            result.error("download_failed", it.javaClass.simpleName, null)
        }
    }

    /** Forwards the download's callbacks to the language-pack event sink. */
    @SuppressLint("NewApi")
    private fun modelDownloadListener(localeId: String): ModelDownloadListener =
        object : ModelDownloadListener {
            override fun onProgress(completedPercent: Int) {
                Log.i(recogniserTag, "language pack progress $completedPercent")
                emitLanguagePack(
                    mapOf(
                        "type" to "progress",
                        "localeId" to localeId,
                        "percent" to completedPercent,
                    ),
                )
            }

            override fun onSuccess() {
                Log.i(recogniserTag, "language pack download done: $localeId")
                emitLanguagePack(mapOf("type" to "done", "localeId" to localeId))
            }

            // BR-U10-47a: "Called when RecognitionService scheduled the
            // download, but won't satisfy it immediately. There will be no
            // further updates on this listener." A deferred download, not a
            // failure and not progress.
            override fun onScheduled() {
                Log.i(recogniserTag, "language pack download scheduled")
                emitLanguagePack(
                    mapOf("type" to "scheduled", "localeId" to localeId),
                )
            }

            override fun onError(error: Int) {
                Log.w(recogniserTag, "language pack download error $error")
                emitLanguagePack(
                    mapOf(
                        "type" to "failed",
                        "localeId" to localeId,
                        "code" to error,
                    ),
                )
            }
        }

    private fun emitLanguagePack(event: Map<String, Any>) {
        languagePackSink?.success(event)
    }

    /**
     * `SpeechRecognizer.isOnDeviceRecognitionAvailable` is API 31+, and
     * segmented sessions need API 33: the version check (decision D-1) comes
     * first and the call is never reached below it.
     */
    @SuppressLint("NewApi")
    private fun isOnDeviceRecognitionAvailable(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            SpeechRecognizer.isOnDeviceRecognitionAvailable(this)

    /**
     * BR-U10-46a (Amendment 04 revision 1c): the on-device check is
     * locale-level. True only when the OS is Android 13 or later, an on-device
     * recogniser exists, and the call's locale is among
     * `checkRecognitionSupport(...).installedOnDeviceLanguages`
     * (developer.android.com/reference/android/speech/RecognitionSupport).
     * A pending or only-supported language, an error, a throw, a missing
     * locale argument and a missing recogniser all answer false; the reply is
     * sent exactly once. The Dart engine's `onDeviceCheckTimeout` stays the
     * guard if the callback never comes. Logs carry the boolean and the
     * locale tag only.
     */
    @SuppressLint("NewApi")
    private fun isOnDeviceSupported(arguments: Any?, result: MethodChannel.Result) {
        val localeId = arguments as? String
        var replied = false
        fun reply(supported: Boolean) {
            if (replied) return
            replied = true
            Log.i(recogniserTag, "on-device check: ${localeId ?: "no locale"} $supported")
            result.success(supported)
        }
        if (localeId == null || !isOnDeviceRecognitionAvailable()) {
            reply(false)
            return
        }
        val recognizer = ensureRecogniser()
        if (recognizer == null) {
            reply(false)
            return
        }
        runCatching {
            recognizer.checkRecognitionSupport(
                languagePackIntent(localeId),
                mainExecutor,
                object : RecognitionSupportCallback {
                    override fun onSupportResult(support: RecognitionSupport) {
                        reply(containsTag(support.installedOnDeviceLanguages, localeId))
                    }

                    override fun onError(error: Int) {
                        Log.w(recogniserTag, "on-device check error $error")
                        reply(false)
                    }
                },
            )
        }.onFailure {
            Log.w(
                recogniserTag,
                "on-device check failed: ${it.javaClass.simpleName}",
            )
            reply(false)
        }
    }

    private fun start(arguments: Any?, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            // Decision D-1: no segmented session below Android 13. The reply
            // is an error so the bridge's `start` answers false.
            Log.w(recogniserTag, "start refused: os version below 33")
            result.error("unsupported_os_version", null, null)
            return
        }
        val args = arguments as? Map<*, *>
        val localeId = args?.get("localeId") as? String
        val minimumLengthMs = args?.get("minimumLengthMs") as? Int
        if (localeId == null || minimumLengthMs == null) {
            result.error("bad_arguments", null, null)
            return
        }
        val recognizer = ensureRecogniser()
        if (recognizer == null) {
            result.error("create_failed", null, null)
            return
        }
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, localeId)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            // End the session at the requested length, which is carried as
            // the `Int` below (a Long makes the service ignore this extra).
            putExtra(
                RecognizerIntent.EXTRA_SEGMENTED_SESSION,
                RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS,
            )
            putExtra(
                RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS,
                minimumLengthMs,
            )
        }
        runCatching { recognizer.startListening(intent) }
            .onSuccess {
                Log.i(recogniserTag, "segmented session started")
                result.success(null)
            }
            .onFailure {
                // The message crosses as a class name only: never its text.
                Log.w(recogniserTag, "start failed: ${it.javaClass.simpleName}")
                result.error("start_failed", it.javaClass.simpleName, null)
            }
    }

    @SuppressLint("NewApi")
    private fun supportedLocales(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(emptyList<String>())
            return
        }
        val recognizer = ensureRecogniser()
        if (recognizer == null) {
            result.success(emptyList<String>())
            return
        }
        val probe = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
        runCatching {
            recognizer.checkRecognitionSupport(
                probe,
                mainExecutor,
                object : RecognitionSupportCallback {
                    override fun onSupportResult(
                        support: RecognitionSupport,
                    ) {
                        val locales = linkedSetOf<String>()
                        locales.addAll(support.installedOnDeviceLanguages)
                        locales.addAll(support.pendingOnDeviceLanguages)
                        locales.addAll(support.supportedOnDeviceLanguages)
                        result.success(locales.toList())
                    }

                    override fun onError(error: Int) {
                        Log.w(recogniserTag, "support check error $error")
                        result.success(emptyList<String>())
                    }
                },
            )
        }.onFailure {
            Log.w(
                recogniserTag,
                "support check failed: ${it.javaClass.simpleName}",
            )
            result.success(emptyList<String>())
        }
    }

    /**
     * Creates the recogniser on demand (it lives on the main thread, and the
     * method channel handler runs there), wired to the forwarding listener.
     * Returns null when it cannot be built (the caller answers the Dart
     * side); below API 33 it is never built.
     */
    @SuppressLint("NewApi")
    private fun ensureRecogniser(): SpeechRecognizer? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            Log.w(recogniserTag, "create skipped: os version below 33")
            return null
        }
        recogniser?.let { return it }
        return runCatching {
            SpeechRecognizer.createOnDeviceSpeechRecognizer(this).also {
                it.setRecognitionListener(recognitionListener())
                recogniser = it
                Log.i(recogniserTag, "recogniser created")
            }
        }.onFailure {
            Log.w(
                recogniserTag,
                "create failed: ${it.javaClass.simpleName}",
            )
        }.getOrNull()
    }

    private fun destroyRecogniser() {
        runCatching { recogniser?.destroy() }
            .onFailure { logFailure("destroy", it) }
        recogniser = null
    }

    /** Forwards the recogniser's callbacks to the event sink. */
    private fun recognitionListener(): RecognitionListener =
        object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                emit(mapOf("type" to "ready"))
            }

            override fun onBeginningOfSpeech() = Unit

            override fun onRmsChanged(rmsdB: Float) = Unit

            override fun onBufferReceived(buffer: ByteArray?) = Unit

            override fun onEndOfSpeech() = Unit

            override fun onError(error: Int) {
                emit(mapOf("type" to "error", "code" to error))
            }

            override fun onResults(results: Bundle?) {
                // The final result of a non-segmented end: a segment here.
                firstResult(results)?.let {
                    emit(mapOf("type" to "segment", "text" to it))
                }
            }

            override fun onPartialResults(partialResults: Bundle?) {
                firstResult(partialResults)?.let {
                    emit(mapOf("type" to "partial", "text" to it))
                }
            }

            @SuppressLint("NewApi")
            override fun onSegmentResults(segmentResults: Bundle) {
                firstResult(segmentResults)?.let {
                    emit(mapOf("type" to "segment", "text" to it))
                }
            }

            @SuppressLint("NewApi")
            override fun onEndOfSegmentedSession() {
                Log.i(recogniserTag, "segmented session ended")
                emit(mapOf("type" to "endOfSession"))
            }

            override fun onEvent(eventType: Int, params: Bundle?) = Unit
        }

    private fun firstResult(bundle: Bundle?): String? = bundle
        ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        ?.firstOrNull()

    private fun emit(event: Map<String, Any>) {
        eventSink?.success(event)
    }

    private fun logFailure(operation: String, error: Throwable) {
        Log.w(recogniserTag, "$operation failed: ${error.javaClass.simpleName}")
    }

    // Both sinks are cleared: a model download can outlive the engine, and
    // its listener must not reach the old engine's sink.
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        destroyRecogniser()
        eventSink = null
        languagePackSink = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        destroyRecogniser()
        eventSink = null
        languagePackSink = null
        super.onDestroy()
    }

    companion object {
        private const val METHOD_CHANNEL = "app.zipcaptions/segmented_speech"
        private const val EVENT_CHANNEL =
            "app.zipcaptions/segmented_speech/events"
        private const val LANGUAGE_PACK_CHANNEL = "app.zipcaptions/language_pack"
        private const val LANGUAGE_PACK_EVENT_CHANNEL =
            "app.zipcaptions/language_pack/events"
    }
}
