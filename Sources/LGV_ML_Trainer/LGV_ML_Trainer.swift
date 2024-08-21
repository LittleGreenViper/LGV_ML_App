/*
 © Copyright 2024, Little Green Viper Software Development LLC
 LICENSE:
 
 MIT License
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
 modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

import Foundation
import SwiftBMLSDK

/* ###################################################################################################################################### */
// MARK: -  -
/* ###################################################################################################################################### */
/**
 */
struct LGV_ML_Trainer {
    /* ################################################################## */
    /**
     The Base URL for our meeting data server. This is an optional, but we allow it to be implicit, as the whole app is toast, if this is bad.
     */
    private static let _dataServerURIBase = URL(string: "https://meetings.recovrr.org/entrypoint.php")
    
    /* ################################################################## */
    /**
     This is the URL session that we will be using to communicate with the server.
     */
    private let _session = URLSession(configuration: .default)
    
    /* ################################################################## */
    /**
     */
    private let _query = SwiftBMLSDK_Query(serverBaseURI: _dataServerURIBase)

    /* ################################################# */
    /**
     */
    private func _fetchMeetings() async -> SwiftBMLSDK_Parser? {
        var ret: SwiftBMLSDK_Parser?
        
        var dun = false // Stupid semaphore.
        
        _query.meetingSearch(specification: SwiftBMLSDK_Query.SearchSpecification()){ inSearchResults, inError in
            guard nil == inError,
                  let inSearchResults = inSearchResults
            else {
                ret = inSearchResults
                dun = true
                return
            }
            
            ret = inSearchResults
            dun = true
        }
        
        while !dun { await Task.yield() }
        
        return ret
    }

    /* ################################################################## */
    /**
     Static initializer.
     */
    init() async {
        let parser = await _fetchMeetings()
    }
}

