/*
Copyright 2022 [PT BOOKBOT INDONESIA](https://bookbot.id/)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

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
    let mixer = AVAudioMixerNode()
    let maxLoopNodeVolume:Float = 0.65
    let minLoopNodeVolume:Float = 0.15
    var soundCache:[String: AVAudioPCMBuffer] = [:]
    var sound: AVAudioPCMBuffer?
    var soundChannels: UInt32 = 1
    var isPlayingSpeech = false
  
    var expectedSpeech: String?
    var grammar: String?
  
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
    var sampleRate:Float = 0
    var conversionFormat:AVAudioFormat? = nil

    var registrar: FlutterPluginRegistrar? = nil

    override init() {
        engine.attach(mixer)
        engine.connect(mixer, to: engine.outputNode, format: nil)

        let category = AVAudioSession.Category.playAndRecord;
        let options = AVAudioSession.CategoryOptions.defaultToSpeaker

        engine.prepare()

        do {
          try AVAudioSession.sharedInstance().setCategory(category, mode: .voiceChat, options: options)
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
      print(call.method)
      print(call.arguments ?? "")
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
          let startSpeech = arguments[1] ?? "" == "true"
          self.initSpeech(language:language, flutterResult: result, startSpeech: startSpeech)
        // The start of a book when it starts listening
        case "listen":
          self.startListening()
          result(nil)
        // The closing of a book and goiong back to the library
        case "stopListening":
          self.stopListening()
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
          let args = call.arguments as! Array<Any?>
          self.flushSpeech(toRead: args[0] as? String ?? "", grammar: args[1] as? String ?? "")
          result(nil)
      case "recognizeAudio":
          let args = call.arguments as! String
          self.recognizeAudio(assetPath: args, flutterResult: result)
        default:
          result(FlutterMethodNotImplemented)
    }
    }
    
    private func recognizeAudio(assetPath: String, flutterResult: @escaping FlutterResult) {
        let key = registrar?.lookupKey(forAsset: assetPath);
        guard let path = Bundle.main.path(forResource: key, ofType: nil) else {
            flutterResult(nil)
            return
        }
        
        if self.recognizer == nil {
            instantiateRecognizer()
        }
        guard let recognizer = self.recognizer else { return }
        
        self.processingQueue.async {
            guard let fileUrl = URL(string: path) else { return }
            let file = try! AVAudioFile(forReading: fileUrl)
            let processingFormat = file.processingFormat
            let bufferSizePerSecond = 0.2
            let sampleRate = 16000.0
            let bufferSize: AVAudioFrameCount = AVAudioFrameCount((sampleRate * bufferSizePerSecond).rounded())
            let buffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: bufferSize)!
            var list = [String]()
            
            while file.framePosition < file.length {
                let framesToRead = min(bufferSize, AVAudioFrameCount(file.length - file.framePosition))
                try! file.read(into: buffer, frameCount: framesToRead)

                let dataLen = Int(buffer.frameLength)
                guard let floatChannelData = buffer.floatChannelData else { return }
                
                var int16Data = [Int16](repeating: 0, count: dataLen)
                for channel in 0..<buffer.format.channelCount {
                    for i in 0..<dataLen {
                        let sample = floatChannelData[Int(channel)][i]
                        int16Data[i] = Int16(sample * Float(Int16.max))
                    }
                }

                int16Data.withUnsafeBufferPointer { ptr in
                    let endOfSpeech = bookbot_recognizer_accept_waveform_s(recognizer, ptr.baseAddress!, Int32(dataLen))
                    let res = endOfSpeech == 1 ? bookbot_recognizer_result(self.recognizer!) : bookbot_recognizer_partial_result(self.recognizer)
                    let resultString = String(validatingUTF8: res!)!
                    let json = resultString.convertToDictionary()!
                    let text = json["partial"]
                    print("recognize text \(resultString)")
                    list.append(resultString)
                }
            }
            
            DispatchQueue.main.async {
                flutterResult(list)
            }
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

    func freeRecognizer() {
        if(recognizer != nil) {
          bookbot_recognizer_free(recognizer);
          recognizer = nil;
        }
    }

    func instantiateRecognizer()  {
        guard let m = model else {
          print("Model not loaded")
          return
        }
      if(grammar == nil || grammar!.isEmpty) {
        recognizer = bookbot_recognizer_new(m.model, self.sampleRate)
      } else {
        do {
          recognizer = bookbot_recognizer_new_grm(m.model, self.sampleRate, self.grammar)
          print("Created recognizer with grammar")
        } catch {
          print("Error generating grammar for recognizer")
        }
      }
     
        bookbot_recognizer_set_max_alternatives(recognizer, 5)
    }
  
    
   
  public func loadModel(language:String) throws {
    self.model = try VoskModel(language: language)
  }

    /// Speech initialiser
    public func initSpeech(language:String, flutterResult: @escaping FlutterResult, startSpeech: Bool) {
        engine.stop()

        // Raw format is the format of the bus - but we need to do conversion for the input format for both Kaldi and the recorder
        let rawFormat = engine.inputNode.inputFormat(forBus: 0)
        inputFormat = AVAudioFormat.init(commonFormat: AVAudioCommonFormat.pcmFormatInt16, sampleRate: rawFormat.sampleRate, channels: 1, interleaved: false)!
      sampleRate = Float(inputFormat!.sampleRate)
        conversionFormat = AVAudioFormat.init(commonFormat: AVAudioCommonFormat.pcmFormatInt16, sampleRate: 32000, channels: 1, interleaved: false)!

        self.processingQueue.async {

          if(self.model == nil || self.model!.language != language) {
            do {
              try self.loadModel(language: language)
            } catch {
              flutterResult(FlutterError(code: "speechError", message: "initSpeech error", details: error))
              return
            }
          }

        }
        
        if startSpeech {
            // Prepare audio buffer converter
            let formatConverter = AVAudioConverter(from: inputFormat!, to: conversionFormat!)!
            formatConverter.sampleRateConverterAlgorithm = AVSampleRateConverterAlgorithm_Normal
            formatConverter.sampleRateConverterQuality = .max
            let sampleRateRatio = inputFormat!.sampleRate / conversionFormat!.sampleRate


            engine.inputNode.removeTap(onBus: 0)
            engine.inputNode.installTap(onBus: 0, bufferSize: UInt32(rawFormat.sampleRate / 10), format: inputFormat!) { buffer, _ in
                // add one check to prevent tasks from being added to the queue in the first place unnecessarily
                guard self.listen, !self.isPlayingSpeech, self.recognizer != nil else {
                  return
                }
                self.processingQueue.async {
                    // add a second check to discard this task if needed immediately after being dequeued
                    guard self.listen, !self.isPlayingSpeech, self.recognizer != nil else {
                      return
                    }

                    let dataLen = Int(buffer.frameLength)
                    let channels = UnsafeBufferPointer(start: buffer.int16ChannelData, count: 1)
                    let endOfSpeech = channels[0].withMemoryRebound(to: Int16.self, capacity: dataLen) {
                      bookbot_recognizer_accept_waveform_s(self.recognizer!, $0, Int32(dataLen))
                    }
                    let res = endOfSpeech == 1 ? bookbot_recognizer_result(self.recognizer!) : bookbot_recognizer_partial_result(self.recognizer)
                    let resultString = String(validatingUTF8: res!)!
    //                print(resultString)
                    DispatchQueue.main.async {
                        self.eventSink?([resultString, endOfSpeech == 1])
                    }
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
        }

        
        
        flutterResult(nil)
    }


    public func startListening() {
        self.listen = true
    }

    public func stopListening() {
        self.listen = false
        DispatchQueue.main.async {
          self.timer?.invalidate()
        }
    }
    
    ///
    /// The [expectedSpeech] is distinct from [grammar] because the former should be used as the audio clip recording transcript, whereas the latter needs to be for the speech recognition model.
    /// For example, if we expect the word "cat", then [expectedSpeech] is set to "cat" but [grammar] needs to be set to [cat, mat, sat] etc.
    /// Otherwise, the recognizer will only ever return the word "cat", no matter what was said.
    ///
    public func flushSpeech(toRead: String, grammar:String) {
        self.expectedSpeech = toRead
        
        // will immediately stop pushing audio into the recognizer
        self.stopListening()
      
        self.grammar = grammar;

        // we have to submit a task to the queue to destroy/recreate the recognizer
        // otherwise this will not be thread-safe and one thread may try to destroy the recognizer while another thread is mid-way through processing an audio segment
        self.processingQueue.async {
            self.stopListening()
            self.freeRecognizer()

            self.instantiateRecognizer()
            DispatchQueue.main.async {
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                // print("Timer called")
                  self.startListening()
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

extension String {
    func convertToDictionary() -> [String: Any]? {
        if let data = data(using: .utf8) {
            return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        }
        return nil
    }
}

