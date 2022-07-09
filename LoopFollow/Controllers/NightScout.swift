//
//  NightScout.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/16/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit


extension MainViewController {

    
    //NS Cage Struct
    struct cageData: Codable {
        var created_at: String
    }
    
    //NS Basal Profile Struct
    struct basalProfileStruct: Codable {
        var value: Double
        var time: String
        var timeAsSeconds: Double
    }
    
    //NS Basal Data  Struct
    struct basalGraphStruct: Codable {
        var basalRate: Double
        var date: TimeInterval
    }
    
    //NS Bolus Data  Struct
    struct bolusGraphStruct: Codable {
        var value: Double
        var date: TimeInterval
        var sgv: Int
    }
    
    //NS Bolus Data  Struct
    struct carbGraphStruct: Codable {
        var value: Double
        var date: TimeInterval
        var sgv: Int
        var absorptionTime: Int
    }
    
    func isStaleData() -> Bool {
        if bgData.count > 0 {
            let now = dateTimeUtils.getNowTimeIntervalUTC()
            let lastReadingTime = bgData.last!.date
            let secondsAgo = now - lastReadingTime
            if secondsAgo >= 20*60 {
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    }
    
    
    // Dex Share Web Call
    func webLoadDexShare(onlyPullLastRecord: Bool = false) {
        // Dexcom Share only returns 24 hrs of data as of now
        // Requesting more just for consistency with NS
        let graphHours = 24 * UserDefaultsRepository.downloadDays.value
        var count = graphHours * 12
        if onlyPullLastRecord { count = 1 }
        dexShare?.fetchData(count) { (err, result) -> () in
            
            // TODO: add error checking
            if(err == nil) {
                var data = result!
                
                // If Dex data is old, load from NS instead
                let latestDate = data[0].date
                let now = dateTimeUtils.getNowTimeIntervalUTC()
                if (latestDate + 330) < now && UserDefaultsRepository.url.value != "" {
                    self.webLoadNSBGData(onlyPullLastRecord: onlyPullLastRecord)
                    print("dex didn't load, triggered NS attempt")
                    return
                }
                
                // Dexcom only returns 24 hrs of data. If we need more, call NS.
                if graphHours > 24 && !onlyPullLastRecord && UserDefaultsRepository.url.value != "" {
                    self.webLoadNSBGData(onlyPullLastRecord: onlyPullLastRecord, dexData: data)
                } else {
                    self.ProcessDexBGData(data: data, onlyPullLastRecord: onlyPullLastRecord, sourceName: "Dexcom")
                }
            } else {
                // If we get an error, immediately try to pull NS BG Data
                if UserDefaultsRepository.url.value != "" {
                    self.webLoadNSBGData(onlyPullLastRecord: onlyPullLastRecord)
                }
                
                if globalVariables.dexVerifiedAlert < dateTimeUtils.getNowTimeIntervalUTC() + 300 {
                    globalVariables.dexVerifiedAlert = dateTimeUtils.getNowTimeIntervalUTC()
                    DispatchQueue.main.async {
                        //self.sendNotification(title: "Dexcom Share Error", body: "Please double check user name and password, internet connection, and sharing status.")
                    }
                }
            }
        }
    }
    
    // NS BG Data Web call
    func webLoadNSBGData(onlyPullLastRecord: Bool = false, dexData: [ShareGlucoseData] = []) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Download: BG") }
        
        // This kicks it out in the instance where dexcom fails but they aren't using NS &&
        if UserDefaultsRepository.url.value == "" {
            self.startBGTimer(time: 10)
            return
        }
        let graphHours = 24 * UserDefaultsRepository.downloadDays.value
        // Set the count= in the url either to pull day(s) of data or only the last record
        var points = "1"
        if !onlyPullLastRecord {
            points = String(graphHours * 12 + 1)
        }
        
        // URL processor
        var urlBGDataPath: String = UserDefaultsRepository.url.value + "/api/v1/entries/sgv.json?"
        if token == "" {
            urlBGDataPath = urlBGDataPath + "count=" + points
        } else {
            urlBGDataPath = urlBGDataPath + "token=" + token + "&count=" + points
        }
        guard let urlBGData = URL(string: urlBGDataPath) else {
            // if we have Dex data, use it
            if !dexData.isEmpty {
                self.ProcessDexBGData(data: dexData, onlyPullLastRecord: onlyPullLastRecord, sourceName: "Dexcom")
                return
            }
            
            if globalVariables.nsVerifiedAlert < dateTimeUtils.getNowTimeIntervalUTC() + 300 {
                globalVariables.nsVerifiedAlert = dateTimeUtils.getNowTimeIntervalUTC()
                //self.sendNotification(title: "Nightscout Error", body: "Please double check url, token, and internet connection. This may also indicate a temporary Nightscout issue")
            }
            DispatchQueue.main.async {
                if self.bgTimer.isValid {
                    self.bgTimer.invalidate()
                }
                self.startBGTimer(time: 10)
            }
            return
        }
        var request = URLRequest(url: urlBGData)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        
        // Downloader
        let getBGTask = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                if globalVariables.nsVerifiedAlert < dateTimeUtils.getNowTimeIntervalUTC() + 300 {
                    globalVariables.nsVerifiedAlert = dateTimeUtils.getNowTimeIntervalUTC()
                    //self.sendNotification(title: "Nightscout Error", body: "Please double check url, token, and internet connection. This may also indicate a temporary Nightscout issue")
                }
                DispatchQueue.main.async {
                    if self.bgTimer.isValid {
                        self.bgTimer.invalidate()
                    }
                    self.startBGTimer(time: 10)
                }
                // if we have Dex data, use it
                if !dexData.isEmpty {
                    self.ProcessDexBGData(data: dexData, onlyPullLastRecord: onlyPullLastRecord, sourceName: "Dexcom")
                }
                return
                
            }
            guard let data = data else {
                if globalVariables.nsVerifiedAlert < dateTimeUtils.getNowTimeIntervalUTC() + 300 {
                    globalVariables.nsVerifiedAlert = dateTimeUtils.getNowTimeIntervalUTC()
                    //self.sendNotification(title: "Nightscout Error", body: "Please double check url, token, and internet connection. This may also indicate a temporary Nightscout issue")
                }
                DispatchQueue.main.async {
                    if self.bgTimer.isValid {
                        self.bgTimer.invalidate()
                    }
                    self.startBGTimer(time: 10)
                }
                return
                
            }
            
            let decoder = JSONDecoder()
            let entriesResponse = try? decoder.decode([ShareGlucoseData].self, from: data)
            if var nsData = entriesResponse {
                DispatchQueue.main.async {
                    // transform NS data to look like Dex data
                    for i in 0..<nsData.count {
                        // convert the NS timestamp to seconds instead of milliseconds
                        nsData[i].date /= 1000
                        nsData[i].date.round(FloatingPointRoundingRule.toNearestOrEven)
                    }
                    
                    // merge NS and Dex data if needed; use recent Dex data and older NS data
                    var sourceName = "Nightscout"
                    if !dexData.isEmpty {
                        let oldestDexDate = dexData[dexData.count - 1].date
                        var itemsToRemove = 0
                        while itemsToRemove < nsData.count && nsData[itemsToRemove].date >= oldestDexDate {
                            itemsToRemove += 1
                        }
                        nsData.removeFirst(itemsToRemove)
                        nsData = dexData + nsData
                        sourceName = "Dexcom"
                    }
                    
                    // trigger the processor for the data after downloading.
                    self.ProcessDexBGData(data: nsData, onlyPullLastRecord: onlyPullLastRecord, sourceName: sourceName)
                    
                }
            } else {
                if globalVariables.nsVerifiedAlert < dateTimeUtils.getNowTimeIntervalUTC() + 300 {
                    globalVariables.nsVerifiedAlert = dateTimeUtils.getNowTimeIntervalUTC()
                    //self.sendNotification(title: "Nightscout Failure", body: "Please double check url, token, and internet connection. This may also indicate a temporary Nightscout issue")
                }
                DispatchQueue.main.async {
                    if self.bgTimer.isValid {
                        self.bgTimer.invalidate()
                    }
                    self.startBGTimer(time: 10)
                }
                return
                
            }
        }
        getBGTask.resume()
    }
    
    // Dexcom BG Data Response processor
    func ProcessDexBGData(data: [ShareGlucoseData], onlyPullLastRecord: Bool, sourceName: String){
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: BG") }
        
        let graphHours = 24 * UserDefaultsRepository.downloadDays.value
        
        let pullDate = data[data.count - 1].date
        let latestDate = data[0].date
        let now = dateTimeUtils.getNowTimeIntervalUTC()
        
        // Start the BG timer based on the reading
        let secondsAgo = now - latestDate
        
        DispatchQueue.main.async {
            // if reading is overdue over: 20:00, re-attempt every 5 minutes
            if secondsAgo >= (20 * 60) {
                self.startBGTimer(time: (5 * 60))
                print("##### started 5 minute bg timer")
                
            // if the reading is overdue: 10:00-19:59, re-attempt every minute
            } else if secondsAgo >= (10 * 60) {
                self.startBGTimer(time: 60)
                print("##### started 1 minute bg timer")
                
            // if the reading is overdue: 7:00-9:59, re-attempt every 30 seconds
            } else if secondsAgo >= (7 * 60) {
                self.startBGTimer(time: 30)
                print("##### started 30 second bg timer")
                
            // if the reading is overdue: 5:00-6:59 re-attempt every 10 seconds
            } else if secondsAgo >= (5 * 60) {
                self.startBGTimer(time: 10)
                print("##### started 10 second bg timer")
            
            // We have a current reading. Set timer to 5:10 from last reading
            } else {
                self.startBGTimer(time: 300 - secondsAgo + Double(UserDefaultsRepository.bgUpdateDelay.value))
                let timerVal = 310 - secondsAgo
                print("##### started 5:10 bg timer: \(timerVal)")
            }
        }
        
        // If we already have data, we're going to pop it to the end and remove the first. If we have old or no data, we'll destroy the whole array and start over. This is simpler than determining how far back we need to get new data from in case Dex back-filled readings
        if !onlyPullLastRecord {
            bgData.removeAll()
        } else if bgData[bgData.count - 1].date != pullDate {
            bgData.removeFirst()
            
        } else {
            if data.count > 0 {
                self.updateBadge(val: data[data.count - 1].sgv)
                if UserDefaultsRepository.speakBG.value {
                    speakBG(sgv: data[data.count - 1].sgv)
                }
            }
            return
        }
        
        // loop through the data so we can reverse the order to oldest first for the graph
        for i in 0..<data.count{
            let dateString = data[data.count - 1 - i].date
            if dateString >= dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) {
                let reading = ShareGlucoseData(sgv: data[data.count - 1 - i].sgv, date: dateString, direction: data[data.count - 1 - i].direction)
                bgData.append(reading)
            }
            
        }

        viewUpdateNSBG(sourceName: sourceName)
    }
    
    // NS BG Data Front end updater
    func viewUpdateNSBG (sourceName: String) {
        DispatchQueue.main.async {
            if UserDefaultsRepository.debugLog.value {
                self.writeDebugLog(value: "Display: BG")
                self.writeDebugLog(value: "Num BG: " + self.bgData.count.description)
            }
            let entries = self.bgData
            if entries.count < 1 { return }
            
            self.updateBGGraph()
            self.updateStats()
            
            let latestEntryi = entries.count - 1
            let latestBG = entries[latestEntryi].sgv
            let priorBG = entries[latestEntryi - 1].sgv
            let deltaBG = latestBG - priorBG as Int
            let lastBGTime = entries[latestEntryi].date
            
            let deltaTime = (TimeInterval(Date().timeIntervalSince1970)-lastBGTime) / 60
            var userUnit = " mg/dL"
            if self.mmol {
                userUnit = " mmol/L"
            }
            
            self.serverText.text = sourceName
            
            var snoozerBG = ""
            var snoozerDirection = ""
            var snoozerDelta = ""
            
            self.BGText.text = bgUnits.toDisplayUnits(String(latestBG))
            snoozerBG = bgUnits.toDisplayUnits(String(latestBG))
            self.setBGTextColor()
            
            if let directionBG = entries[latestEntryi].direction {
                self.DirectionText.text = self.bgDirectionGraphic(directionBG)
                snoozerDirection = self.bgDirectionGraphic(directionBG)
                self.latestDirectionString = self.bgDirectionGraphic(directionBG)
            }
            else
            {
                self.DirectionText.text = ""
                snoozerDirection = ""
                self.latestDirectionString = ""
            }
            
            if deltaBG < 0 {
                self.DeltaText.text = bgUnits.toDisplayUnits(String(deltaBG))
                snoozerDelta = bgUnits.toDisplayUnits(String(deltaBG))
                self.latestDeltaString = String(deltaBG)
            }
            else
            {
                self.DeltaText.text = "+" + bgUnits.toDisplayUnits(String(deltaBG))
                snoozerDelta = "+" + bgUnits.toDisplayUnits(String(deltaBG))
                self.latestDeltaString = "+" + String(deltaBG)
            }
            self.updateBadge(val: latestBG)
            
            // Snoozer Display
            guard let snoozer = self.tabBarController!.viewControllers?[2] as? SnoozeViewController else { return }
            snoozer.BGLabel.text = snoozerBG
            snoozer.DirectionLabel.text = snoozerDirection
            snoozer.DeltaLabel.text = snoozerDelta
            
        }
        
    }
    
    // NS Device Status Web Call
    func webLoadNSDeviceStatus() {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Download: device status") }
        let urlUser = UserDefaultsRepository.url.value
        
        
        // NS Api is not working to find by greater than date
        var urlStringDeviceStatus = urlUser + "/api/v1/devicestatus.json?count=288"
        if token != "" {
            urlStringDeviceStatus = urlUser + "/api/v1/devicestatus.json?count=288&token=" + token
        }
        let escapedAddress = urlStringDeviceStatus.addingPercentEncoding(withAllowedCharacters:NSCharacterSet.urlQueryAllowed)
        guard let urlDeviceStatus = URL(string: escapedAddress!) else {
            if globalVariables.nsVerifiedAlert < dateTimeUtils.getNowTimeIntervalUTC() + 300 {
                globalVariables.nsVerifiedAlert = dateTimeUtils.getNowTimeIntervalUTC()
                //self.sendNotification(title: "Nightscout Failure", body: "Please double check url, token, and internet connection. This may also indicate a temporary Nightscout issue")
            }
            DispatchQueue.main.async {
                if self.deviceStatusTimer.isValid {
                    self.deviceStatusTimer.invalidate()
                }
                self.startDeviceStatusTimer(time: 10)
            }
            
            return
        }
        
        
        var requestDeviceStatus = URLRequest(url: urlDeviceStatus)
        requestDeviceStatus.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        
        
        let deviceStatusTask = URLSession.shared.dataTask(with: requestDeviceStatus) { data, response, error in
            
            guard error == nil else {
                if globalVariables.nsVerifiedAlert < dateTimeUtils.getNowTimeIntervalUTC() + 300 {
                    globalVariables.nsVerifiedAlert = dateTimeUtils.getNowTimeIntervalUTC()
                    //self.sendNotification(title: "Nightscout Error", body: "Please double check url, token, and internet connection. This may also indicate a temporary Nightscout issue")
                }
                DispatchQueue.main.async {
                    if self.deviceStatusTimer.isValid {
                        self.deviceStatusTimer.invalidate()
                    }
                    self.startDeviceStatusTimer(time: 10)
                }
                return
            }
            
            guard let data = data else {
                if globalVariables.nsVerifiedAlert < dateTimeUtils.getNowTimeIntervalUTC() + 300 {
                    globalVariables.nsVerifiedAlert = dateTimeUtils.getNowTimeIntervalUTC()
                    //self.sendNotification(title: "Nightscout Error", body: "Please double check url, token, and internet connection. This may also indicate a temporary Nightscout issue")
                }
                DispatchQueue.main.async {
                    if self.deviceStatusTimer.isValid {
                        self.deviceStatusTimer.invalidate()
                    }
                    self.startDeviceStatusTimer(time: 10)
                }
                return
            }
            
            
            let json = try? (JSONSerialization.jsonObject(with: data) as? [[String:AnyObject]])
            if let json = json {
                DispatchQueue.main.async {
                    self.updateDeviceStatusDisplay(jsonDeviceStatus: json)
                }
            } else {
                if globalVariables.nsVerifiedAlert < dateTimeUtils.getNowTimeIntervalUTC() + 300 {
                    globalVariables.nsVerifiedAlert = dateTimeUtils.getNowTimeIntervalUTC()
                    //self.sendNotification(title: "Nightscout Error", body: "Please double check url, token, and internet connection. This may also indicate a temporary Nightscout issue")
                }
                DispatchQueue.main.async {
                    if self.deviceStatusTimer.isValid {
                        self.deviceStatusTimer.invalidate()
                    }
                    self.startDeviceStatusTimer(time: 10)
                }
                return
            }
        }
        deviceStatusTask.resume()
        
    }
    
    // NS Device Status Response Processor
    fileprivate func processPredictionFor(_ lastLoopTime: TimeInterval, _ prediction: [Int], graphData: inout [ShareGlucoseData]) {
        if UserDefaultsRepository.downloadPrediction.value && latestLoopTime < lastLoopTime {
            graphData.removeAll()
            var predictionTime = lastLoopTime
            let toLoad = Int(UserDefaultsRepository.predictionToLoad.value * 12)
            var i = 0
            while i <= toLoad {
                if i < prediction.count {
                    let prediction = ShareGlucoseData(sgv: prediction[i], date: predictionTime, direction: "flat")
                    graphData.append(prediction)
                    predictionTime += 300
                }
                i += 1
            }
        }
    }
    
    func updateDeviceStatusDisplay(jsonDeviceStatus: [[String:AnyObject]]) {
        self.clearLastInfoData(index: 0)
        self.clearLastInfoData(index: 1)
        self.clearLastInfoData(index: 3)
        self.clearLastInfoData(index: 4)
        self.clearLastInfoData(index: 5)
        tableData.removeAll()
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: device status") }
        if jsonDeviceStatus.count == 0 {
            return
        }
        
        //Process the current data first
        let lastDeviceStatus = jsonDeviceStatus[0] as [String : AnyObject]?
        
        //pump and uploader
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate,
                                   .withTime,
                                   .withDashSeparatorInDate,
                                   .withColonSeparatorInTime]
        if let lastPumpRecord = lastDeviceStatus?["pump"] as! [String : AnyObject]? {
            if let lastPumpTime = formatter.date(from: (lastPumpRecord["clock"] as! String))?.timeIntervalSince1970  {
                if let reservoirData = lastPumpRecord["reservoir"] as? Double {
                    latestPumpVolume = reservoirData
                    //tableData[5].value = String(format:"%.0f", reservoirData) + "U"
                    tableData.append(infoData(name: "Reservoir", value: String(format:"%.0f", reservoirData) + "U"))
                } else {
                    latestPumpVolume = 50.0
                    //tableData[5].value = "50+U"
                    tableData.append(infoData(name: "Reservoir", value: String(format:"%.0f", latestPumpVolume) + "U"))
                }
                
                if let uploader = lastDeviceStatus?["uploader"] as? [String:AnyObject] {
                    let upbat = uploader["battery"] as! Double
                    tableData.append(infoData(name: "Uploader", value: String(format:"%.0f", upbat) + "%"))
                }
            }
        }
        
        // Loop
        if let lastLoopRecord = lastDeviceStatus?["openaps"] as? [String : AnyObject] {
            //print("Loop: \(lastLoopRecord)")
            if let lastLoopTimeStamp = lastLoopRecord["suggested"]?["timestamp"] as? String  {
                if let lastLoopTime = formatter.date(from: lastLoopTimeStamp)?.timeIntervalSince1970  {
                    UserDefaultsRepository.alertLastLoopTime.value = lastLoopTime
                    if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "lastLoopTime: " + String(lastLoopTime)) }
                    if lastLoopRecord["failureReason"] != nil {
                        LoopStatusLabel.text = "X"
                        latestLoopStatusString = "X"
                        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Loop Failure: X") }
                    } else {
                        var wasEnacted = false
                        if let enacted = lastLoopRecord["suggested"] as? [String:AnyObject] {
                            if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Loop: Was Enacted") }
                            wasEnacted = true
                            if enacted["rate"] is Double {

                            }
                        }
                        if wasEnacted {
                            if let sensRatio = lastLoopRecord["suggested"]?["sensitivityRatio"] as? Double {
                                tableData.append(infoData(name: "Autosens ratio", value: String(format: "%.2f", sensRatio)))
                            }
                            if let iobdata = lastLoopRecord["suggested"]?["IOB"] as? Double {
                                //tableData[0].value = String(format:"%.2f", (iobdata))
                                tableData.append(infoData(name: "IOB", value: String(format: "%.2f", iobdata)))
                                latestIOB = String(format:"%.2f", (iobdata))
                            }
                            if let cobdata = lastLoopRecord["suggested"]?["COB"] as? Int64 {
                                //tableData[1].value = String(cobdata)
                                latestCOB = String(cobdata)
                            }
                        
                            if let predictdata = lastLoopRecord["suggested"]?["predBGs"] as? [String:AnyObject] {
                                if let prediction = predictdata["IOB"] as? [Int] {
                                    //PredictionLabel.text = bgUnits.toDisplayUnits(String(Int(prediction.last!)))
                                    //PredictionLabel.textColor = UIColor.systemPurple
                                    
                                    processPredictionFor(lastLoopTime, prediction, graphData: &predictionDataIOB)
                                }
                                
                                if let prediction = predictdata["ZT"] as? [Int] {
                                    processPredictionFor(lastLoopTime, prediction, graphData: &predictionDataZT)}
                                
                                if let prediction = predictdata["COB"] as? [Int] {
                                    processPredictionFor(lastLoopTime, prediction, graphData: &predictionDataCOB)}
                                else
                                {
                                    predictionDataCOB.removeAll()
                                }
                                
                                if let prediction = predictdata["UAM"] as? [Int] {
                                    processPredictionFor(lastLoopTime, prediction, graphData: &predictionDataUAM)}
                                else
                                {
                                    predictionDataUAM.removeAll()
                                }
                                
                                updatePredictionGraph()
                            }
                            
                            if let rate = lastLoopRecord["suggested"]?["rate"] as? Double {
                                tableData.append(infoData(name: "Basal", value: String(format: "%.2f", rate) + " U/hr"))
                            }
                            
                            if let reason = lastLoopRecord["suggested"]?["reason"] as? String {
                                //ReasonLabel.text = reason
                                let splitReasons = reason.replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">").split(separator: ";")
                                for semicolonSplitReason in splitReasons {
                                    let reasons = semicolonSplitReason.split(separator: ",")
                                    for r in reasons {
                                        var cleanR = r.trimmingCharacters(in: NSCharacterSet.whitespaces)
                                        
                                        //cleanR = cleanR.replacingOccurrences(of: "&lt;", with: "<")
                                        //cleanR = cleanR.replacingOccurrences(of: "&gt;", with: ">")
                                        
                                        if (cleanR.contains(":"))
                                        {
                                            let splitReason = cleanR.split(separator: ":")
                                            tableData.append(infoData(name: String(splitReason[0]).trimmingCharacters(in: NSCharacterSet.whitespaces), value: String(splitReason[1])))
                                        }
                                        else if (cleanR.starts(with: "IOBpredBG"))
                                        {
                                            tableData.append(infoData(name: "IOB pred BG", value: cleanR.replacingOccurrences(of: "IOBpredBG", with: "")))
                                        }
                                        else if (r.starts(with: "COBpredBG"))
                                        {
                                            tableData.append(infoData(name: "COBpredBG", value: cleanR.replacingOccurrences(of: "COBpredBG", with: "")))
                                        }
                                        else if (cleanR.starts(with: "insulinReq"))
                                        {
                                            tableData.append(infoData(name: "insulinReq", value: cleanR.replacingOccurrences(of: "insulinReq", with: "")))
                                        }
                                        else if (cleanR.starts(with: "Eventual BG"))
                                        {
                                            tableData.append(infoData(name: "Eventual BG", value: cleanR.replacingOccurrences(of: "Eventual BG ", with: "")))
                                        }
                                        else if (cleanR.starts(with: "temp"))
                                        {
                                            tableData.append(infoData(name: "temp", value: cleanR.replacingOccurrences(of: "temp ", with: "")))
                                        }
                                        else if (cleanR.filter { $0 == " " }.count == 1)
                                        {
                                            let splitReason = cleanR.split(separator: " ")
                                            tableData.append(infoData(name: String(splitReason[0]).trimmingCharacters(in: NSCharacterSet.whitespaces), value: String(splitReason[1])))
                                        }
                                        else
                                        {
                                            tableData.append(infoData(name: "", value: cleanR))
                                        }
                                    }
                                }
                                
                            }
                        }
                        if let loopStatus = lastLoopRecord["recommendedTempBasal"] as? [String:AnyObject] {
                            if let tempBasalTime = formatter.date(from: (loopStatus["timestamp"] as! String))?.timeIntervalSince1970 {
                                var lastBGTime = lastLoopTime
                                if bgData.count > 0 {
                                    lastBGTime = bgData[bgData.count - 1].date
                                }
                                if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "tempBasalTime: " + String(tempBasalTime)) }
                                if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "lastBGTime: " + String(lastBGTime)) }
                                if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "wasEnacted: " + String(wasEnacted)) }
                                if tempBasalTime > lastBGTime && !wasEnacted {
                                    LoopStatusLabel.text = "⏀"
                                    latestLoopStatusString = "⏀"
                                    if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Open Loop: recommended temp. temp time > bg time, was not enacted") }
                                } else {
                                    LoopStatusLabel.text = "↻"
                                    latestLoopStatusString = "↻"
                                    if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Looping: recommended temp, but temp time is < bg time and/or was enacted") }
                                }
                            }
                        } else {
                            LoopStatusLabel.text = "↻"
                            latestLoopStatusString = "↻"
                            if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Looping: no recommended temp") }
                        }
                        
                    }
                    
                    if ((TimeInterval(Date().timeIntervalSince1970) - lastLoopTime) / 60) > 15 {
                        LoopStatusLabel.text = "⚠"
                        latestLoopStatusString = "⚠"
                    }
                    latestLoopTime = lastLoopTime
                } // end lastLoopTime
            }
        } // end lastLoop Record
        
        var oText = "" as String
        currentOverride = 1.0
        if let lastOverride = lastDeviceStatus?["override"] as! [String : AnyObject]? {
            if let lastOverrideTime = formatter.date(from: (lastOverride["timestamp"] as! String))?.timeIntervalSince1970  {
            }
            if lastOverride["active"] as! Bool {
                
                let lastCorrection  = lastOverride["currentCorrectionRange"] as! [String: AnyObject]
                if let multiplier = lastOverride["multiplier"] as? Double {
                    currentOverride = multiplier
                    oText += String(format: "%.0f%%", (multiplier * 100))
                }
                else
                {
                    oText += "100%"
                }
                oText += " ("
                let minValue = lastCorrection["minValue"] as! Double
                let maxValue = lastCorrection["maxValue"] as! Double
                oText += bgUnits.toDisplayUnits(String(minValue)) + "-" + bgUnits.toDisplayUnits(String(maxValue)) + ")"
                
                //[3].value =  oText
            }
        }
        
        infoTable.reloadData()
        
        // Start the timer based on the timestamp
        let now = dateTimeUtils.getNowTimeIntervalUTC()
        let secondsAgo = now - latestLoopTime
        
        DispatchQueue.main.async {
            // if Loop is overdue over: 20:00, re-attempt every 5 minutes
            if secondsAgo >= (20 * 60) {
                self.startDeviceStatusTimer(time: (5 * 60))
                print("started 5 minute device status timer")
                
                // if the Loop is overdue: 10:00-19:59, re-attempt every minute
            } else if secondsAgo >= (10 * 60) {
                self.startDeviceStatusTimer(time: 60)
                print("started 1 minute device status timer")
                
                // if the Loop is overdue: 7:00-9:59, re-attempt every 30 seconds
            } else if secondsAgo >= (7 * 60) {
                self.startDeviceStatusTimer(time: 30)
                print("started 30 second device status timer")
                
                // if the Loop is overdue: 5:00-6:59 re-attempt every 10 seconds
            } else if secondsAgo >= (5 * 60) {
                self.startDeviceStatusTimer(time: 10)
                print("started 10 second device status timer")
                
                // We have a current Loop. Set timer to 5:10 from last reading
            } else {
                self.startDeviceStatusTimer(time: 310 - secondsAgo)
                let timerVal = 310 - secondsAgo
                print("started 5:10 device status timer: \(timerVal)")
            }
        }
    }
    
    // NS Cage Web Call
    func webLoadNSCage() {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Download: CAGE") }
        let urlUser = UserDefaultsRepository.url.value
        var urlString = urlUser + "/api/v1/treatments.json?find[eventType]=Site%20Change&count=1"
        if token != "" {
            urlString = urlUser + "/api/v1/treatments.json?token=" + token + "&find[eventType]=Site%20Change&count=1"
        }
        
        guard let urlData = URL(string: urlString) else {
            return
        }
        var request = URLRequest(url: urlData)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                return
            }
            guard let data = data else {
                return
            }
            
            let decoder = JSONDecoder()
            let entriesResponse = try? decoder.decode([cageData].self, from: data)
            if let entriesResponse = entriesResponse {
                DispatchQueue.main.async {
                    self.updateCage(data: entriesResponse)
                }
            } else {
                return
            }
        }
        task.resume()
    }
    
    // NS Cage Response Processor
    func updateCage(data: [cageData]) {
        self.clearLastInfoData(index: 7)
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: CAGE") }
        if data.count == 0 {
            return
        }
        
        let lastCageString = data[0].created_at
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate,
                                   .withTime,
                                   .withDashSeparatorInDate,
                                   .withColonSeparatorInTime]
        UserDefaultsRepository.alertCageInsertTime.value = formatter.date(from: (lastCageString))?.timeIntervalSince1970 as! TimeInterval
        if let cageTime = formatter.date(from: (lastCageString))?.timeIntervalSince1970 {
            let now = dateTimeUtils.getNowTimeIntervalUTC()
            let secondsAgo = now - cageTime
            //let days = 24 * 60 * 60
            
            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .positional // Use the appropriate positioning for the current locale
            formatter.allowedUnits = [ .day, .hour ] // Units to display in the formatted string
            formatter.zeroFormattingBehavior = [ .pad ] // Pad with zeroes where appropriate for the locale
            
            let formattedDuration = formatter.string(from: secondsAgo)
            //tableData[7].value = formattedDuration ?? ""
        }
        infoTable.reloadData()
    }
    
    // NS Sage Web Call
    func webLoadNSSage() {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Download: SAGE") }
        
        let lastDateString = dateTimeUtils.nowMinus10DaysTimeInterval()
        let urlUser = UserDefaultsRepository.url.value
        var urlString = urlUser + "/api/v1/treatments.json?find[eventType]=Sensor%20Start&find[created_at][$gte]=" + lastDateString + "&count=1"
        if token != "" {
            urlString = urlUser + "/api/v1/treatments.json?token=" + token + "&find[eventType]=Sensor%20Start&find[created_at][$gte]=" + lastDateString + "&count=1"
        }
        
        guard let urlData = URL(string: urlString) else {
            return
        }
        var request = URLRequest(url: urlData)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                return
            }
            guard let data = data else {
                return
            }
            
            let decoder = JSONDecoder()
            let entriesResponse = try? decoder.decode([cageData].self, from: data)
            if let entriesResponse = entriesResponse {
                DispatchQueue.main.async {
                    self.updateSage(data: entriesResponse)
                }
            } else {
                return
            }
        }
        task.resume()
    }
    
    // NS Sage Response Processor
    func updateSage(data: [cageData]) {
        self.clearLastInfoData(index: 6)
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process/Display: SAGE") }
        if data.count == 0 {
            return
        }
        
        var lastSageString = data[0].created_at
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate,
                                   .withTime,
                                   .withDashSeparatorInDate,
                                   .withColonSeparatorInTime]
        UserDefaultsRepository.alertSageInsertTime.value = formatter.date(from: (lastSageString))?.timeIntervalSince1970 as! TimeInterval

        if UserDefaultsRepository.alertAutoSnoozeCGMStart.value && (dateTimeUtils.getNowTimeIntervalUTC() - UserDefaultsRepository.alertSageInsertTime.value < 7200){
            let snoozeTime = Date(timeIntervalSince1970: UserDefaultsRepository.alertSageInsertTime.value + 7200)
            UserDefaultsRepository.alertSnoozeAllTime.value = snoozeTime
            UserDefaultsRepository.alertSnoozeAllIsSnoozed.value = true
            guard let alarms = self.tabBarController!.viewControllers?[1] as? AlarmViewController else { return }
            alarms.reloadIsSnoozed(key: "alertSnoozeAllIsSnoozed", value: true)
            alarms.reloadSnoozeTime(key: "alertSnoozeAllTime", setNil: false, value: snoozeTime)
        }
        
        if let sageTime = formatter.date(from: (lastSageString as! String))?.timeIntervalSince1970 {
            let now = dateTimeUtils.getNowTimeIntervalUTC()
            let secondsAgo = now - sageTime
            let days = 24 * 60 * 60
            
            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .positional // Use the appropriate positioning for the current locale
            formatter.allowedUnits = [ .day, .hour] // Units to display in the formatted string
            formatter.zeroFormattingBehavior = [ .pad ] // Pad with zeroes where appropriate for the locale
            
            let formattedDuration = formatter.string(from: secondsAgo)
            //tableData[6].value = formattedDuration ?? ""
        }
        infoTable.reloadData()
    }
    
    // NS Profile Web Call
    func webLoadNSProfile() {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Download: profile") }
        let urlUser = UserDefaultsRepository.url.value
        var urlString = urlUser + "/api/v1/profile/current.json"
        if token != "" {
            urlString = urlUser + "/api/v1/profile/current.json?token=" + token
        }
        
        let escapedAddress = urlString.addingPercentEncoding(withAllowedCharacters:NSCharacterSet.urlQueryAllowed)
        guard let url = URL(string: escapedAddress!) else {
            return
        }
        
        var request = URLRequest(url: url)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                return
            }
            guard let data = data else {
                return
            }
            
            
            let json = try? JSONSerialization.jsonObject(with: data) as! Dictionary<String, Any>
            
            if let json = json {
                DispatchQueue.main.async {
                    self.updateProfile(jsonDeviceStatus: json)
                }
            } else {
                return
            }
        }
        task.resume()
    }
    
    // NS Profile Response Processor
    fileprivate func extractBasal(_ jsonDeviceStatus: [String : Any]) throws -> NSArray {
        let store = try jsonDeviceStatus[keyPath: "store"] as! NSDictionary
        
        for (key, value) in store
        {
            if let profile = value as? NSDictionary
            {
                let basal = profile["basal"] as! NSArray
                return basal
            }
        }
        
        return NSArray()
    }
    
    func updateProfile(jsonDeviceStatus: Dictionary<String, Any>) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: profile") }
        if jsonDeviceStatus.count == 0 {
            return
        }
        if jsonDeviceStatus[keyPath: "message"] != nil { return }
        do {
            
            let basal = try extractBasal(jsonDeviceStatus)
            
            basalProfile.removeAll()
            for i in 0..<basal.count {
                let dict = basal[i] as! Dictionary<String, Any>
                do {
                    let thisValue = try dict[keyPath: "value"] as! Double
                    let thisTime = dict[keyPath: "time"] as! String
                    if let thisTimeAsSeconds = dict[keyPath: "timeAsSeconds"] as! Double? {
                        let entry = basalProfileStruct(value: thisValue, time: thisTime, timeAsSeconds: thisTimeAsSeconds)
                        basalProfile.append(entry)
                    }
                    else
                    {
                        let splitTime = thisTime.split(separator: ":")
                        let dateComponents = DateComponents(hour: Int.init(string: String(splitTime[0])), minute: Int.init(string: String(splitTime[1])))
                        let thisTimeAsSeconds = (dateComponents.hour! * 60 + dateComponents.minute!) * 60
                        let entry = basalProfileStruct(value: thisValue, time: thisTime, timeAsSeconds: Double(thisTimeAsSeconds))
                        basalProfile.append(entry)
                    }
                    
                    
                    
                } catch {
                   if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "ERROR: profile wrapped in quotes") }
                }
            }
        } catch {
            if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "ERROR: profile can't be loaded") }
        }
        // Don't process the basal or draw the graph until after the BG has been fully processeed and drawn
        if firstGraphLoad { return }

        var basalSegments: [DataStructs.basalProfileSegment] = []
        
        let graphHours = 24 * UserDefaultsRepository.downloadDays.value
        // Build scheduled basal segments from right to left by
        // moving pointers to the current midnight and current basal
        var midnight = dateTimeUtils.getTimeIntervalMidnightToday()
        var basalProfileIndex = basalProfile.count - 1
        var start = midnight + basalProfile[basalProfileIndex].timeAsSeconds
        var end = dateTimeUtils.getNowTimeIntervalUTC()
        // Move back until we're in the graph range
        while start > end {
            basalProfileIndex -= 1
            start = midnight + basalProfile[basalProfileIndex].timeAsSeconds
        }
        // Add records while they're still within the graph
        let graphStart = dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours)
        while end >= graphStart {
            let entry = DataStructs.basalProfileSegment(
                basalRate: basalProfile[basalProfileIndex].value, startDate: start, endDate: end)
            basalSegments.append(entry)
            
            basalProfileIndex -= 1
            if basalProfileIndex < 0 {
                basalProfileIndex = basalProfile.count - 1
                midnight = midnight.advanced(by: -24*60*60)
            }
            end = start - 1
            start = midnight + basalProfile[basalProfileIndex].timeAsSeconds
        }
        // reverse the result to get chronological order
        basalSegments.reverse()
        
        var firstPass = true
        // Runs the scheduled basal to the end of the prediction line
        var predictionEndTime = dateTimeUtils.getNowTimeIntervalUTC() + (3600 * UserDefaultsRepository.predictionToLoad.value)
        basalScheduleData.removeAll()
        
        for i in 0..<basalSegments.count {
            let timeStart = dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours)
            
            // This processed everything after the first one.
            if firstPass == false
                && basalSegments[i].startDate <= predictionEndTime {
                let startDot = basalGraphStruct(basalRate: basalSegments[i].basalRate, date: basalSegments[i].startDate)
                basalScheduleData.append(startDot)
                var endDate = basalSegments[i].endDate
                
                // if it's the last one needed, set it to end at the prediction end time
                if endDate > predictionEndTime || i == basalSegments.count - 1 {
                    endDate = Double(predictionEndTime)
                }

                let endDot = basalGraphStruct(basalRate: basalSegments[i].basalRate, date: endDate)
                basalScheduleData.append(endDot)
            }
            
            // we need to manually set the first one
            // Check that this is the first one and there are no existing entries
            if firstPass == true {
                // check that the timestamp is > the current entry and < the next entry
                if timeStart >= basalSegments[i].startDate && timeStart < basalSegments[i].endDate {
                    // Set the start time to match the BG start
                    let startDot = basalGraphStruct(basalRate: basalSegments[i].basalRate, date: Double(timeStart + (60 * 5)))
                    basalScheduleData.append(startDot)
                    
                    // set the enddot where the next one will start
                    var endDate = basalSegments[i].endDate
                    let endDot = basalGraphStruct(basalRate: basalSegments[i].basalRate, date: endDate)
                    basalScheduleData.append(endDot)
                    firstPass = false
                }
            }
        }
        
        if UserDefaultsRepository.graphBasal.value {
            updateBasalScheduledGraph()
        }
        
    }
    
    // NS Treatments Web Call
    // Downloads Basal, Bolus, Carbs, BG Check, Notes, Overrides
    func WebLoadNSTreatments() {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Download: Treatments") }
        if !UserDefaultsRepository.downloadTreatments.value { return }
        
        let graphHours = 24 * UserDefaultsRepository.downloadDays.value
        let startTimeString = dateTimeUtils.nowMinusNHoursTimeInterval(N: graphHours)
        
        var urlString = UserDefaultsRepository.url.value + "/api/v1/treatments.json?find[created_at][$gte]=" + startTimeString
        if token != "" {
            urlString = UserDefaultsRepository.url.value + "/api/v1/treatments.json?token=" + token + "&find[created_at][$gte]=" + startTimeString
        }
        
        guard let urlData = URL(string: urlString) else {
            return
        }
        
        
        var request = URLRequest(url: urlData)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            
            guard error == nil else {
                return
            }
            guard let data = data else {
                return
            }
            
            let json = try? (JSONSerialization.jsonObject(with: data) as? [[String:AnyObject]])
            if let json = json {
                DispatchQueue.main.async {
                    self.updateTreatments(entries: json)
                }
            } else {
                return
            }
        }
        task.resume()
    }
    
    // Process and split out treatments to individual tasks
    func updateTreatments(entries: [[String:AnyObject]]) {
        
        var tempBasal: [[String:AnyObject]] = []
        var bolus: [[String:AnyObject]] = []
        var carbs: [[String:AnyObject]] = []
        var temporaryOverride: [[String:AnyObject]] = []
        var note: [[String:AnyObject]] = []
        var bgCheck: [[String:AnyObject]] = []
        var suspendPump: [[String:AnyObject]] = []
        var resumePump: [[String:AnyObject]] = []
        var pumpSiteChange: [[String:AnyObject]] = []
        var cgmSensorStart: [[String:AnyObject]] = []
        
        for i in 0..<entries.count {
            let entry = entries[i] as [String : AnyObject]?
            if !(entry?["isValid"] as! Bool) {
                continue
            }
            
            switch entry?["eventType"] as! String {
                case "Temp Basal":
                    tempBasal.append(entry!)
                case "Correction Bolus":
                    bolus.append(entry!)
                case "Bolus":
                    bolus.append(entry!)
                case "Meal Bolus":
                    carbs.append(entry!)
                    bolus.append(entry!)
                case "Carb Correction":
                    carbs.append(entry!)
                case "Temporary Override":
                    temporaryOverride.append(entry!)
                case "Note":
                    note.append(entry!)
                    print("Note: \(String(describing: entry))")
                case "BG Check":
                    bgCheck.append(entry!)
                case "Suspend Pump":
                    suspendPump.append(entry!)
                case "Resume Pump":
                    resumePump.append(entry!)
                case "Pump Site Change":
                    pumpSiteChange.append(entry!)
                case "Sensor Start":
                    cgmSensorStart.append(entry!)
                default:
                    print("No Match: \(String(describing: entry))")
            }
        }
        // end of for loop
        
        if tempBasal.count > 0 {
                   processNSBasals(entries: tempBasal)
               } else {
                   if basalData.count < 0 {
                       clearOldTempBasal()
                   }
               }
               if bolus.count > 0 {
                   processNSBolus(entries: bolus)
               } else {
                   if bolusData.count > 0 {
                       clearOldBolus()
                   }
               }
               if carbs.count > 0 {
                   processNSCarbs(entries: carbs)
               } else {
                   if carbData.count > 0 {
                       clearOldCarb()
                   }
               }
               if bgCheck.count > 0 {
                   processNSBGCheck(entries: bgCheck)
               } else {
                   if bgCheckData.count > 0 {
                       clearOldBGCheck()
                   }
               }
               if temporaryOverride.count > 0 {
                   processNSOverrides(entries: temporaryOverride)
               } else {
                   if overrideGraphData.count > 0 {
                       clearOldOverride()
                   }
               }
               if suspendPump.count > 0 {
                   processSuspendPump(entries: suspendPump)
               } else {
                   if suspendGraphData.count > 0 {
                       clearOldSuspend()
                   }
               }
               if resumePump.count > 0 {
                   processResumePump(entries: resumePump)
               } else {
                   if resumeGraphData.count > 0 {
                       clearOldResume()
                   }
               }
               if cgmSensorStart.count > 0 {
                   processSensorStart(entries: cgmSensorStart)
               } else {
                   if sensorStartGraphData.count > 0 {
                       clearOldSensor()
                   }
               }
               if note.count > 0 {
                   processNotes(entries: note)
               } else {
                   if noteGraphData.count > 0 {
                       clearOldNotes()
                   }
               }
    }
    
    func clearOldTempBasal()
        {
            basalData.removeAll()
            updateBasalGraph()
        }
        
        func clearOldBolus()
        {
            bolusData.removeAll()
            updateBolusGraph()
        }
        
        func clearOldCarb()
        {
            carbData.removeAll()
            updateCarbGraph()
        }
        
        func clearOldBGCheck()
        {
            bgCheckData.removeAll()
            updateBGCheckGraph()
        }
        
        func clearOldOverride()
        {
            overrideGraphData.removeAll()
            updateOverrideGraph()
        }
        
        func clearOldSuspend()
        {
            suspendGraphData.removeAll()
            updateSuspendGraph()
        }
        
        func clearOldResume()
        {
            resumeGraphData.removeAll()
            updateResumeGraph()
        }
        
        func clearOldSensor()
        {
            sensorStartGraphData.removeAll()
            updateSensorStart()
        }
        
        func clearOldNotes()
        {
            noteGraphData.removeAll()
            updateNotes()
        }
    
    // NS Temp Basal Response Processor
    func processNSBasals(entries: [[String:AnyObject]]) {
        self.clearLastInfoData(index: 2)
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: Basal") }
        // due to temp basal durations, we're going to destroy the array and load everything each cycle for the time being.
        basalData.removeAll()
        
        var lastEndDot = 0.0
        
        var tempArray = entries
        tempArray.reverse()
        for i in 0..<tempArray.count {
            let currentEntry = tempArray[i] as [String : AnyObject]?
            var basalDate: String
            if currentEntry?["timestamp"] != nil {
                basalDate = currentEntry?["timestamp"] as! String
            } else if currentEntry?["created_at"] != nil {
                basalDate = currentEntry?["created_at"] as! String
            } else {
                continue
            }
            var strippedZone = String(basalDate.dropLast())
            strippedZone = strippedZone.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            guard let dateString = dateFormatter.date(from: strippedZone) else { continue }
            let dateTimeStamp = dateString.timeIntervalSince1970
            guard let basalRate = currentEntry?["absolute"] as? Double else {
                if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "ERROR: Null Basal entry")}
                continue
            }
            
            let midnightTime = dateTimeUtils.getTimeIntervalMidnightToday()
            // Setting end dots
            var duration = 0.0
            do {
                duration = try currentEntry?["duration"] as! Double
            } catch {
                print("No Duration Found")
            }
            
            // This adds scheduled basal wherever there is a break between temps. can't check the prior ending on the first item. it is 24 hours old, so it isn't important for display anyway
            if i > 0 {
                let priorEntry = tempArray[i - 1] as [String : AnyObject]?
                var priorBasalDate: String
                if priorEntry?["timestamp"] != nil {
                    priorBasalDate = priorEntry?["timestamp"] as! String
                } else if currentEntry?["created_at"] != nil {
                    priorBasalDate = priorEntry?["created_at"] as! String
                } else {
                    continue
                }
                var priorStrippedZone = String(priorBasalDate.dropLast())
                priorStrippedZone = priorStrippedZone.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression)
                let priorDateFormatter = DateFormatter()
                priorDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                priorDateFormatter.locale = Locale(identifier: "en_US")
                priorDateFormatter.timeZone = TimeZone(abbreviation: "UTC")
                guard let priorDateString = dateFormatter.date(from: priorStrippedZone) else { continue }
                let priorDateTimeStamp = priorDateString.timeIntervalSince1970
                let priorDuration = priorEntry?["duration"] as! Double
                // if difference between time stamps is greater than the duration of the last entry, there is a gap. Give a 15 second leeway on the timestamp
                if Double( dateTimeStamp - priorDateTimeStamp ) > Double( (priorDuration * 60) + 15 ) {
                    
                    var scheduled = 0.0
                    var midGap = false
                    var midGapTime: TimeInterval = 0
                    var midGapValue: Double = 0
                    // cycle through basal profiles.
                    // TODO figure out how to deal with profile changes that happen mid-gap
                    for b in 0..<self.basalScheduleData.count {
                        
                        if (priorDateTimeStamp + (priorDuration * 60)) >= basalScheduleData[b].date {
                            scheduled = basalScheduleData[b].basalRate
                            
                            // deal with mid-gap scheduled basal change
                            // don't do it on the last scheudled basal entry
                            if b < self.basalScheduleData.count - 1 {
                                if dateTimeStamp > self.basalScheduleData[b + 1].date {
                                   // midGap = true
                                    // TODO: finish this to handle mid-gap items without crashing from overlapping entries
                                    midGapTime = self.basalScheduleData[b + 1].date
                                    midGapValue = self.basalScheduleData[b + 1].basalRate
                                }
                            }
                            
                        }
                        
                    }
                    
                    // Make the starting dot at the last ending dot
                    let startDot = basalGraphStruct(basalRate: scheduled, date: Double(priorDateTimeStamp + (priorDuration * 60)))
                    basalData.append(startDot)
                        
                       
                    if midGap {
                        // Make the ending dot at the new scheduled basal
                        let endDot1 = basalGraphStruct(basalRate: scheduled, date: Double(midGapTime))
                        basalData.append(endDot1)
                        // Make the starting dot at the scheduled Time
                        let startDot2 = basalGraphStruct(basalRate: midGapValue, date: Double(midGapTime))
                        basalData.append(startDot2)
                        // Make the ending dot at the new basal value
                        let endDot2 = basalGraphStruct(basalRate: midGapValue, date: Double(dateTimeStamp))
                        basalData.append(endDot2)
                        
                    } else {
                        // Make the ending dot at the new starting dot
                        let endDot = basalGraphStruct(basalRate: scheduled, date: Double(dateTimeStamp))
                        basalData.append(endDot)
                    }
                        

                }
            }
            
            // Make the starting dot
            let startDot = basalGraphStruct(basalRate: basalRate, date: Double(dateTimeStamp))
            basalData.append(startDot)
            
            // Make the ending dot
            // If it's the last one and has no duration, extend it for 30 minutes past the start. Otherwise set ending at duration
            // duration is already set to 0 if there is no duration set on it.
            //if i == tempArray.count - 1 && dateTimeStamp + duration <= dateTimeUtils.getNowTimeIntervalUTC() {
            if i == tempArray.count - 1 && duration == 0.0 {
                lastEndDot = dateTimeStamp + (30 * 60)
                latestBasal = String(format:"%.2f", basalRate)
            } else {
                lastEndDot = dateTimeStamp + (duration * 60)
                latestBasal = String(format:"%.2f", basalRate)
            }
            
            // Double check for overlaps of incorrectly ended TBRs and sent it to end when the next one starts if it finds a discrepancy
            if i < tempArray.count - 1 {
                let nextEntry = tempArray[i + 1] as [String : AnyObject]?
                var nextBasalDate: String
                if nextEntry?["timestamp"] != nil {
                    nextBasalDate = nextEntry?["timestamp"] as! String
                } else if currentEntry?["created_at"] != nil {
                    nextBasalDate = nextEntry?["created_at"] as! String
                } else {
                    continue
                }
                var nextStrippedZone = String(nextBasalDate.dropLast())
                nextStrippedZone = nextStrippedZone.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression)
                let nextDateFormatter = DateFormatter()
                nextDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                nextDateFormatter.locale = Locale(identifier: "en_US")
                nextDateFormatter.timeZone = TimeZone(abbreviation: "UTC")
                guard let nextDateString = dateFormatter.date(from: nextStrippedZone) else { continue }
                let nextDateTimeStamp = nextDateString.timeIntervalSince1970
                if nextDateTimeStamp < (dateTimeStamp + (duration * 60)) {
                    lastEndDot = nextDateTimeStamp
                }
            }
            
            let endDot = basalGraphStruct(basalRate: basalRate, date: Double(lastEndDot))
            basalData.append(endDot)
            
            
        }
        
        // If last  basal was prior to right now, we need to create one last scheduled entry
        if lastEndDot <= dateTimeUtils.getNowTimeIntervalUTC() {
            var scheduled = 0.0
            // cycle through basal profiles.
            // TODO figure out how to deal with profile changes that happen mid-gap
            for b in 0..<self.basalProfile.count {
                let scheduleTimeYesterday = self.basalProfile[b].timeAsSeconds + dateTimeUtils.getTimeIntervalMidnightYesterday()
                let scheduleTimeToday = self.basalProfile[b].timeAsSeconds + dateTimeUtils.getTimeIntervalMidnightToday()
                // check the prior temp ending to the profile seconds from midnight
                print("yesterday " + String(scheduleTimeYesterday))
                print("today " + String(scheduleTimeToday))
                if lastEndDot >= scheduleTimeToday {
                    scheduled = basalProfile[b].value
                }
            }
            
            latestBasal = String(format:"%.2f", scheduled)
            // Make the starting dot at the last ending dot
            let startDot = basalGraphStruct(basalRate: scheduled, date: Double(lastEndDot))
            basalData.append(startDot)
            
            // Make the ending dot 10 minutes after now
            let endDot = basalGraphStruct(basalRate: scheduled, date: Double(Date().timeIntervalSince1970 + (60 * 10)))
            basalData.append(endDot)
            
        }
        //tableData[2].value = latestBasal
        //tableData.append(infoData(name: "Basal", value: latestBasal))
        infoTable.reloadData()
        if UserDefaultsRepository.graphBasal.value {
            updateBasalGraph()
        }
        infoTable.reloadData()
    }

    // NS Meal Bolus Response Processor
    func processNSBolus(entries: [[String:AnyObject]]) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: Bolus") }
        // because it's a small array, we're going to destroy and reload every time.
        bolusData.removeAll()
        var lastFoundIndex = 0
        for i in 0..<entries.count {
            let currentEntry = entries[entries.count - 1 - i] as [String : AnyObject]?
            var bolusDate: String
            if currentEntry?["timestamp"] != nil {
                bolusDate = currentEntry?["timestamp"] as! String
            } else if currentEntry?["created_at"] != nil {
                bolusDate = currentEntry?["created_at"] as! String
            } else {
                continue
            }
            
            // fix to remove millisecond (after period in timestamp) for FreeAPS users
            var strippedZone = String(bolusDate.dropLast())
            strippedZone = strippedZone.components(separatedBy: ".")[0]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            guard let dateString = dateFormatter.date(from: strippedZone) else { continue }
            let dateTimeStamp = dateString.timeIntervalSince1970

            guard let bolus = currentEntry?["insulin"] as? Double else { continue }
                let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
                lastFoundIndex = sgv.foundIndex
                
                if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                    // Make the dot
                    let dot = bolusGraphStruct(value: bolus, date: Double(dateTimeStamp), sgv: Int(sgv.sgv + 20))
                    bolusData.append(dot)
                }
            
        }
        
        if UserDefaultsRepository.graphBolus.value {
            updateBolusGraph()
        }
        
    }
   
    // NS Carb Bolus Response Processor
    func processNSCarbs(entries: [[String:AnyObject]]) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: Carbs") }
        // because it's a small array, we're going to destroy and reload every time.
        carbData.removeAll()
        var lastFoundIndex = 0
        var lastFoundBolus = 0
        for i in 0..<entries.count {
            let currentEntry = entries[entries.count - 1 - i] as [String : AnyObject]?
            var carbDate: String
            if currentEntry?["timestamp"] != nil {
                carbDate = currentEntry?["timestamp"] as! String
            } else if currentEntry?["created_at"] != nil {
                carbDate = currentEntry?["created_at"] as! String
            } else {
                continue
            }
            
            
            let absorptionTime = currentEntry?["absorptionTime"] as? Int ?? 0
            
            // Fix for FreeAPS milliseconds in timestamp
            var strippedZone = String(carbDate.dropLast())
            strippedZone = strippedZone.components(separatedBy: ".")[0]
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            guard let dateString = dateFormatter.date(from: strippedZone) else { continue }
            var dateTimeStamp = dateString.timeIntervalSince1970
            
            guard let carbs = currentEntry?["carbs"] as? Double else {
                if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "ERROR: Null Carb entry")}
                continue
            }
            let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
            lastFoundIndex = sgv.foundIndex
            
            var offset = -50
            if sgv.sgv < Double(topBG - 100) {
                let bolusTime = findNearestBolusbyTime(timeWithin: 300, needle: dateTimeStamp, haystack: bolusData, startingIndex: lastFoundBolus)
                lastFoundBolus = bolusTime.foundIndex
                
                if bolusTime.offset {
                    offset = 70
                } else {
                    offset = 20
                }
            }
            
            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                // Make the dot
                let dot = carbGraphStruct(value: Double(carbs), date: Double(dateTimeStamp), sgv: Int(sgv.sgv + Double(offset)), absorptionTime: absorptionTime)
                carbData.append(dot)
            }
            
            
            
        }
        
        if UserDefaultsRepository.graphCarbs.value {
            updateCarbGraph()
        }
        
        
    }
    
    // NS Suspend Pump Response Processor
    func processSuspendPump(entries: [[String:AnyObject]]) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: Suspend Pump") }
        // because it's a small array, we're going to destroy and reload every time.
        suspendGraphData.removeAll()
        var lastFoundIndex = 0
        for i in 0..<entries.count {
            let currentEntry = entries[entries.count - 1 - i] as [String : AnyObject]?
            var date: String
            if currentEntry?["timestamp"] != nil {
                date = currentEntry?["timestamp"] as! String
            } else if currentEntry?["created_at"] != nil {
                date = currentEntry?["created_at"] as! String
            } else {
                return
            }
            // Fix for FreeAPS milliseconds in timestamp
            var strippedZone = String(date.dropLast())
            strippedZone = strippedZone.components(separatedBy: ".")[0]
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            let dateString = dateFormatter.date(from: strippedZone)
            let dateTimeStamp = dateString!.timeIntervalSince1970

            let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
            lastFoundIndex = sgv.foundIndex
            
            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                // Make the dot
                let dot = DataStructs.timestampOnlyStruct(date: Double(dateTimeStamp), sgv: Int(sgv.sgv))
                suspendGraphData.append(dot)
            }
        }
        if UserDefaultsRepository.graphOtherTreatments.value {
        updateSuspendGraph()
        }
        
    }
    
    // NS Resume Pump Response Processor
    func processResumePump(entries: [[String:AnyObject]]) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: Resume Pump") }
        // because it's a small array, we're going to destroy and reload every time.
        resumeGraphData.removeAll()
        var lastFoundIndex = 0
        for i in 0..<entries.count {
            let currentEntry = entries[entries.count - 1 - i] as [String : AnyObject]?
            var date: String
            if currentEntry?["timestamp"] != nil {
                date = currentEntry?["timestamp"] as! String
            } else if currentEntry?["created_at"] != nil {
                date = currentEntry?["created_at"] as! String
            } else {
                return
            }
            // Fix for FreeAPS milliseconds in timestamp
            var strippedZone = String(date.dropLast())
            strippedZone = strippedZone.components(separatedBy: ".")[0]
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            let dateString = dateFormatter.date(from: strippedZone)
            let dateTimeStamp = dateString!.timeIntervalSince1970

            let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
            lastFoundIndex = sgv.foundIndex
            
            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                // Make the dot
                let dot = DataStructs.timestampOnlyStruct(date: Double(dateTimeStamp), sgv: Int(sgv.sgv))
                resumeGraphData.append(dot)
            }
        }
        if UserDefaultsRepository.graphOtherTreatments.value {
        updateResumeGraph()
        }
        
    }
    
    // NS Sensor Start Response Processor
    func processSensorStart(entries: [[String:AnyObject]]) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: Sensor Start") }
        // because it's a small array, we're going to destroy and reload every time.
        sensorStartGraphData.removeAll()
        var lastFoundIndex = 0
        for i in 0..<entries.count {
            let currentEntry = entries[entries.count - 1 - i] as [String : AnyObject]?
            var date: String
            if currentEntry?["timestamp"] != nil {
                date = currentEntry?["timestamp"] as! String
            } else if currentEntry?["created_at"] != nil {
                date = currentEntry?["created_at"] as! String
            } else {
                return
            }
            // Fix for FreeAPS milliseconds in timestamp
            var strippedZone = String(date.dropLast())
            strippedZone = strippedZone.components(separatedBy: ".")[0]
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            let dateString = dateFormatter.date(from: strippedZone)
            let dateTimeStamp = dateString!.timeIntervalSince1970

            let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
            lastFoundIndex = sgv.foundIndex
            
            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                // Make the dot
                let dot = DataStructs.timestampOnlyStruct(date: Double(dateTimeStamp), sgv: Int(sgv.sgv))
                sensorStartGraphData.append(dot)
            }
        }
        if UserDefaultsRepository.graphOtherTreatments.value {
        updateSensorStart()
        }
        
    }
    
    // NS Note Response Processor
    func processNotes(entries: [[String:AnyObject]]) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: Notes") }
        // because it's a small array, we're going to destroy and reload every time.
        noteGraphData.removeAll()
        var lastFoundIndex = 0
        for i in 0..<entries.count {
            let currentEntry = entries[entries.count - 1 - i] as [String : AnyObject]?
            var date: String
            if currentEntry?["timestamp"] != nil {
                date = currentEntry?["timestamp"] as! String
            } else if currentEntry?["created_at"] != nil {
                date = currentEntry?["created_at"] as! String
            } else {
                return
            }
            // Fix for FreeAPS milliseconds in timestamp
            var strippedZone = String(date.dropLast())
            strippedZone = strippedZone.components(separatedBy: ".")[0]
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            let dateString = dateFormatter.date(from: strippedZone)
            let dateTimeStamp = dateString!.timeIntervalSince1970

            let sgv = findNearestBGbyTime(needle: dateTimeStamp, haystack: bgData, startingIndex: lastFoundIndex)
            lastFoundIndex = sgv.foundIndex
            
            guard let thisNote = currentEntry?["notes"] as? String else { continue }
            
            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                // Make the dot
                let dot = DataStructs.noteStruct(date: Double(dateTimeStamp), sgv: Int(sgv.sgv), note: thisNote)
                noteGraphData.append(dot)
            }
        }
        if UserDefaultsRepository.graphOtherTreatments.value {
        updateNotes()
        }
        
    }
    
    // NS BG Check Response Processor
    func processNSBGCheck(entries: [[String:AnyObject]]) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: BG Check") }
        // because it's a small array, we're going to destroy and reload every time.
        bgCheckData.removeAll()
        for i in 0..<entries.count {
            let currentEntry = entries[entries.count - 1 - i] as [String : AnyObject]?
            var date: String
            if currentEntry?["timestamp"] != nil {
                date = currentEntry?["timestamp"] as! String
            } else if currentEntry?["created_at"] != nil {
                date = currentEntry?["created_at"] as! String
            } else {
                return
            }
            // Fix for FreeAPS milliseconds in timestamp
            var strippedZone = String(date.dropLast())
            strippedZone = strippedZone.components(separatedBy: ".")[0]
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            let dateString = dateFormatter.date(from: strippedZone)
            let dateTimeStamp = dateString!.timeIntervalSince1970
            
            guard let sgv = currentEntry?["glucose"] as? Int else {
                if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "ERROR: Non-Int Glucose entry")}
                continue
            }
            
            if dateTimeStamp < (dateTimeUtils.getNowTimeIntervalUTC() + (60 * 60)) {
                // Make the dot
                //let dot = ShareGlucoseData(value: Double(carbs), date: Double(dateTimeStamp), sgv: Int(sgv.sgv))
                let dot = ShareGlucoseData(sgv: sgv, date: Double(dateTimeStamp), direction: "")
                bgCheckData.append(dot)
            }
            
            
            
        }
        
        if UserDefaultsRepository.graphOtherTreatments.value {
            updateBGCheckGraph()
        }
        
        
    }
    
    // NS Override Response Processor
    func processNSOverrides(entries: [[String:AnyObject]]) {
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Process: Overrides") }
        // because it's a small array, we're going to destroy and reload every time.
        overrideGraphData.removeAll()
        for i in 0..<entries.count {
            let currentEntry = entries[entries.count - 1 - i] as [String : AnyObject]?
            var date: String
            if currentEntry?["timestamp"] != nil {
                date = currentEntry?["timestamp"] as! String
            } else if currentEntry?["created_at"] != nil {
                date = currentEntry?["created_at"] as! String
            } else {
                return
            }
            // Fix for FreeAPS milliseconds in timestamp
            var strippedZone = String(date.dropLast())
            strippedZone = strippedZone.components(separatedBy: ".")[0]
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
            let dateString = dateFormatter.date(from: strippedZone)
            var dateTimeStamp = dateString!.timeIntervalSince1970
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            if dateTimeStamp < dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) {
                dateTimeStamp = dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours)
            }
            
            var multiplier: Double = 1.0
            if currentEntry?["insulinNeedsScaleFactor"] != nil {
                multiplier = currentEntry?["insulinNeedsScaleFactor"] as! Double
            }
            var duration: Double = 5.0
            if let durationType = currentEntry?["durationType"] as? String {
                duration = dateTimeUtils.getNowTimeIntervalUTC() - dateTimeStamp + (60 * 60)
            } else {
                duration = (currentEntry?["duration"] as? Double)!
                duration = duration * 60
            }
            
            // Skip overrides that aren't 5 minutes long. This prevents overlapping that causes bars to not display.
            if duration < 300 { continue }
            
            guard let enteredBy = currentEntry?["enteredBy"] as? String else { continue }
            guard let reason = currentEntry?["reason"] as? String else { continue }
            
            var range: [Int] = []
            if let ranges = currentEntry?["correctionRange"] as? [Int] {
                if ranges.count == 2 {
                    guard let low = ranges[0] as? Int else { continue }
                    guard let high = ranges[1] as? Int else { continue }
                    range.append(low)
                    range.append(high)
                }
                
            }
                        
            let endDate = dateTimeStamp + (duration)

            let dot = DataStructs.overrideStruct(insulNeedsScaleFactor: multiplier, date: dateTimeStamp, endDate: endDate, duration: duration, correctionRange: range, enteredBy: enteredBy, reason: reason, sgv: -20)
            overrideGraphData.append(dot)
            
            
        }
        if UserDefaultsRepository.graphOtherTreatments.value {
        updateOverrideGraph()
        }
        
    }
}
