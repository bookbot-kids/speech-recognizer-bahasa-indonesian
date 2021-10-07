#if os(iOS)
  import Flutter
#elseif os(macOS)
  import FlutterMacOS
#endif

import Foundation
import AVFoundation

extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

class SpeechController: NSObject, FlutterStreamHandler, FlutterPlugin {
    public var eventSink: FlutterEventSink?

    let engine = AVAudioEngine()

    //
    // Audio playback properties
    //
    let mixer = AVAudioMixerNode()
    let soundNode = AVAudioPlayerNode()
    let speechNode = AVAudioPlayerNode()
    let loopNode = AVAudioPlayerNode()

    let maxLoopNodeVolume:Float = 0.65
    let minLoopNodeVolume:Float = 0.15
    var soundCache:[String: AVAudioPCMBuffer] = [:]
    var sound: AVAudioPCMBuffer?
    var soundChannels: UInt32 = 1
    var isPlayingSpeech = false
  
    //
    // Speech recognition properties
    //
    var processingQueue: DispatchQueue! = DispatchQueue(label: "recognizerQueue", qos: DispatchQoS.userInteractive)
    var model : VoskModel?
    var recognizer : OpaquePointer?
    // When listen is false, audio buffers will not be sent to the recogniser
    var listen = true;
    // a timer to reset the speech recognizer if a certain amount of time has elapsed and this has not been automatically reinstated
    var timer:Timer? = nil

    var inputFormat:AVAudioFormat? = nil
    var conversionFormat:AVAudioFormat? = nil

    var registrar: FlutterPluginRegistrar? = nil

    override init() {
        engine.attach(mixer)
        engine.connect(mixer, to: engine.outputNode, format: nil)

        // Add the sound effects and looping node players
        engine.attach(soundNode)
        engine.connect(soundNode, to: mixer, format: nil)
        let format32KHzMono = AVAudioFormat.init(standardFormatWithSampleRate: 32000, channels: 1)
        engine.attach(speechNode)
        engine.connect(speechNode, to: mixer, format: format32KHzMono)
        engine.attach(loopNode)
        engine.connect(loopNode, to: mixer, format: nil)

        let category = AVAudioSession.Category.playAndRecord;
        let options = AVAudioSession.CategoryOptions.defaultToSpeaker

        engine.prepare()

        do {
          try AVAudioSession.sharedInstance().setCategory(category, options:options)
          try engine.start()
        } catch {
          print("Initialization error")
        }
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        #if os(iOS)
        let messenger = registrar.messenger()
        #elseif os(macOS)
        let messenger = registrar.messenger
        #endif

        let channel = FlutterMethodChannel(
         name: "com.bookbot/control",
            binaryMessenger: messenger)


        let instance = SpeechController()
        instance.registrar = registrar
        registrar.addMethodCallDelegate(instance, channel: channel)

        let eventChannel = FlutterEventChannel(name: "com.bookbot/event", binaryMessenger: messenger)
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    //      print(call.method)
    //      print(call.arguments ?? "")
      // Handle incoming messages from Flutter
      switch call.method {
        case "audioPermission":
          self.audioPermission(flutterResult: result)
        case "authorize":
          self.authorize(flutterResult: result)
        // Needed for speech, after authorization or start of book
        case "initSpeech":
            let arguments = call.arguments as! [String?]
            let language = arguments[0]!
            self.initSpeech(language:language, flutterResult: result)
        // The start of a book when it starts listening
        case "listen":
          self.startSpeech()
          result(nil)
        // The closing of a book and goiong back to the library
        case "stopListening":
          self.listen = false
          self.stopSpeech()
          result(nil)
        // Mute microphone. Will be muted and unmuted from other actions
        case "mute":
          self.listen = false
          result(nil)
        // Unmute the microphone
        case "unmute":
          self.listen = true
          result(nil)
        // Final process of speech - for when page is turned or text line is touched
        case "flushSpeech":
          self.flushSpeech(toRead: call.arguments as? String ?? "")
          result(nil)
        case "cacheSounds":
          self.cacheSounds(flutterResult: result)
        case "playSound":
          guard let arguments = call.arguments as? [String], let path = arguments[safe:0], let start = Double(arguments[1]), let end = Double(arguments[2]) else {
            result(nil)
            return
          }
          self.play(path: path, from: start, to: end, flutterResult: result)
          result(nil)
        case "endSpeechSound":
          // Fade out the speech node
          self.fadeout(node: speechNode, pause: false, flutterResult: result)
          result(nil)
        case "playLoop":
          self.playLoop(path: call.arguments as! String, flutterResult: result)
        case "endLoop":
          self.fadeout(node: loopNode, pause: true, flutterResult: result)
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
    }
    }

    public func audioPermission(flutterResult: @escaping FlutterResult) {
        #if os(iOS)
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
          flutterResult("authorized")
        case .denied:
          flutterResult("denied")
        case .undetermined:
          flutterResult("undetermined")
        default:
          flutterResult(FlutterError(code: "audioPermissionError", message: "Unknown Audio Error", details: ""))
        }
        #elseif os(macOS)
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
          isAudioRecordingGranted = true
          flutterResult("authorized")
        case .denied:
          flutterResult("denied")
        case .notDetermined:
          flutterResult("undetermined")
        case .restricted:
          flutterResult(FlutterError(code: "audioPermissionError", message: "Restricted Audio Error", details: ""))
        default:
          flutterResult(FlutterError(code: "audioPermissionError", message: "Unknown Audio Error", details: ""))
        }
        #endif
    }

    public func authorize(flutterResult: @escaping FlutterResult) {
        #if os(iOS)
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
          //OperationQueue.main.addOperation {
            flutterResult(granted)
          //}
        }
        #elseif os(macOS)
        AVCaptureDevice.requestAccess(for: .audio) { granted in
          //OperationQueue.main.addOperation {
            flutterResult(granted)
          //}
        }
        #endif
    }

    func _freeRecognizer() {
        if(recognizer != nil) {
          vosk_recognizer_free(recognizer);
          recognizer = nil;
        }
    }

    func _instantiateRecognizer() {
        guard let m = model, let input = inputFormat else {
            return
        }

        recognizer = vosk_recognizer_new(m.model, Float(input.sampleRate))
    }

    /// Speech initialiser
    public func initSpeech(language:String, flutterResult: @escaping FlutterResult) {
        engine.stop()

        // Raw format is the format of the bus - but we need to do conversion for the input format for both Kaldi and the recorder
        let rawFormat = engine.inputNode.inputFormat(forBus: 0)
        inputFormat = AVAudioFormat.init(commonFormat: AVAudioCommonFormat.pcmFormatInt16, sampleRate: rawFormat.sampleRate, channels: 1, interleaved: false)!
        conversionFormat = AVAudioFormat.init(commonFormat: AVAudioCommonFormat.pcmFormatInt16, sampleRate: 32000, channels: 1, interleaved: false)!

        self.processingQueue.async {
          self._freeRecognizer()
          
          if(self.model == nil || self.model!.language != language) {
            do {
              self.model = try VoskModel(language: language)
            } catch {
              flutterResult(FlutterError(code: "speechError", message: "initSpeech error", details: error))
              return
            }
          }
            
          self._instantiateRecognizer()
        }

        // Prepare audio buffer converter
        let formatConverter = AVAudioConverter(from: inputFormat!, to: conversionFormat!)!
        formatConverter.sampleRateConverterAlgorithm = AVSampleRateConverterAlgorithm_Normal
        formatConverter.sampleRateConverterQuality = .max

        engine.inputNode.removeTap(onBus: 0)
        engine.inputNode.installTap(onBus: 0, bufferSize: UInt32(rawFormat.sampleRate / 10), format: inputFormat!) { buffer, _ in
            self.processingQueue.async {
                guard self.listen, !self.isPlayingSpeech, self.recognizer != nil else {
                  return
                }

                let dataLen = Int(buffer.frameLength)
                let channels = UnsafeBufferPointer(start: buffer.int16ChannelData, count: 1)
                let endOfSpeech = channels[0].withMemoryRebound(to: Int8.self, capacity: dataLen * 2) {
                  vosk_recognizer_accept_waveform(self.recognizer!, $0, Int32(dataLen))
                }
                let res = endOfSpeech == 1 ? vosk_recognizer_result(self.recognizer!) :vosk_recognizer_partial_result(self.recognizer)
                let resultString = String(validatingUTF8: res!)!
                self.eventSink?(resultString)
                print("recognize \(resultString)")
            }
        }
        
        engine.prepare()
        
        do {
          try engine.start()
        }
        catch {
          flutterResult(FlutterError(code: "audioError", message: "audioError", details: error.localizedDescription))
          return
        }
        
        flutterResult(nil)
    }

    public func startSpeech() {
        self.processingQueue.async {
          self.listen = true
        }
    }

    public func stopSpeech() {
        DispatchQueue.main.async {
          self.timer?.invalidate()
        }
        self.processingQueue.async {
          self.listen = false
        }
    }

    public func flushSpeech(toRead: String) {
        self.processingQueue.async {
            self.stopSpeech()
            // print("Stopped")
            self._freeRecognizer()
            // print("Freed")
            self._instantiateRecognizer()
            // print("Instantiated")
            DispatchQueue.main.async {
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                // print("Timer called")
                  self.processingQueue.async {
                    self.startSpeech()
                    // print("Started speech")
                  }
                }
            }
        }
    }


    public func cacheSounds(flutterResult: FlutterResult) {
        let sounds = Bundle.main.urls(forResourcesWithExtension: "m4a", subdirectory: nil)!

        // Find all m4a assets that are prefixed with _, and cache these
        for sound in sounds {
          let file = sound.lastPathComponent
          if file.starts(with: "_") {
            let fileName = String(file.split(separator: ".").first!)
            let file = try! AVAudioFile(forReading: sound)
            let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
            try! file.read(into: buffer)
            soundCache[fileName] = buffer
          }
        }
        flutterResult(nil)
    }

    //
    // TODO - this really should be treated as 100% async and submitted via a DispatchQueue
    // to avoid future concurrency/deadlock issues with async callbacks executing when Flutter tries to send another request via a platform channel.
    // However, currently the timing of various other things (e.g. animation triggers) is tied to the assumption that audio has started playing as soon as
    // this method returns (this is another TODO that could be fixed).
    // For now, we will just ensure that all callbacks (mostly fading things out/in) are dispatched.
    // Theoretically this still exposes the risk of deadlock but the window for this to occur is so small, I think the risk is minimal.
    //
    public func play(path: String, from: Double, to: Double, flutterResult: @escaping FlutterResult) {
      if(!self.engine.isRunning) {
        do {
          try engine.start()
        }
        catch {
          flutterResult(FlutterError(code: "audioError", message: "audioError", details: error.localizedDescription))
        }
      }
         
        let filePath = path.replacingOccurrences(of: "%", with:"%25")
        let key = self.registrar!.lookupKey(forAsset:filePath);
        // print("Trying to play asset at \(filePath) under key \(key)")
        guard let audioPath = Bundle.main.path(forResource: key, ofType: nil) else {
            print("Couldn't find audio asset @ \(filePath)")
            flutterResult(FlutterError(code: "asset_not_found", message: "Could not locate asset.", details: filePath))
            return;
        }

        // print("Audio path is \(audioPath)")
        playSound(audioPath: audioPath, from: from, to: to, flutterResult: flutterResult)
    }

    private func playSound(audioPath: String, from: Double, to: Double, flutterResult: @escaping FlutterResult) {
        guard let audioUrl = URL.init(string: audioPath.replacingOccurrences(of: "%", with:"%25")) else {
            flutterResult(FlutterError(code: "asset_not_found", message: "Could not locate asset.", details: audioPath))
            return;
        }
        
        // print("Audio url is \(audioUrl)")
        
        // Guard to see if audio file can be loaded
        guard let file = try? AVAudioFile(forReading: audioUrl) else {
          return flutterResult(nil)
        }

        let soundChannels = file.processingFormat.channelCount
        let node = soundChannels == 1 ? self.speechNode : self.soundNode
        self.partialFadeLoopOut()
        node.stop()

        self.isPlayingSpeech = true

        if from == 0.0 && to == 0.0 {
          node.scheduleFile(file, at: nil,
                        completionCallbackType: AVAudioPlayerNodeCompletionCallbackType.dataConsumed,
                        completionHandler:{ (type:AVAudioPlayerNodeCompletionCallbackType) -> Void in
                                  DispatchQueue.main.async {
                                      self.partialFadeLoopIn()
                                      self.isPlayingSpeech = false
                                      // print("Stopped")
                                  }
                              })
         
        } else {
            let sampleRate = node.outputFormat(forBus: 0).sampleRate
            let framePosition = AVAudioFramePosition(from * sampleRate)
            let frames = to == 0.0 ? Double(file.length) : to * sampleRate
            let frameCount = frames - (from * sampleRate)
            guard frameCount > 0 else {
                return flutterResult(nil)
            }
              
            node.scheduleSegment(file, startingFrame: framePosition, frameCount: AVAudioFrameCount(frameCount), at: nil,
                                     completionCallbackType: AVAudioPlayerNodeCompletionCallbackType.dataConsumed,
                                     completionHandler:{ (type:AVAudioPlayerNodeCompletionCallbackType) -> Void in
                                        DispatchQueue.main.async {
                                            self.partialFadeLoopIn()
                                            self.isPlayingSpeech = false
                                            // print("Stopped")
                                        }
                                     })
            }
        
        node.play()
        flutterResult(nil)
    }

    public func playLoop(path: String, flutterResult: @escaping FlutterResult) {

        guard engine.isRunning else {
            flutterResult(FlutterError(code: "engine_not_running", message: "Engine has not yet been initialized.", details:nil))
            return;
        }

          let key = self.registrar!.lookupKey(forAsset:path);

          let audioPath = Bundle.main.path(forResource: key, ofType: nil);

          if(audioPath == nil) {
              flutterResult(FlutterError(code: "asset_not_found", message: "Could not locate asset.", details: path))
              return;
          }

          let audioUrl = URL.init(string: audioPath!);

          if(audioUrl == nil) {
              flutterResult(FlutterError(code: "asset_not_found", message: "Could not locate asset.", details: path))
              return;
          }

          let audioFile = try! AVAudioFile(forReading: audioUrl!)
          self.scheduleNextLoop(audioFile: audioFile)
          self.loopNode.volume = self.minLoopNodeVolume

          self.loopNode.play()
          self.partialFadeLoopIn()
          flutterResult(nil)

    }

    public func partialFadeLoopOut() {
        let partial = self.loopNode.volume / 10;

        if(self.loopNode.volume >= self.minLoopNodeVolume) {
          self.loopNode.volume -= partial

          if(self.loopNode.volume >= self.minLoopNodeVolume) {
            DispatchQueue.main.asyncAfter(deadline:.now() + 0.03) {
              self.partialFadeLoopOut()
            }
        }
        }
    }

    public func partialFadeLoopIn() {
        let partial = self.loopNode.volume / 10;
        // 30 ms
        if(self.loopNode.volume <= self.maxLoopNodeVolume) {
            self.loopNode.volume += partial

            if(self.loopNode.volume <= self.maxLoopNodeVolume) {
              DispatchQueue.main.asyncAfter(deadline:.now() + 0.03) {
                self.partialFadeLoopIn()
              }
            }
        }
    }

    func scheduleNextLoop(audioFile: AVAudioFile) {
        loopNode.scheduleFile(audioFile, at: nil) {
          DispatchQueue.main.asyncAfter(deadline:.now() + 4.0) {
            self.scheduleNextLoop(audioFile: audioFile)
          }
        }
    }

    func fadeout(node: AVAudioPlayerNode, pause: Bool = false, flutterResult: @escaping FlutterResult) {
        fadeout(node: node, pause: pause)
        flutterResult(nil)
    }

    func fadeout(node: AVAudioPlayerNode, pause: Bool = false) {
        let volume = node.volume
        // print("fadeout current volume \(volume)")
        let partial = node.volume / 10;
        for _ in 1...10 {
            // 30 ms
            usleep(30000)
            node.volume -= partial
        }

        node.volume = 0
        if pause {
          node.pause()
        } else {
          node.stop()
        }

        // revert to old volume
        node.volume = volume
    }

    /// eventSink is where to send events back to Flutter
    public func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink
        return nil
    }

    /// Cleanup
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}



