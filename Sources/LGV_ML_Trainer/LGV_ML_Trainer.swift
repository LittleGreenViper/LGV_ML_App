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
import CoreLocation
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
     */
    private func _fetchMeetings() async -> (ids: [UInt64], descriptions: [String], jsonData: Data?)? {
        var ret: (ids: [UInt64], descriptions: [String], jsonData: Data?)?
        
        var dun = false // Stupid semaphore.
        
        _query.meetingSearch(specification: SwiftBMLSDK_Query.SearchSpecification()){ inSearchResults, inError in
            defer { dun = true }
            guard nil == inError,
                  let inSearchResults = inSearchResults
            else { return }
            
            let ids: [UInt64] = inSearchResults.meetings.map { $0.id }
            let descriptions: [String] = inSearchResults.meetings.map { $0.descriptionString }
            
            guard ids.count == descriptions.count else { return }
            
            ret = (ids: ids, descriptions: descriptions, jsonData: inSearchResults.meetings.asJSONData)
        }
        
        while !dun { await Task.yield() }
        
        return ret
    }

    /* ################################################################## */
    /**
     Basic initializer.
     */
    init() async {
        guard let csvData = await _fetchMeetings() else { return }
        
        let simpleDataFrame: DataFrame = ["id": csvData.ids, "description": csvData.descriptions]
        saveDataFrameToDesktopFile(simpleDataFrame)
        
        if let jsonData = csvData.jsonData,
           let jsonDataFrame = try? DataFrame(jsonData: jsonData),
           let jsonFileURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.appendingPathComponent("meetingData.json") {
            try? FileManager.default.removeItem(at: jsonFileURL)
            FileManager.default.createFile(atPath: jsonFileURL.relativePath, contents: jsonData)
            print(jsonDataFrame)
            print(simpleDataFrame)
        }
    }
    
    /* ################################################################## */
    /**
     Saves the data as a CSV file, for checking and debugging.
     */
    func saveDataFrameToDesktopFile(_ inDataFrame: DataFrame) {
        guard let desktopDirectoryPath = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first else { return }
        do {
            let filePath = desktopDirectoryPath.appendingPathComponent("meetingData.csv")
            try inDataFrame.writeCSV(to: filePath)
        } catch {
             print(error)
        }
    }
}

/* ###################################################################################################################################### */
// MARK: - Meeting Extensions -
/* ###################################################################################################################################### */
/**
 This extension adds some basic interpretation methods to the base class.
 */
extension SwiftBMLSDK_Parser.Meeting {
    /* ############################################# */
    /**
     This returns a natural-language, English description of the meeting (used for ML stuff).
     */
    public var descriptionString: String {
        var descriptionString = "\"\(name)\" is " +
                                (.hybrid == meetingType ? "a hybrid" : .virtual == meetingType ? "a virtual" : "an in-person") + " \((.na == organization ? "NA" : "Unknown")) meeting"
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let weekdayString = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        descriptionString += ", that meets every \(weekdayString[weekday - 1]), at \(formatter.string(from: startTime)), and lasts for \(Int(duration / 60)) minutes."
        
        let timeZoneString = timeZone.localizedName(for: .standard, locale: .current) ?? ""
        
        if !timeZoneString.isEmpty {
            descriptionString += "\nIts time zone is \(timeZoneString)."
        }
        
        let addressString = basicInPersonAddress
        
        if !addressString.isEmpty {
            descriptionString += "\nIt meets at \(addressString.replacingOccurrences(of: "\n", with: ", "))."
        }
        
        if let inPersonExtraInfo = locationInfo,
           !inPersonExtraInfo.isEmpty {
            descriptionString += "\n\(inPersonExtraInfo)"
        }

        if let coords = coords,
           CLLocationCoordinate2DIsValid(coords) {
            let lat = (coords.latitude * 100000).rounded(.toNearestOrEven) / 100000
            let lng = (coords.longitude * 100000).rounded(.toNearestOrEven) / 100000
            descriptionString += "\nIts latitude/longitude is \(lat), \(lng)."
        }
        
        if let virtualURL = virtualURL {
            descriptionString += "\nThe virtual URL is \(virtualURL.absoluteString) ."
        }
        
        if let virtualPhoneNumber = virtualPhoneNumber {
            descriptionString += "\nThe virtual phone number is \(virtualPhoneNumber) ."
        }
        
        if let virtualInfo = virtualInfo,
           !virtualInfo.isEmpty {
            descriptionString += "\n\(virtualInfo)"
        }
        
        if let comments = comments,
           !comments.isEmpty {
            descriptionString += "\n\(comments)"
        }

        formats.forEach {
            let formatString = $0.description
            if !formatString.isEmpty {
                descriptionString += "\n\(formatString)"
            }
        }
        
        return descriptionString
    }
}
