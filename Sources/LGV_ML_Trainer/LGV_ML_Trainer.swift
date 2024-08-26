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
import TabularData

/* ###################################################################################################################################### */
// MARK: - ML Trainer for Meetings -
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
     This is our query instance, that we'll use to fetch the server data.
     */
    private let _query = SwiftBMLSDK_Query(serverBaseURI: _dataServerURIBase)

    /* ################################################# */
    /**
     This is an async function (but it might as well be synchronous, since nothing is to be done, until it's finished), that reads the entire meeting database, then turns it into ML-friendly JSON.
     
     - returns: A JSON Data instance, with the simplified and parsed meeting data, all tied up in a bow for ML.
     */
    private func _fetchMeetings() async -> Data? {
        var ret: Data?
        
        var dun = false // Stupid semaphore.
        
        _query.meetingSearch(specification: SwiftBMLSDK_Query.SearchSpecification()){ inSearchResults, inError in
            defer { dun = true }
            guard nil == inError,
                  let inSearchResults = inSearchResults
            else { return }
            
            ret = inSearchResults.meetings.asJSONData
        }
        
        while !dun { await Task.yield() }
        
        return ret
    }

    /* ################################################################## */
    /**
     Basic initializer.
     */
    init() async {
        guard let jsonData = await _fetchMeetings(),
              let data = try? DataFrame(jsonData: jsonData),
              let desktopDirectoryPathString = NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true).first,
              let desktopDirectoryPath = NSURL(string: desktopDirectoryPathString),
              let jsonFilePath = desktopDirectoryPath.appendingPathComponent("meetingData.json")
        else { return }
        
        try? FileManager.default.removeItem(at: jsonFilePath)
        FileManager.default.createFile(atPath: jsonFilePath.absoluteString, contents: jsonData)
        
        print(data)
    }
}
