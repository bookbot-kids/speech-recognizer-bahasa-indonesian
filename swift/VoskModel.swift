//
//  Vosk.swift
//  VoskApiTest
//
//  Created by Niсkolay Shmyrev on 01.03.20.
//  Copyright © 2020-2021 Alpha Cephei. All rights reserved.
//

import Foundation

enum VoskError: Error {
    case runtimeError(String)
}

public final class VoskModel {
    
    var model : OpaquePointer!
  
    var language:String
    
    init(language:String) throws {
        self.language = language
        var modelPath:String
        if(language == "en") {
            modelPath = "/model-en-us"
        } else if(language == "id") {
            modelPath = "/model-id-id"
        } else {
            throw VoskError.runtimeError("Unrecognized language string \(language)")
        }
        
        // Set to -1 to disable logs
        vosk_set_log_level(0);
        
        if let resourcePath = Bundle.main.resourcePath {
            model = vosk_model_new(resourcePath + modelPath)
        }
    }
    
    deinit {
        vosk_model_free(model)
    }
    
}

