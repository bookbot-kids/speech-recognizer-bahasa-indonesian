//
//  sctest.swift
//  speech_recognizerTests
//
//  Created by admin on 30/7/22.
//

import XCTest
@testable import Runner

class RecognitionTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testRecognizerWithGrammar() throws {
      let sc = SpeechController()
//      sc.grammar = "[\"john mewakili kelasnya di perlombaan renang\"]"
      sc.grammar = "[\"seperti apa wawancara anda\"]"
      sc.sampleRate = 16000
      try sc.loadModel(language: "id")
      sc.instantiateRecognizer()
      let testBundle = Bundle(for: type(of:self))
      let url = testBundle.url(forResource:"sample_id", withExtension:".pcm") // already encoded as 16-bit PCM 16khz
      var data = try Data(contentsOf: url!)
        
      data.withUnsafeBytes { rawBufferPointer in
        let rawPtr = rawBufferPointer.bindMemory(to: Int16.self)
        let endOfSpeech = bookbot_recognizer_accept_waveform_s(sc.recognizer!,                rawPtr.baseAddress!, Int32(data.count / 2))
      }

    
      let res = bookbot_recognizer_result(sc.recognizer!)
      let resultString = String(validatingUTF8: res!)!
      sc.freeRecognizer()
      XCTAssertEqual(resultString, "{\n  \"text\" : \"seperti apa wawancara anda\"\n}")
      
    }
  
  func testRecognizerWithoutGrammar() throws {
    let sc = SpeechController()
    sc.sampleRate = 16000
    try sc.loadModel(language: "id")
    sc.instantiateRecognizer()
    let testBundle = Bundle(for: type(of:self))
    let url = testBundle.url(forResource:"sample_id", withExtension:".pcm") // already encoded as 16-bit PCM 16khz
    var data = try Data(contentsOf: url!)
      
    data.withUnsafeBytes { rawBufferPointer in
      let rawPtr = rawBufferPointer.bindMemory(to: Int16.self)
      let endOfSpeech = bookbot_recognizer_accept_waveform_s(sc.recognizer!,                rawPtr.baseAddress!, Int32(data.count / 2))
    }

  
    let res = bookbot_recognizer_result(sc.recognizer!)
    let resultString = String(validatingUTF8: res!)!
    sc.freeRecognizer()
    XCTAssertEqual(resultString, "{\n  \"text\" : \"seperti apa wawancara anda\"\n}")
    
  }



}
