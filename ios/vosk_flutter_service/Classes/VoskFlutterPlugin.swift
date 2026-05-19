import Flutter
import UIKit
import AVFoundation

// vosk_api.h is exposed via the pod's public headers AND the module map.

class VoskEventHandler: NSObject, FlutterStreamHandler {
    private(set) var sink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }
}

public class VoskFlutterPlugin: NSObject, FlutterPlugin {
    var channel: FlutterMethodChannel?

    private let resultHandler = VoskEventHandler()
    private let partialHandler = VoskEventHandler()
    private let errorHandler = VoskEventHandler()

    // Maps to store pointers to C objects
    // Key: Path (String) -> Value: OpaquePointer (VoskModel*)
    private var modelsMap = [String: OpaquePointer]()
    private var speakerModelsMap = [String: OpaquePointer]()
    // Key: ID (Int) -> Value: OpaquePointer (VoskRecognizer*)
    private var recognizersMap = [Int: OpaquePointer]()

    // Audio service
    private var speechService: SpeechService?

    public static func register(with registrar: FlutterPluginRegistrar) {
        NSLog("VOSK_SWIFT: Registering VoskFlutterPlugin")
        let channel = FlutterMethodChannel(name: "vosk_flutter", binaryMessenger: registrar.messenger())
        let instance = VoskFlutterPlugin()
        instance.channel = channel

        FlutterEventChannel(name: "result_event_channel", binaryMessenger: registrar.messenger())
            .setStreamHandler(instance.resultHandler)
        FlutterEventChannel(name: "partial_event_channel", binaryMessenger: registrar.messenger())
            .setStreamHandler(instance.partialHandler)
        FlutterEventChannel(name: "error_event_channel", binaryMessenger: registrar.messenger())
            .setStreamHandler(instance.errorHandler)

        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        NSLog("VOSK_SWIFT: Handling method \(call.method)")

        // Automatically ensure audio session is configured for recording if needed
        if call.method.starts(with: "recognizer.") || call.method.starts(with: "speechService.") {
            configureAudioSession()
        }

        switch call.method {
        case "model.create":
            guard let modelPath = call.arguments as? String else {
                result(FlutterError(code: "WRONG_ARGS", message: "Model path missing", details: nil))
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                if let model = vosk_model_new(modelPath) {
                    DispatchQueue.main.async {
                        self.modelsMap[modelPath] = model
                        self.channel?.invokeMethod("model.created", arguments: modelPath)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.channel?.invokeMethod("model.error", arguments: ["modelPath": modelPath, "error": "Failed to load model"])
                    }
                }
            }
            result(nil)

        case "speakerModel.create":
            guard let modelPath = call.arguments as? String else {
                result(FlutterError(code: "WRONG_ARGS", message: "Speaker model path missing", details: nil))
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                if let model = vosk_spk_model_new(modelPath) {
                    DispatchQueue.main.async {
                        self.speakerModelsMap[modelPath] = model
                        self.channel?.invokeMethod("speakerModel.created", arguments: modelPath)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.channel?.invokeMethod("speakerModel.error", arguments: ["modelPath": modelPath, "error": "Failed to load speaker model"])
                    }
                }
            }
            result(nil)

        case "recognizer.create":
            guard let args = call.arguments as? [String: Any],
                  let sampleRate = args["sampleRate"] as? NSNumber,
                  let modelPath = args["modelPath"] as? String else {
                result(FlutterError(code: "WRONG_ARGS", message: "Missing required arguments", details: nil))
                return
            }

            guard let model = modelsMap[modelPath] else {
                result(FlutterError(code: "NO_MODEL", message: "Model not found: \(modelPath)", details: nil))
                return
            }

            let recognizerId = (recognizersMap.keys.max() ?? 0) + 1
            let rate = sampleRate.floatValue

            var recognizer: OpaquePointer?
            if let grammar = args["grammar"] as? String {
                recognizer = vosk_recognizer_new_grm(model, rate, grammar)
            } else {
                recognizer = vosk_recognizer_new(model, rate)
            }

            if let rec = recognizer {
                recognizersMap[recognizerId] = rec
                result(recognizerId)
            } else {
                result(FlutterError(code: "CREATION_ERROR", message: "Failed to create recognizer", details: nil))
            }

        case "recognizer.setMaxAlternatives":
            guard let args = call.arguments as? [String: Any],
                  let recognizerId = args["recognizerId"] as? Int,
                  let maxAlternatives = args["maxAlternatives"] as? Int else {
                result(FlutterError(code: "WRONG_ARGS", message: "Missing arguments", details: nil))
                return
            }
            if let recognizer = recognizersMap[recognizerId] {
                vosk_recognizer_set_max_alternatives(recognizer, Int32(maxAlternatives))
                result(nil)
            } else {
                result(FlutterError(code: "NO_RECOGNIZER", message: "Recognizer not found", details: nil))
            }

        case "recognizer.setWords":
            guard let args = call.arguments as? [String: Any],
                  let recognizerId = args["recognizerId"] as? Int,
                  let words = args["words"] as? Bool else {
                result(FlutterError(code: "WRONG_ARGS", message: "Missing arguments", details: nil))
                return
            }
            if let recognizer = recognizersMap[recognizerId] {
                vosk_recognizer_set_words(recognizer, words ? 1 : 0)
                result(nil)
            } else {
                result(FlutterError(code: "NO_RECOGNIZER", message: "Recognizer not found", details: nil))
            }

        case "recognizer.setPartialWords":
            result(nil)

        case "recognizer.acceptWaveform", "recognizer.acceptWaveForm":
            guard let args = call.arguments as? [String: Any],
                  let recognizerId = args["recognizerId"] as? Int else {
                result(FlutterError(code: "WRONG_ARGS", message: "Missing arguments", details: nil))
                return
            }

            guard let recognizer = recognizersMap[recognizerId] else {
                result(FlutterError(code: "NO_RECOGNIZER", message: "Recognizer not found", details: nil))
                return
            }

            if let bytes = args["bytes"] as? FlutterStandardTypedData {
                let data = bytes.data
                let length = Int32(data.count)
                let res = data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Int32 in
                    if let baseAddress = buffer.baseAddress {
                        let charPtr = baseAddress.assumingMemoryBound(to: CChar.self)
                        return vosk_recognizer_accept_waveform(recognizer, charPtr, length)
                    }
                    return -1
                }
                result(res == 1)
            } else {
                result(FlutterError(code: "WRONG_ARGS", message: "Data missing", details: nil))
            }

        case "recognizer.getResult":
            guard let args = call.arguments as? [String: Any],
                  let recognizerId = args["recognizerId"] as? Int,
                  let recognizer = recognizersMap[recognizerId] else {
                result(FlutterError(code: "NO_RECOGNIZER", message: "Recognizer not found", details: nil))
                return
            }
            result(vosk_recognizer_result(recognizer).map { String(cString: $0) } ?? "{}")

        case "recognizer.getPartialResult":
            guard let args = call.arguments as? [String: Any],
                  let recognizerId = args["recognizerId"] as? Int,
                  let recognizer = recognizersMap[recognizerId] else {
                result(FlutterError(code: "NO_RECOGNIZER", message: "Recognizer not found", details: nil))
                return
            }
            result(vosk_recognizer_partial_result(recognizer).map { String(cString: $0) } ?? "{\"partial\": \"\"}")

        case "recognizer.getFinalResult":
            guard let args = call.arguments as? [String: Any],
                  let recognizerId = args["recognizerId"] as? Int,
                  let recognizer = recognizersMap[recognizerId] else {
                result(FlutterError(code: "NO_RECOGNIZER", message: "Recognizer not found", details: nil))
                return
            }
            result(vosk_recognizer_final_result(recognizer).map { String(cString: $0) } ?? "{\"text\": \"\"}")

        case "recognizer.reset":
            guard let args = call.arguments as? [String: Any],
                  let recognizerId = args["recognizerId"] as? Int,
                  let recognizer = recognizersMap[recognizerId] else {
                result(FlutterError(code: "NO_RECOGNIZER", message: "Recognizer not found", details: nil))
                return
            }
            vosk_recognizer_reset(recognizer)
            result(nil)

        case "recognizer.close":
            guard let args = call.arguments as? [String: Any],
                  let recognizerId = args["recognizerId"] as? Int,
                  let recognizer = recognizersMap[recognizerId] else {
                result(nil)
                return
            }
            vosk_recognizer_free(recognizer)
            recognizersMap.removeValue(forKey: recognizerId)
            result(nil)

        case "speechService.init":
            guard let args = call.arguments as? [String: Any],
                  let recognizerId = args["recognizerId"] as? Int,
                  let sampleRate = args["sampleRate"] as? NSNumber else {
                result(FlutterError(code: "WRONG_ARGS", message: "Missing arguments", details: nil))
                return
            }

            guard let recognizer = recognizersMap[recognizerId] else {
                result(FlutterError(code: "NO_RECOGNIZER", message: "Recognizer not found", details: nil))
                return
            }

            if speechService != nil {
                result(FlutterError(code: "INITIALIZE_FAIL", message: "SpeechService already initialized", details: nil))
                return
            }

            speechService = SpeechService(
                recognizer: recognizer,
                sampleRate: sampleRate.doubleValue,
                resultHandler: resultHandler,
                partialHandler: partialHandler,
                errorHandler: errorHandler
            )
            result(nil)

        case "speechService.start":
            guard let service = speechService else {
                result(FlutterError(code: "NO_SPEECH_SERVICE", message: "SpeechService not created", details: nil))
                return
            }
            do {
                try service.start()
                result(true)
            } catch {
                result(FlutterError(code: "START_ERROR", message: error.localizedDescription, details: nil))
            }

        case "speechService.stop":
            guard let service = speechService else {
                result(FlutterError(code: "NO_SPEECH_SERVICE", message: "SpeechService not created", details: nil))
                return
            }
            service.stop()
            result(true)

        case "speechService.cancel":
            guard let service = speechService else {
                result(FlutterError(code: "NO_SPEECH_SERVICE", message: "SpeechService not created", details: nil))
                return
            }
            service.stop()
            result(true)

        case "speechService.destroy":
            speechService?.stop()
            speechService = nil
            result(nil)

        case "speechService.setPause":
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    deinit {
        for model in modelsMap.values {
            vosk_model_free(model)
        }
        for model in speakerModelsMap.values {
            vosk_spk_model_free(model)
        }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            NSLog("VOSK_DEBUG: AVAudioSession configured and active")
        } catch {
            NSLog("VOSK_DEBUG: Failed to configure AVAudioSession: \(error)")
        }
    }
}

class SpeechService {
    let recognizer: OpaquePointer
    let engine = AVAudioEngine()
    let inputNode: AVAudioInputNode
    let bus = 0
    let sampleRate: Double
    private let resultHandler: VoskEventHandler
    private let partialHandler: VoskEventHandler
    private let errorHandler: VoskEventHandler
    private var converter: AVAudioConverter?

    init(
        recognizer: OpaquePointer,
        sampleRate: Double,
        resultHandler: VoskEventHandler,
        partialHandler: VoskEventHandler,
        errorHandler: VoskEventHandler
    ) {
        self.recognizer = recognizer
        self.sampleRate = sampleRate
        self.resultHandler = resultHandler
        self.partialHandler = partialHandler
        self.errorHandler = errorHandler
        self.inputNode = engine.inputNode
    }

    func start() throws {
        let hardwareFormat = inputNode.outputFormat(forBus: bus)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: true
        ) else {
            throw NSError(domain: "VoskFlutter", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create target audio format"])
        }
        guard let audioConverter = AVAudioConverter(from: hardwareFormat, to: targetFormat) else {
            throw NSError(domain: "VoskFlutter", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create audio converter"])
        }
        converter = audioConverter

        inputNode.installTap(onBus: bus, bufferSize: 4096, format: hardwareFormat) { [weak self] (buffer, time) in
            guard let self = self, let converter = self.converter else { return }

            let ratio = self.sampleRate / hardwareFormat.sampleRate
            let outputCapacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * ratio)) + 1
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputCapacity) else { return }

            var inputConsumed = false
            var convError: NSError?
            converter.convert(to: outputBuffer, error: &convError) { _, outStatus in
                if inputConsumed {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                inputConsumed = true
                outStatus.pointee = .haveData
                return buffer
            }

            guard convError == nil, outputBuffer.frameLength > 0,
                  let channelData = outputBuffer.int16ChannelData else { return }

            let dataLen = Int32(outputBuffer.frameLength) * 2
            let ptr = channelData[0].withMemoryRebound(to: CChar.self, capacity: Int(dataLen)) { $0 }

            if vosk_recognizer_accept_waveform(self.recognizer, ptr, dataLen) == 1 {
                if let res = vosk_recognizer_result(self.recognizer) {
                    self.reportResult(String(cString: res))
                }
            } else {
                if let res = vosk_recognizer_partial_result(self.recognizer) {
                    self.reportPartial(String(cString: res))
                }
            }
        }

        try engine.start()
    }

    func stop() {
        engine.stop()
        inputNode.removeTap(onBus: bus)
        if let res = vosk_recognizer_final_result(recognizer) {
            reportResult(String(cString: res))
        }
    }

    private func reportResult(_ result: String) {
        DispatchQueue.main.async {
            self.resultHandler.sink?(result)
        }
    }

    private func reportPartial(_ result: String) {
        DispatchQueue.main.async {
            self.partialHandler.sink?(result)
        }
    }
}
