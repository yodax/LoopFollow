//
//  Graphs.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/16/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation
import Charts
import UIKit

let ScaleXMax:Float = 150.0
extension UIColor {
   convenience init(red: Int, green: Int, blue: Int) {
       assert(red >= 0 && red <= 255, "Invalid red component")
       assert(green >= 0 && green <= 255, "Invalid green component")
       assert(blue >= 0 && blue <= 255, "Invalid blue component")

       self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
   }

   convenience init(rgb: Int) {
       self.init(
           red: (rgb >> 16) & 0xFF,
           green: (rgb >> 8) & 0xFF,
           blue: rgb & 0xFF
       )
   }
}

extension MainViewController {
    
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        if chartView == BGChartFull {
            BGChart.moveViewToX(entry.x)
        }
        if entry.data as? String == "hide"{
            BGChart.highlightValue(nil, callDelegate: false)
        }
        
    }
    
    func chartScaled(_ chartView: ChartViewBase, scaleX: CGFloat, scaleY: CGFloat) {
        print("Chart Scaled: \(BGChart.scaleX), \(BGChart.scaleY)")
      
        // dont store huge values
        var scale: Float = Float(BGChart.scaleX)
        if(scale > ScaleXMax ) {
            scale = ScaleXMax
        }
        UserDefaultsRepository.chartScaleX.value = Float(scale)
    }

    fileprivate func setupPredictionLine(_ linePrediction: LineChartDataSet, color: NSUIColor) {
        linePrediction.circleRadius = CGFloat(globalVariables.dotBG)
        linePrediction.circleColors = [color]
        linePrediction.colors = [color]
        linePrediction.drawCircleHoleEnabled = false
        linePrediction.axisDependency = YAxis.AxisDependency.right
        linePrediction.highlightEnabled = true
        linePrediction.drawValuesEnabled = false
        
        if UserDefaultsRepository.showLines.value {
            linePrediction.lineWidth = 2
        } else {
            linePrediction.lineWidth = 0
        }
        if UserDefaultsRepository.showDots.value {
            linePrediction.drawCirclesEnabled = true
        } else {
            linePrediction.drawCirclesEnabled = false
        }
        linePrediction.setDrawHighlightIndicators(false)
        linePrediction.valueFont.withSize(50)
    }
    
    func createGraph(){
        self.BGChart.clear()
        
        // Create the BG Graph Data
        let entries = bgData
        var bgChartEntry = [ChartDataEntry]()
        var colors = [NSUIColor]()
        var maxBG: Float = UserDefaultsRepository.minBGScale.value
        
        // Setup BG line details
        let lineBG = LineChartDataSet(entries:bgChartEntry, label: "")
        lineBG.circleRadius = CGFloat(globalVariables.dotBG)
        lineBG.circleColors = [NSUIColor.systemGreen]
        lineBG.drawCircleHoleEnabled = false
        lineBG.axisDependency = YAxis.AxisDependency.right
        lineBG.highlightEnabled = true
        lineBG.drawValuesEnabled = false
        
        if UserDefaultsRepository.showLines.value {
            lineBG.lineWidth = 2
        } else {
            lineBG.lineWidth = 0
        }
        if UserDefaultsRepository.showDots.value {
            lineBG.drawCirclesEnabled = true
        } else {
            lineBG.drawCirclesEnabled = false
        }
        lineBG.setDrawHighlightIndicators(false)
        lineBG.valueFont.withSize(50)
        
        // Setup Prediction line details
        var predictionChartEntry = [ChartDataEntry]()
        let linePrediction = LineChartDataSet(entries:predictionChartEntry, label: "")
        setupPredictionLine(linePrediction, color: NSUIColor.systemPurple)
        
        // create Basal graph data
        var chartEntry = [ChartDataEntry]()
        var maxBasal = UserDefaultsRepository.minBasalScale.value
        let lineBasal = LineChartDataSet(entries:chartEntry, label: "")
        lineBasal.setDrawHighlightIndicators(false)
        lineBasal.setColor(NSUIColor.systemBlue, alpha: 0.5)
        lineBasal.lineWidth = 0
        lineBasal.drawFilledEnabled = true
        lineBasal.fillColor = NSUIColor.systemBlue
        lineBasal.fillAlpha = 0.5
        lineBasal.drawCirclesEnabled = false
        lineBasal.axisDependency = YAxis.AxisDependency.left
        lineBasal.highlightEnabled = true
        lineBasal.drawValuesEnabled = false
        lineBasal.fillFormatter = basalFillFormatter()
        
        // Boluses
        var chartEntryBolus = [ChartDataEntry]()
        let lineBolus = LineChartDataSet(entries:chartEntryBolus, label: "")
        lineBolus.circleRadius = CGFloat(globalVariables.dotBolus)
        lineBolus.circleColors = [NSUIColor.systemBlue.withAlphaComponent(0.75)]
        lineBolus.drawCircleHoleEnabled = false
        lineBolus.setDrawHighlightIndicators(false)
        lineBolus.setColor(NSUIColor.systemBlue, alpha: 1.0)
        lineBolus.lineWidth = 0
        lineBolus.axisDependency = YAxis.AxisDependency.right
        lineBolus.valueFormatter = ChartYDataValueFormatter()
        lineBolus.valueTextColor = NSUIColor.label
        lineBolus.fillColor = NSUIColor.systemBlue
        lineBolus.fillAlpha = 0.6
        
            lineBolus.drawCirclesEnabled = true
            lineBolus.drawFilledEnabled = false
        
        if UserDefaultsRepository.showValues.value  {
            lineBolus.drawValuesEnabled = true
            lineBolus.highlightEnabled = false
        } else {
            lineBolus.drawValuesEnabled = false
            lineBolus.highlightEnabled = true
        }
        

        
        // Carbs
        var chartEntryCarbs = [ChartDataEntry]()
        let lineCarbs = LineChartDataSet(entries:chartEntryCarbs, label: "")
        lineCarbs.circleRadius = CGFloat(globalVariables.dotCarb)
        lineCarbs.circleColors = [NSUIColor.systemOrange.withAlphaComponent(0.75)]
        lineCarbs.drawCircleHoleEnabled = false
        lineCarbs.setDrawHighlightIndicators(false)
        lineCarbs.setColor(NSUIColor.systemBlue, alpha: 1.0)
        lineCarbs.lineWidth = 0
        lineCarbs.axisDependency = YAxis.AxisDependency.right
        lineCarbs.valueFormatter = ChartYDataValueFormatter()
        lineCarbs.valueTextColor = NSUIColor.label
        lineCarbs.fillColor = NSUIColor.systemOrange
        lineCarbs.fillAlpha = 0.6
       
            lineCarbs.drawCirclesEnabled = true
            lineCarbs.drawFilledEnabled = false
        
        if UserDefaultsRepository.showValues.value {
            lineCarbs.drawValuesEnabled = true
            lineCarbs.highlightEnabled = false
        } else {
            lineCarbs.drawValuesEnabled = false
            lineCarbs.highlightEnabled = true
        }
        
        
        // create Scheduled Basal graph data
        var chartBasalScheduledEntry = [ChartDataEntry]()
        let lineBasalScheduled = LineChartDataSet(entries:chartBasalScheduledEntry, label: "")
        lineBasalScheduled.setDrawHighlightIndicators(false)
        lineBasalScheduled.setColor(NSUIColor.systemBlue, alpha: 0.8)
        lineBasalScheduled.lineWidth = 2
        lineBasalScheduled.drawFilledEnabled = false
        lineBasalScheduled.drawCirclesEnabled = false
        lineBasalScheduled.axisDependency = YAxis.AxisDependency.left
        lineBasalScheduled.highlightEnabled = false
        lineBasalScheduled.drawValuesEnabled = false
        lineBasalScheduled.lineDashLengths = [10.0, 5.0]
        
        // create Override graph data
        var chartOverrideEntry = [ChartDataEntry]()
        let lineOverride = LineChartDataSet(entries:chartOverrideEntry, label: "")
        lineOverride.setDrawHighlightIndicators(false)
        lineOverride.lineWidth = 0
        lineOverride.drawFilledEnabled = true
        lineOverride.fillFormatter = OverrideFillFormatter()
        lineOverride.fillColor = NSUIColor.systemGreen
        lineOverride.fillAlpha = 0.6
        lineOverride.drawCirclesEnabled = false
        lineOverride.axisDependency = YAxis.AxisDependency.right
        lineOverride.highlightEnabled = true
        lineOverride.drawValuesEnabled = false
//        lineOverride.circleColors = [NSUIColor.systemGreen.withAlphaComponent(0.75)]
//        lineOverride.valueFormatter = ChartYDataValueFormatter()
//        lineOverride.drawCircleHoleEnabled = false
        
        // BG Check
        var chartEntryBGCheck = [ChartDataEntry]()
        let lineBGCheck = LineChartDataSet(entries:chartEntryBGCheck, label: "")
        lineBGCheck.circleRadius = CGFloat(globalVariables.dotOther)
        lineBGCheck.circleColors = [NSUIColor.systemRed.withAlphaComponent(0.75)]
        lineBGCheck.drawCircleHoleEnabled = false
        lineBGCheck.setDrawHighlightIndicators(false)
        lineBGCheck.setColor(NSUIColor.systemRed, alpha: 1.0)
        lineBGCheck.drawCirclesEnabled = true
        lineBGCheck.lineWidth = 0
        lineBGCheck.highlightEnabled = true
        lineBGCheck.axisDependency = YAxis.AxisDependency.right
        lineBGCheck.valueFormatter = ChartYDataValueFormatter()
        lineBGCheck.drawValuesEnabled = false
        
        // Suspend Pump
        var chartEntrySuspend = [ChartDataEntry]()
        let lineSuspend = LineChartDataSet(entries:chartEntrySuspend, label: "")
        lineSuspend.circleRadius = CGFloat(globalVariables.dotOther)
        lineSuspend.circleColors = [NSUIColor.systemTeal.withAlphaComponent(0.75)]
        lineSuspend.drawCircleHoleEnabled = false
        lineSuspend.setDrawHighlightIndicators(false)
        lineSuspend.setColor(NSUIColor.systemGray2, alpha: 1.0)
        lineSuspend.drawCirclesEnabled = true
        lineSuspend.lineWidth = 0
        lineSuspend.highlightEnabled = true
        lineSuspend.axisDependency = YAxis.AxisDependency.right
        lineSuspend.valueFormatter = ChartYDataValueFormatter()
        lineSuspend.drawValuesEnabled = false
        
        // Resume Pump
        var chartEntryResume = [ChartDataEntry]()
        let lineResume = LineChartDataSet(entries:chartEntryResume, label: "")
        lineResume.circleRadius = CGFloat(globalVariables.dotOther)
        lineResume.circleColors = [NSUIColor.systemTeal.withAlphaComponent(0.75)]
        lineResume.drawCircleHoleEnabled = false
        lineResume.setDrawHighlightIndicators(false)
        lineResume.setColor(NSUIColor.systemGray4, alpha: 1.0)
        lineResume.drawCirclesEnabled = true
        lineResume.lineWidth = 0
        lineResume.highlightEnabled = true
        lineResume.axisDependency = YAxis.AxisDependency.right
        lineResume.valueFormatter = ChartYDataValueFormatter()
        lineResume.drawValuesEnabled = false
        
        // Sensor Start
        var chartEntrySensor = [ChartDataEntry]()
        let lineSensor = LineChartDataSet(entries:chartEntrySensor, label: "")
        lineSensor.circleRadius = CGFloat(globalVariables.dotOther)
        lineSensor.circleColors = [NSUIColor.systemIndigo.withAlphaComponent(0.75)]
        lineSensor.drawCircleHoleEnabled = false
        lineSensor.setDrawHighlightIndicators(false)
        lineSensor.setColor(NSUIColor.systemGray3, alpha: 1.0)
        lineSensor.drawCirclesEnabled = true
        lineSensor.lineWidth = 0
        lineSensor.highlightEnabled = true
        lineSensor.axisDependency = YAxis.AxisDependency.right
        lineSensor.valueFormatter = ChartYDataValueFormatter()
        lineSensor.drawValuesEnabled = false
        
        // Notes
        var chartEntryNote = [ChartDataEntry]()
        let lineNote = LineChartDataSet(entries:chartEntryNote, label: "")
        lineNote.circleRadius = CGFloat(globalVariables.dotOther)
        lineNote.circleColors = [NSUIColor.systemGray.withAlphaComponent(0.75)]
        lineNote.drawCircleHoleEnabled = false
        lineNote.setDrawHighlightIndicators(false)
        lineNote.setColor(NSUIColor.systemGray3, alpha: 1.0)
        lineNote.drawCirclesEnabled = true
        lineNote.lineWidth = 0
        lineNote.highlightEnabled = true
        lineNote.axisDependency = YAxis.AxisDependency.right
        lineNote.valueFormatter = ChartYDataValueFormatter()
        lineNote.drawValuesEnabled = false
        
        var predictionCOBChartEntry = [ChartDataEntry]()
        let linePredictionCOB = LineChartDataSet(entries:predictionCOBChartEntry, label: "")
        setupPredictionLine(linePredictionCOB, color: NSUIColor.systemPurple)
        
        var predictionIOBChartEntry = [ChartDataEntry]()
        let linePredictionIOB = LineChartDataSet(entries:predictionIOBChartEntry, label: "")
        setupPredictionLine(linePredictionIOB, color: NSUIColor.systemBlue)
        
        
        var predictionZTChartEntry = [ChartDataEntry]()
        let linePredictionZT = LineChartDataSet(entries:predictionZTChartEntry, label: "")
        setupPredictionLine(linePredictionZT, color: NSUIColor.systemYellow)
        
        
        var predictionUAMChartEntry = [ChartDataEntry]()
        let linePredictionUAM = LineChartDataSet(entries:predictionUAMChartEntry, label: "")
        setupPredictionLine(linePredictionUAM, color: NSUIColor.systemOrange)
        
        // Setup the chart data of all lines
        let data = LineChartData()
        data.addDataSet(dataSet: lineBG) // Dataset 0
        data.addDataSet(dataSet: linePrediction) // Dataset 1
        data.addDataSet(dataSet: lineBasal) // Dataset 2
        data.addDataSet(dataSet: lineBolus) // Dataset 3
        data.addDataSet(dataSet: lineCarbs) // Dataset 4
        data.addDataSet(dataSet: lineBasalScheduled) // Dataset 5
        data.addDataSet(dataSet: lineOverride) // Dataset 6
        data.addDataSet(dataSet: lineBGCheck) // Dataset 7
        data.addDataSet(dataSet: lineSuspend) // Dataset 8
        data.addDataSet(dataSet: lineResume) // Dataset 9
        data.addDataSet(dataSet: lineSensor) // Dataset 10
        data.addDataSet(dataSet: lineNote) // Dataset 11
        data.addDataSet(dataSet: linePredictionCOB) // Dataset 12
        data.addDataSet(dataSet: linePredictionIOB) // Dataset 13
        data.addDataSet(dataSet: linePredictionZT) // Dataset 14
        data.addDataSet(dataSet: linePredictionUAM) // Dataset 15

        data.setValueFont(UIFont.systemFont(ofSize: 12))
        
        // Add marker popups for bolus and carbs
        let marker = PillMarker(color: .secondarySystemBackground, font: UIFont.boldSystemFont(ofSize: 14), textColor: .label)
        BGChart.marker = marker
        
        // Clear limit lines so they don't add multiples when changing the settings
        BGChart.rightAxis.removeAllLimitLines()
        
        //Add lower red line based on low alert value
        let ll = ChartLimitLine()
        ll.limit = Double(UserDefaultsRepository.lowLine.value)
        ll.lineColor = NSUIColor.systemRed.withAlphaComponent(0.5)
        BGChart.rightAxis.addLimitLine(ll)
        
        //Add upper yellow line based on low alert value
        let ul = ChartLimitLine()
        ul.limit = Double(UserDefaultsRepository.highLine.value)
        ul.lineColor = NSUIColor.systemYellow.withAlphaComponent(0.5)
        BGChart.rightAxis.addLimitLine(ul)
        
        // Add vertical lines as configured
        createVerticalLines()
        startGraphNowTimer()
        
        // Setup the main graph overall details
        BGChart.xAxis.valueFormatter = ChartXValueFormatter()
        BGChart.xAxis.granularity = 1800
        BGChart.xAxis.labelTextColor = NSUIColor.label
        BGChart.xAxis.labelPosition = XAxis.LabelPosition.bottom
        BGChart.xAxis.drawGridLinesEnabled = false
        
        BGChart.leftAxis.enabled = true
        BGChart.leftAxis.labelPosition = YAxis.LabelPosition.insideChart
        BGChart.leftAxis.axisMaximum = maxBasal
        BGChart.leftAxis.axisMinimum = 0
        BGChart.leftAxis.drawGridLinesEnabled = false
        BGChart.leftAxis.granularityEnabled = true
        BGChart.leftAxis.granularity = 0.5
        
        BGChart.rightAxis.labelTextColor = NSUIColor.label
        BGChart.rightAxis.labelPosition = YAxis.LabelPosition.insideChart
        BGChart.rightAxis.axisMinimum = 0.0
        BGChart.rightAxis.axisMaximum = Double(maxBG)
        BGChart.rightAxis.gridLineDashLengths = [5.0, 5.0]
        BGChart.rightAxis.drawGridLinesEnabled = false
        BGChart.rightAxis.valueFormatter = ChartYMMOLValueFormatter()
        BGChart.rightAxis.granularityEnabled = true
        BGChart.rightAxis.granularity = 50
        
        BGChart.maxHighlightDistance = 15.0
        BGChart.legend.enabled = false
        BGChart.scaleYEnabled = false
        BGChart.drawGridBackgroundEnabled = true
        BGChart.gridBackgroundColor = NSUIColor.secondarySystemBackground
        
        BGChart.highlightValue(nil, callDelegate: false)
        
        BGChart.data = data
        BGChart.setExtraOffsets(left: 10, top: 10, right: 10, bottom: 10)
        
    }
    
    func createVerticalLines() {
        BGChart.xAxis.removeAllLimitLines()
        BGChartFull.xAxis.removeAllLimitLines()
        createNowAndDIALines()
        createMidnightLines()
    }
    
    func createNowAndDIALines() {
        let ul = ChartLimitLine()
        ul.limit = Double(dateTimeUtils.getNowTimeIntervalUTC())
        ul.lineColor = NSUIColor.systemGray.withAlphaComponent(0.5)
        ul.lineWidth = 1
        BGChart.xAxis.addLimitLine(ul)
        
        
        if UserDefaultsRepository.showDIALines.value {
            for i in 1..<7 {
                let ul = ChartLimitLine()
                ul.limit = Double(dateTimeUtils.getNowTimeIntervalUTC() - Double(i * 60 * 60))
                ul.lineColor = NSUIColor.systemGray.withAlphaComponent(0.3)
                let dash = 10.0 - Double(i)
                let space = 5.0 + Double(i)
                ul.lineDashLengths = [CGFloat(dash), CGFloat(space)]
                ul.lineWidth = 1
                BGChart.xAxis.addLimitLine(ul)
            }
        }
    }
    
    func createMidnightLines() {
        // Draw a line at midnight: useful when showing multiple days of data
        if UserDefaultsRepository.showMidnightLines.value {
            var midnightTimeInterval = dateTimeUtils.getTimeIntervalMidnightToday()
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            let graphStart = dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours)
            while midnightTimeInterval > graphStart {
                // Large chart
                let ul = ChartLimitLine()
                ul.limit = Double(midnightTimeInterval)
                ul.lineColor = NSUIColor.systemTeal.withAlphaComponent(0.5)
                ul.lineDashLengths = [CGFloat(2), CGFloat(5)]
                ul.lineWidth = 1
                BGChart.xAxis.addLimitLine(ul)

                // Small chart
                let sl = ChartLimitLine()
                sl.limit = Double(midnightTimeInterval)
                sl.lineColor = NSUIColor.systemTeal
                sl.lineDashLengths = [CGFloat(2), CGFloat(2)]
                sl.lineWidth = 1
                BGChartFull.xAxis.addLimitLine(sl)
                
                midnightTimeInterval = midnightTimeInterval.advanced(by: -24*60*60)
            }
        }
    }
    
    func updateBGGraphSettings() {
        let dataIndex = 0
        let dataIndexPrediction = 1
        let lineBG = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet
        let linePrediction = BGChart.lineData!.dataSets[dataIndexPrediction] as! LineChartDataSet
        if UserDefaultsRepository.showLines.value {
            lineBG.lineWidth = 2
            linePrediction.lineWidth = 2
        } else {
            lineBG.lineWidth = 0
            linePrediction.lineWidth = 0
        }
        if UserDefaultsRepository.showDots.value {
            lineBG.drawCirclesEnabled = true
            linePrediction.drawCirclesEnabled = true
        } else {
            lineBG.drawCirclesEnabled = false
            linePrediction.drawCirclesEnabled = false
        }
        
        BGChart.rightAxis.axisMinimum = 0
        
        // Clear limit lines so they don't add multiples when changing the settings
        BGChart.rightAxis.removeAllLimitLines()
        
        //Add lower red line based on low alert value
        let ll = ChartLimitLine()
        ll.limit = Double(UserDefaultsRepository.lowLine.value)
        ll.lineColor = NSUIColor.systemRed.withAlphaComponent(0.5)
        BGChart.rightAxis.addLimitLine(ll)
        
        //Add upper yellow line based on low alert value
        let ul = ChartLimitLine()
        ul.limit = Double(UserDefaultsRepository.highLine.value)
        ul.lineColor = NSUIColor.systemYellow.withAlphaComponent(0.5)
        BGChart.rightAxis.addLimitLine(ul)
        
        // Re-create vertical markers in case their settings changed
        createVerticalLines()
    
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        
    }
    
    func updateBGGraph() {
        if UserDefaultsRepository.debugLog.value { writeDebugLog(value: "##### Start BG Graph #####") }
        let dataIndex = 0
        let entries = bgData
        if entries.count < 1 { return }
        var mainChart = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet
        var smallChart = BGChartFull.lineData!.dataSets[dataIndex] as! LineChartDataSet
        mainChart.clear()
        smallChart.clear()
        var maxBGOffset: Float = 50
        
        var colors = [NSUIColor]()
        for i in 0..<entries.count{
            if Float(entries[i].sgv) > topBG - maxBGOffset {
                topBG = Float(entries[i].sgv) + maxBGOffset
            }
            let value = ChartDataEntry(x: Double(entries[i].date), y: Double(entries[i].sgv), data: formatPillText(line1: bgUnits.toDisplayUnits(String(entries[i].sgv)), time: entries[i].date))
            if UserDefaultsRepository.debugLog.value { writeDebugLog(value: "BG: " + value.description) }
            mainChart.addEntry(value)
            smallChart.addEntry(value)
            
            if Double(entries[i].sgv) >= Double(UserDefaultsRepository.highLine.value) {
                colors.append(NSUIColor.systemYellow)
            } else if Double(entries[i].sgv) <= Double(UserDefaultsRepository.lowLine.value) {
               colors.append(NSUIColor.systemRed)
            } else {
                colors.append(NSUIColor.systemGreen)
            }
        }
        
        if UserDefaultsRepository.debugLog.value { writeDebugLog(value: "Total Graph BGs: " + mainChart.entries.count.description) }
        
        
        // Set Colors
        let lineBG = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet

        let lineBGSmall = BGChartFull.lineData!.dataSets[dataIndex] as! LineChartDataSet
        lineBG.colors.removeAll()
        lineBG.circleColors.removeAll()
        lineBGSmall.colors.removeAll()
        lineBGSmall.circleColors.removeAll()

        if colors.count > 0 {
            for i in 0..<colors.count{
                mainChart.addColor(colors[i])
                mainChart.circleColors.append(colors[i])
                smallChart.addColor(colors[i])
                smallChart.circleColors.append(colors[i])
            }
        }
        
        if UserDefaultsRepository.debugLog.value { writeDebugLog(value: "Total Colors: " + mainChart.colors.count.description) }
        
        BGChart.rightAxis.axisMaximum = Double(topBG)
        BGChart.setVisibleXRangeMinimum(600)
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        BGChartFull.rightAxis.axisMaximum = Double(topBG)
        BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChartFull.data?.notifyDataChanged()
        BGChartFull.notifyDataSetChanged()
        
        if firstGraphLoad {
            var scaleX = CGFloat(UserDefaultsRepository.chartScaleX.value)
            print("Scale: \(scaleX)")
            if( scaleX > CGFloat(ScaleXMax) ) {
                scaleX = CGFloat(ScaleXMax)
                UserDefaultsRepository.chartScaleX.value = ScaleXMax
            }
            BGChart.zoom(scaleX: scaleX, scaleY: 1, x: 1, y: 1)
            firstGraphLoad = false
        }
        
        // Move to current reading everytime new readings load
        BGChart.moveViewToAnimated(xValue: dateTimeUtils.getNowTimeIntervalUTC() - (BGChart.visibleXRange * 0.7), yValue: 0.0, axis: .right, duration: 1, easingOption: .easeInBack)
    }
    
    fileprivate func updatePredictionsFor(_ maxBGOffset: Float, _ colors: inout [UIColor], _ mainChart: LineChartDataSet, _ smallChart: LineChartDataSet, predictionData: [ShareGlucoseData], color: NSUIColor) {
        for i in 0..<predictionData.count {
            var predictionVal = Double(predictionData[i].sgv)
            if Float(predictionVal) > topBG - maxBGOffset {
                topBG = Float(predictionVal) + maxBGOffset
            }
            
            if i == 0 {
                if UserDefaultsRepository.showDots.value {
                    colors.append(color.withAlphaComponent(0.0))
                } else {
                    colors.append(color.withAlphaComponent(1.0))
                }
                
            } else if predictionVal > 400 {
                predictionVal = 400
                colors.append(NSUIColor.systemYellow)
            } else if predictionVal < 0 {
                predictionVal = 0
                colors.append(NSUIColor.systemRed)
            } else {
                colors.append(color)
            }
            let value = ChartDataEntry(x: predictionData[i].date, y: predictionVal, data: formatPillText(line1: bgUnits.toDisplayUnits(String(predictionData[i].sgv)), time: predictionData[i].date))
            mainChart.addEntry(value)
            smallChart.addEntry(value)
        }
    }
    
    fileprivate func updatePredChart(_ dataIndex: Int, predictionData: [ShareGlucoseData], color: NSUIColor) {
        let mainChart = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet
        let smallChart = BGChartFull.lineData!.dataSets[dataIndex] as! LineChartDataSet
        
        mainChart.clear()
        smallChart.clear()
        if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Graph: print prediction") }
        
        var colors = [NSUIColor]()
        let maxBGOffset: Float = 20
        updatePredictionsFor(maxBGOffset, &colors, mainChart, smallChart, predictionData: predictionData, color: color)
        
        smallChart.circleColors.removeAll()
        smallChart.colors.removeAll()
        mainChart.colors.removeAll()
        mainChart.circleColors.removeAll()
        if colors.count > 0 {
            if UserDefaultsRepository.debugLog.value { self.writeDebugLog(value: "Graph: prediction colors") }
            for i in 0..<colors.count{
                mainChart.addColor(colors[i])
                mainChart.circleColors.append(colors[i])
                smallChart.addColor(colors[i])
                smallChart.circleColors.append(colors[i])
            }
        }
        BGChart.rightAxis.axisMaximum = Double(topBG)
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChartFull.data?.notifyDataChanged()
        BGChartFull.notifyDataSetChanged()
    }
    
    func updatePredictionGraph() {
        updatePredChart(12, predictionData: predictionDataCOB, color: UIColor(rgb: 0xFB8C00))
        updatePredChart(13, predictionData: predictionDataIOB, color: UIColor(rgb: 0x1e88e5))
        updatePredChart(14, predictionData: predictionDataZT, color: UIColor(rgb: 0x00d2d2))
        updatePredChart(15, predictionData: predictionDataUAM, color: UIColor(rgb: 0xc9bd60))
    }
    
    func updateBasalGraph() {
        var dataIndex = 2
        BGChart.lineData?.dataSets[dataIndex].clear()
        BGChartFull.lineData?.dataSets[dataIndex].clear()
        var maxBasal = UserDefaultsRepository.minBasalScale.value
        var maxBasalSmall: Double = 0.0
        for i in 0..<basalData.count{
            let value = ChartDataEntry(x: Double(basalData[i].date), y: Double(basalData[i].basalRate), data: formatPillText(line1: String(basalData[i].basalRate), time: basalData[i].date))
            BGChart.data?.dataSets[dataIndex].addEntry(value)
            if UserDefaultsRepository.smallGraphTreatments.value {
                BGChartFull.data?.dataSets[dataIndex].addEntry(value)
            }
            if basalData[i].basalRate  > maxBasal {
                maxBasal = basalData[i].basalRate
            }
            if basalData[i].basalRate > maxBasalSmall {
                maxBasalSmall = basalData[i].basalRate
            }
        }
        
        BGChart.leftAxis.axisMaximum = maxBasal
        BGChartFull.leftAxis.axisMaximum = maxBasalSmall
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        
        if UserDefaultsRepository.smallGraphTreatments.value {
            BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func updateBasalScheduledGraph() {
        var dataIndex = 5
        BGChart.lineData?.dataSets[dataIndex].clear()
        BGChartFull.lineData?.dataSets[dataIndex].clear()
        for i in 0..<basalScheduleData.count{
            let value = ChartDataEntry(x: Double(basalScheduleData[i].date), y: Double(basalScheduleData[i].basalRate))
            BGChart.data?.dataSets[dataIndex].addEntry(value)
            if UserDefaultsRepository.smallGraphTreatments.value {
                BGChartFull.data?.dataSets[dataIndex].addEntry(value)
            }
        }
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value {
            BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func updateBolusGraph() {
        var dataIndex = 3
        var yTop: Double = 370
        var yBottom: Double = 345
        var mainChart = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet
        var smallChart = BGChartFull.lineData!.dataSets[dataIndex] as! LineChartDataSet
        mainChart.clear()
        smallChart.clear()
        
        var colors = [NSUIColor]()
        for i in 0..<bolusData.count{
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 2
            formatter.minimumIntegerDigits = 0
            
            // Check overlapping carbs to shift left if needed
            let bolusShift = findNextBolusTime(timeWithin: 240, needle: bolusData[i].date, haystack: bolusData, startingIndex: i)
            var dateTimeStamp = bolusData[i].date
            
            // Alpha colors for DIA
            let nowTime = dateTimeUtils.getNowTimeIntervalUTC()
            let diffTimeHours = (nowTime - dateTimeStamp) / 60 / 60
            if diffTimeHours <= 1 {
                colors.append(NSUIColor.systemBlue.withAlphaComponent(1.0))
            } else if diffTimeHours > 6 {
                colors.append(NSUIColor.systemBlue.withAlphaComponent(0.25))
            } else {
                let thisAlpha = 1.0 - (0.15 * diffTimeHours)
                colors.append(NSUIColor.systemBlue.withAlphaComponent(CGFloat(thisAlpha)))
            }
            
            if bolusShift {
                // Move it half the distance between BG readings
                dateTimeStamp = dateTimeStamp - 150
            }
            
            // skip if outside of visible area
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            if dateTimeStamp < dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) { continue }
  
            let dot = ChartDataEntry(x: Double(dateTimeStamp), y: Double(bolusData[i].sgv), data: formatter.string(from: NSNumber(value: bolusData[i].value)))
            mainChart.addEntry(dot)
            if UserDefaultsRepository.smallGraphTreatments.value {
                smallChart.addEntry(dot)
            }
        }
        
        // Set Colors
        let lineBolus = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet
        let lineBolusSmall = BGChartFull.lineData!.dataSets[dataIndex] as! LineChartDataSet
        lineBolus.colors.removeAll()
        lineBolus.circleColors.removeAll()
        lineBolusSmall.colors.removeAll()
        lineBolusSmall.circleColors.removeAll()
        
        if colors.count > 0 {
            for i in 0..<colors.count{
                mainChart.addColor(colors[i])
                mainChart.circleColors.append(colors[i])
                smallChart.addColor(colors[i])
                smallChart.circleColors.append(colors[i])
            }
        }
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value {
            BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func updateCarbGraph() {
        var dataIndex = 4
        var mainChart = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet
        var smallChart = BGChartFull.lineData!.dataSets[dataIndex] as! LineChartDataSet
        mainChart.clear()
        smallChart.clear()
        
        var colors = [NSUIColor]()
        for i in 0..<carbData.count{
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 2
            formatter.minimumIntegerDigits = 1

            
            var valueString: String = formatter.string(from: NSNumber(value: carbData[i].value))!
            
            var hours = 3
            if carbData[i].absorptionTime > 0 && UserDefaultsRepository.showAbsorption.value {
                hours = carbData[i].absorptionTime / 60
                valueString += " " + String(hours) + "h"
            }
            
            // Check overlapping carbs to shift left if needed
            let carbShift = findNextCarbTime(timeWithin: 250, needle: carbData[i].date, haystack: carbData, startingIndex: i)
            var dateTimeStamp = carbData[i].date
            
            // Alpha colors for DIA
            let nowTime = dateTimeUtils.getNowTimeIntervalUTC()
            let diffTimeHours = (nowTime - dateTimeStamp) / 60 / 60
            if diffTimeHours <= 0.5 {
                colors.append(NSUIColor.systemOrange.withAlphaComponent(1.0))
            } else if diffTimeHours > Double(hours) {
                colors.append(NSUIColor.systemOrange.withAlphaComponent(0.25))
            } else {
                let thisAlpha = 1.0 - ((0.75 / Double(hours)) * diffTimeHours)
                colors.append(NSUIColor.systemOrange.withAlphaComponent(CGFloat(thisAlpha)))
            }
            
            // skip if outside of visible area
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            if dateTimeStamp < dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) { continue }
            
            if carbShift {
                dateTimeStamp = dateTimeStamp - 250
            }
            
            
            let dot = ChartDataEntry(x: Double(dateTimeStamp), y: Double(carbData[i].sgv), data: valueString)
            BGChart.data?.dataSets[dataIndex].addEntry(dot)
            if UserDefaultsRepository.smallGraphTreatments.value {
                BGChartFull.data?.dataSets[dataIndex].addEntry(dot)
            }
            
            

        }
        
        // Set Colors
        let lineCarbs = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet
        let lineCarbsSmall = BGChartFull.lineData!.dataSets[dataIndex] as! LineChartDataSet
        lineCarbs.colors.removeAll()
        lineCarbs.circleColors.removeAll()
        lineCarbsSmall.colors.removeAll()
        lineCarbsSmall.circleColors.removeAll()
        
        if colors.count > 0 {
            for i in 0..<colors.count{
                mainChart.addColor(colors[i])
                mainChart.circleColors.append(colors[i])
                smallChart.addColor(colors[i])
                smallChart.circleColors.append(colors[i])
            }
        }
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value {
            BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func updateBGCheckGraph() {
        var dataIndex = 7
        BGChart.lineData?.dataSets[dataIndex].clear()
        BGChartFull.lineData?.dataSets[dataIndex].clear()
        
        for i in 0..<bgCheckData.count{
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 2
            formatter.minimumIntegerDigits = 1
            
            // skip if outside of visible area
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            if bgCheckData[i].date < dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) { continue }
            
            let value = ChartDataEntry(x: Double(bgCheckData[i].date), y: Double(bgCheckData[i].sgv * 18), data: formatPillText(line1: String(bgCheckData[i].sgv), time: bgCheckData[i].date))
            BGChart.data?.dataSets[dataIndex].addEntry(value)
            if UserDefaultsRepository.smallGraphTreatments.value {
                BGChartFull.data?.dataSets[dataIndex].addEntry(value)
            }

        }
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value {
            BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func updateSuspendGraph() {
        var dataIndex = 8
        BGChart.lineData?.dataSets[dataIndex].clear()
        BGChartFull.lineData?.dataSets[dataIndex].clear()
        let thisData = suspendGraphData
        for i in 0..<thisData.count{
            // skip if outside of visible area
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            if thisData[i].date < dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) { continue }
            
            let value = ChartDataEntry(x: Double(thisData[i].date), y: Double(thisData[i].sgv), data: formatPillText(line1: "Suspend Pump", time: thisData[i].date))
            BGChart.data?.dataSets[dataIndex].addEntry(value)
            if UserDefaultsRepository.smallGraphTreatments.value {
                BGChartFull.data?.dataSets[dataIndex].addEntry(value)
            }
        }
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value {
            BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func updateResumeGraph() {
        var dataIndex = 9
        BGChart.lineData?.dataSets[dataIndex].clear()
        BGChartFull.lineData?.dataSets[dataIndex].clear()
        let thisData = resumeGraphData
        for i in 0..<thisData.count{
            // skip if outside of visible area
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            if thisData[i].date < dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) { continue }
            
            let value = ChartDataEntry(x: Double(thisData[i].date), y: Double(thisData[i].sgv), data: formatPillText(line1: "Resume Pump", time: thisData[i].date))
            BGChart.data?.dataSets[dataIndex].addEntry(value)
            if UserDefaultsRepository.smallGraphTreatments.value {
                BGChartFull.data?.dataSets[dataIndex].addEntry(value)
            }
        }
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value {
            BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func updateSensorStart() {
        var dataIndex = 10
        BGChart.lineData?.dataSets[dataIndex].clear()
        BGChartFull.lineData?.dataSets[dataIndex].clear()
        let thisData = sensorStartGraphData
        for i in 0..<thisData.count{
            // skip if outside of visible area
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            if thisData[i].date < dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) { continue }
            
            let value = ChartDataEntry(x: Double(thisData[i].date), y: Double(thisData[i].sgv), data: formatPillText(line1: "Start Sensor", time: thisData[i].date))
            BGChart.data?.dataSets[dataIndex].addEntry(value)
            if UserDefaultsRepository.smallGraphTreatments.value {
                BGChartFull.data?.dataSets[dataIndex].addEntry(value)
            }
        }
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value {
            BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func updateNotes() {
        var dataIndex = 11
        BGChart.lineData?.dataSets[dataIndex].clear()
        BGChartFull.lineData?.dataSets[dataIndex].clear()
        let thisData = noteGraphData
        for i in 0..<thisData.count{
            
            // skip if outside of visible area
            let graphHours = 24 * UserDefaultsRepository.downloadDays.value
            if thisData[i].date < dateTimeUtils.getTimeIntervalNHoursAgo(N: graphHours) { continue }
            
            let value = ChartDataEntry(x: Double(thisData[i].date), y: Double(thisData[i].sgv), data: formatPillText(line1: thisData[i].note, time: thisData[i].date))
            BGChart.data?.dataSets[dataIndex].addEntry(value)
            if UserDefaultsRepository.smallGraphTreatments.value {
                BGChartFull.data?.dataSets[dataIndex].addEntry(value)
            }
        }
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value {
            BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
 
    fileprivate func setupPredictionLine2(_ linePrediction: LineChartDataSet, color: NSUIColor) {
        linePrediction.drawCirclesEnabled = false
        //line2.setDrawHighlightIndicators(false)
        linePrediction.setColor(color)
        linePrediction.highlightEnabled = true
        linePrediction.drawHorizontalHighlightIndicatorEnabled = false
        linePrediction.drawVerticalHighlightIndicatorEnabled = false
        linePrediction.highlightColor = NSUIColor.label
        linePrediction.drawValuesEnabled = false
        linePrediction.lineWidth = 1.5
        linePrediction.axisDependency = YAxis.AxisDependency.right
    }
    
    func createSmallBGGraph(){
        let entries = bgData
       var bgChartEntry = [ChartDataEntry]()
       var colors = [NSUIColor]()
        var maxBG: Float = UserDefaultsRepository.minBGScale.value
        
        let lineBG = LineChartDataSet(entries:bgChartEntry, label: "")
        
        lineBG.drawCirclesEnabled = false
        //line2.setDrawHighlightIndicators(false)
        lineBG.highlightEnabled = true
        lineBG.drawHorizontalHighlightIndicatorEnabled = false
        lineBG.drawVerticalHighlightIndicatorEnabled = false
        lineBG.highlightColor = NSUIColor.label
        lineBG.drawValuesEnabled = false
        lineBG.lineWidth = 1.5
        lineBG.axisDependency = YAxis.AxisDependency.right
        
        // Setup Prediction line details
        var predictionChartEntry = [ChartDataEntry]()
        let linePrediction = LineChartDataSet(entries:predictionChartEntry, label: "")
        setupPredictionLine2(linePrediction, color: NSUIColor.systemPurple)
        
        // create Basal graph data
        var chartEntry = [ChartDataEntry]()
        var maxBasal = UserDefaultsRepository.minBasalScale.value
        let lineBasal = LineChartDataSet(entries:chartEntry, label: "")
        lineBasal.setDrawHighlightIndicators(false)
        lineBasal.setColor(NSUIColor.systemBlue, alpha: 0.5)
        lineBasal.lineWidth = 0
        lineBasal.drawFilledEnabled = true
        lineBasal.fillColor = NSUIColor.systemBlue
        lineBasal.fillAlpha = 0.35
        lineBasal.drawCirclesEnabled = false
        lineBasal.axisDependency = YAxis.AxisDependency.left
        lineBasal.highlightEnabled = false
        lineBasal.drawValuesEnabled = false
        lineBasal.fillFormatter = basalFillFormatter()
        
        // Boluses
        var chartEntryBolus = [ChartDataEntry]()
        let lineBolus = LineChartDataSet(entries:chartEntryBolus, label: "")
        lineBolus.circleRadius = 2
        lineBolus.circleColors = [NSUIColor.systemBlue.withAlphaComponent(0.75)]
        lineBolus.drawCircleHoleEnabled = false
        lineBolus.setDrawHighlightIndicators(false)
        lineBolus.setColor(NSUIColor.systemBlue, alpha: 1.0)
        lineBolus.lineWidth = 0
        lineBolus.axisDependency = YAxis.AxisDependency.right
        lineBolus.valueFormatter = ChartYDataValueFormatter()
        lineBolus.valueTextColor = NSUIColor.label
        lineBolus.fillColor = NSUIColor.systemBlue
        lineBolus.fillAlpha = 0.6
        lineBolus.drawCirclesEnabled = true
        lineBolus.drawFilledEnabled = false
        lineBolus.drawValuesEnabled = false
        lineBolus.highlightEnabled = false
        

        
        // Carbs
        var chartEntryCarbs = [ChartDataEntry]()
        let lineCarbs = LineChartDataSet(entries:chartEntryCarbs, label: "")
        lineCarbs.circleRadius = 2
        lineCarbs.circleColors = [NSUIColor.systemOrange.withAlphaComponent(0.75)]
        lineCarbs.drawCircleHoleEnabled = false
        lineCarbs.setDrawHighlightIndicators(false)
        lineCarbs.setColor(NSUIColor.systemBlue, alpha: 1.0)
        lineCarbs.lineWidth = 0
        lineCarbs.axisDependency = YAxis.AxisDependency.right
        lineCarbs.valueFormatter = ChartYDataValueFormatter()
        lineCarbs.valueTextColor = NSUIColor.label
        lineCarbs.fillColor = NSUIColor.systemOrange
        lineCarbs.fillAlpha = 0.6
        lineCarbs.drawCirclesEnabled = true
        lineCarbs.drawFilledEnabled = false
        lineCarbs.drawValuesEnabled = false
        lineCarbs.highlightEnabled = false
        
        
        
        // create Scheduled Basal graph data
        var chartBasalScheduledEntry = [ChartDataEntry]()
        let lineBasalScheduled = LineChartDataSet(entries:chartBasalScheduledEntry, label: "")
        lineBasalScheduled.setDrawHighlightIndicators(false)
        lineBasalScheduled.setColor(NSUIColor.systemBlue, alpha: 0.8)
        lineBasalScheduled.lineWidth = 0.5
        lineBasalScheduled.drawFilledEnabled = false
        lineBasalScheduled.drawCirclesEnabled = false
        lineBasalScheduled.axisDependency = YAxis.AxisDependency.left
        lineBasalScheduled.highlightEnabled = false
        lineBasalScheduled.drawValuesEnabled = false
        lineBasalScheduled.lineDashLengths = [2, 1]
        
        // create Override graph data
        var chartOverrideEntry = [ChartDataEntry]()
        let lineOverride = LineChartDataSet(entries:chartOverrideEntry, label: "")
        lineOverride.setDrawHighlightIndicators(false)
        lineOverride.lineWidth = 0
        lineOverride.drawFilledEnabled = true
        lineOverride.fillFormatter = OverrideFillFormatter()
        lineOverride.fillColor = NSUIColor.systemGreen
        lineOverride.fillAlpha = 0.6
        lineOverride.drawCirclesEnabled = false
        lineOverride.axisDependency = YAxis.AxisDependency.right
        lineOverride.highlightEnabled = true
        lineOverride.drawValuesEnabled = false
        
        // BG Check
        var chartEntryBGCheck = [ChartDataEntry]()
        let lineBGCheck = LineChartDataSet(entries:chartEntryBGCheck, label: "")
        lineBGCheck.circleRadius = 2
        lineBGCheck.circleColors = [NSUIColor.systemRed.withAlphaComponent(0.75)]
        lineBGCheck.drawCircleHoleEnabled = false
        lineBGCheck.setDrawHighlightIndicators(false)
        lineBGCheck.setColor(NSUIColor.systemRed, alpha: 1.0)
        lineBGCheck.drawCirclesEnabled = true
        lineBGCheck.lineWidth = 0
        lineBGCheck.highlightEnabled = false
        lineBGCheck.axisDependency = YAxis.AxisDependency.right
        lineBGCheck.valueFormatter = ChartYDataValueFormatter()
        lineBGCheck.drawValuesEnabled = false
        
        // Suspend Pump
        var chartEntrySuspend = [ChartDataEntry]()
        let lineSuspend = LineChartDataSet(entries:chartEntrySuspend, label: "")
        lineSuspend.circleRadius = 2
        lineSuspend.circleColors = [NSUIColor.systemTeal.withAlphaComponent(0.75)]
        lineSuspend.drawCircleHoleEnabled = false
        lineSuspend.setDrawHighlightIndicators(false)
        lineSuspend.setColor(NSUIColor.systemGray2, alpha: 1.0)
        lineSuspend.drawCirclesEnabled = true
        lineSuspend.lineWidth = 0
        lineSuspend.highlightEnabled = false
        lineSuspend.axisDependency = YAxis.AxisDependency.right
        lineSuspend.valueFormatter = ChartYDataValueFormatter()
        lineSuspend.drawValuesEnabled = false
        
        // Resume Pump
        var chartEntryResume = [ChartDataEntry]()
        let lineResume = LineChartDataSet(entries:chartEntryResume, label: "")
        lineResume.circleRadius = 2
        lineResume.circleColors = [NSUIColor.systemTeal.withAlphaComponent(0.75)]
        lineResume.drawCircleHoleEnabled = false
        lineResume.setDrawHighlightIndicators(false)
        lineResume.setColor(NSUIColor.systemGray4, alpha: 1.0)
        lineResume.drawCirclesEnabled = true
        lineResume.lineWidth = 0
        lineResume.highlightEnabled = false
        lineResume.axisDependency = YAxis.AxisDependency.right
        lineResume.valueFormatter = ChartYDataValueFormatter()
        lineResume.drawValuesEnabled = false
        
        // Sensor Start
        var chartEntrySensor = [ChartDataEntry]()
        let lineSensor = LineChartDataSet(entries:chartEntrySensor, label: "")
        lineSensor.circleRadius = 2
        lineSensor.circleColors = [NSUIColor.systemIndigo.withAlphaComponent(0.75)]
        lineSensor.drawCircleHoleEnabled = false
        lineSensor.setDrawHighlightIndicators(false)
        lineSensor.setColor(NSUIColor.systemGray3, alpha: 1.0)
        lineSensor.drawCirclesEnabled = true
        lineSensor.lineWidth = 0
        lineSensor.highlightEnabled = false
        lineSensor.axisDependency = YAxis.AxisDependency.right
        lineSensor.valueFormatter = ChartYDataValueFormatter()
        lineSensor.drawValuesEnabled = false
        
        // Notes
        var chartEntryNote = [ChartDataEntry]()
        let lineNote = LineChartDataSet(entries:chartEntryNote, label: "")
        lineNote.circleRadius = 2
        lineNote.circleColors = [NSUIColor.systemGray.withAlphaComponent(0.75)]
        lineNote.drawCircleHoleEnabled = false
        lineNote.setDrawHighlightIndicators(false)
        lineNote.setColor(NSUIColor.systemGray3, alpha: 1.0)
        lineNote.drawCirclesEnabled = true
        lineNote.lineWidth = 0
        lineNote.highlightEnabled = false
        lineNote.axisDependency = YAxis.AxisDependency.right
        lineNote.valueFormatter = ChartYDataValueFormatter()
        lineNote.drawValuesEnabled = false
        
        let predictionCOBChartEntry = [ChartDataEntry]()
        let linePredictionCOB = LineChartDataSet(entries:predictionCOBChartEntry, label: "")
        setupPredictionLine2(linePredictionCOB, color: NSUIColor.systemPurple)
        
        let predictionIOBChartEntry = [ChartDataEntry]()
        let linePredictionIOB = LineChartDataSet(entries:predictionIOBChartEntry, label: "")
        setupPredictionLine2(linePredictionIOB, color: UIColor(rgb: 0x1e88e5))
        
        
        let predictionZTChartEntry = [ChartDataEntry]()
        let linePredictionZT = LineChartDataSet(entries:predictionZTChartEntry, label: "")
        setupPredictionLine2(linePredictionZT, color: NSUIColor.systemYellow)
        
        
        let predictionUAMChartEntry = [ChartDataEntry]()
        let linePredictionUAM = LineChartDataSet(entries:predictionUAMChartEntry, label: "")
        setupPredictionLine2(linePredictionUAM, color: NSUIColor.systemOrange)
        
        // Setup the chart data of all lines
        let data = LineChartData()
        data.addDataSet(dataSet: lineBG) // Dataset 0
        data.addDataSet(dataSet: linePrediction) // Dataset 1
        data.addDataSet(dataSet: lineBasal) // Dataset 2
        data.addDataSet(dataSet: lineBolus) // Dataset 3
        data.addDataSet(dataSet: lineCarbs) // Dataset 4
        data.addDataSet(dataSet: lineBasalScheduled) // Dataset 5
        data.addDataSet(dataSet: lineOverride) // Dataset 6
        data.addDataSet(dataSet: lineBGCheck) // Dataset 7
        data.addDataSet(dataSet: lineSuspend) // Dataset 8
        data.addDataSet(dataSet: lineResume) // Dataset 9
        data.addDataSet(dataSet: lineSensor) // Dataset 10
        data.addDataSet(dataSet: lineNote) // Dataset 11
        data.addDataSet(dataSet: linePredictionCOB) // Dataset 12
        data.addDataSet(dataSet: linePredictionIOB) // Dataset 13
        data.addDataSet(dataSet: linePredictionZT) // Dataset 14
        data.addDataSet(dataSet: linePredictionUAM) // Dataset 15
        
        BGChartFull.highlightPerDragEnabled = true
        BGChartFull.leftAxis.enabled = false
        BGChartFull.leftAxis.axisMaximum = maxBasal
        BGChartFull.leftAxis.axisMinimum = 0
        
        BGChartFull.rightAxis.enabled = false
        BGChartFull.rightAxis.axisMinimum = 0.0
        BGChartFull.rightAxis.axisMaximum = Double(maxBG)
                                               
        BGChartFull.xAxis.drawLabelsEnabled = false
        BGChartFull.xAxis.drawGridLinesEnabled = false
        BGChartFull.xAxis.drawAxisLineEnabled = false
        BGChartFull.legend.enabled = false
        BGChartFull.scaleYEnabled = false
        BGChartFull.scaleXEnabled = false
        BGChartFull.drawGridBackgroundEnabled = false
        BGChartFull.data = data
        
        
    }
    
    func updateOverrideGraph() {
        var dataIndex = 6
        var yTop: Double = Double(topBG - 5)
        var yBottom: Double = Double(topBG - 25)
        var chart = BGChart.lineData!.dataSets[dataIndex] as! LineChartDataSet
        var smallChart = BGChartFull.lineData!.dataSets[dataIndex] as! LineChartDataSet
        chart.clear()
        smallChart.clear()
        let thisData = overrideGraphData
        
        var colors = [NSUIColor]()
        for i in 0..<thisData.count{
            let thisItem = thisData[i]
            let multiplier = thisItem.insulNeedsScaleFactor as! Double * 100.0
            var labelText = thisItem.reason + "\r\n"
            labelText += String(Int(thisItem.insulNeedsScaleFactor * 100)) + "% "
            if thisItem.correctionRange.count == 2 {
                labelText += String(thisItem.correctionRange[0]) + "-" + String(thisItem.correctionRange[1])
            }
            if thisItem.enteredBy.count > 0 {
                labelText += "\r\nEntered By: " + thisItem.enteredBy
            }
            
            
            // Start Dot
            // Shift dots 30 seconds to create an empty 0 space between consecutive temps
            let preStartDot = ChartDataEntry(x: Double(thisItem.date), y: yBottom, data: labelText)
            BGChart.data?.dataSets[dataIndex].addEntry(preStartDot)
            if UserDefaultsRepository.smallGraphTreatments.value {
                BGChartFull.data?.dataSets[dataIndex].addEntry(preStartDot)
            }
            
            let startDot = ChartDataEntry(x: Double(thisItem.date + 1), y: yTop, data: labelText)
            BGChart.data?.dataSets[dataIndex].addEntry(startDot)
            if UserDefaultsRepository.smallGraphTreatments.value {
                BGChartFull.data?.dataSets[dataIndex].addEntry(startDot)
            }

            // End Dot
            let endDot = ChartDataEntry(x: Double(thisItem.endDate - 2), y: yTop, data: labelText)
            BGChart.data?.dataSets[dataIndex].addEntry(endDot)
            if UserDefaultsRepository.smallGraphTreatments.value {
                BGChartFull.data?.dataSets[dataIndex].addEntry(endDot)
            }
            
            // Post end dot
            let postEndDot = ChartDataEntry(x: Double(thisItem.endDate - 1), y: yBottom, data: labelText)
            BGChart.data?.dataSets[dataIndex].addEntry(postEndDot)
            if UserDefaultsRepository.smallGraphTreatments.value {
                BGChartFull.data?.dataSets[dataIndex].addEntry(postEndDot)
            }
        }
        
        BGChart.data?.dataSets[dataIndex].notifyDataSetChanged()
        BGChart.data?.notifyDataChanged()
        BGChart.notifyDataSetChanged()
        if UserDefaultsRepository.smallGraphTreatments.value {
            BGChartFull.data?.dataSets[dataIndex].notifyDataSetChanged()
            BGChartFull.data?.notifyDataChanged()
            BGChartFull.notifyDataSetChanged()
        }
    }
    
    func formatPillText(line1: String, time: TimeInterval) -> String {
        let dateFormatter = DateFormatter()
        //let timezoneOffset = TimeZone.current.secondsFromGMT()
        //let epochTimezoneOffset = value + Double(timezoneOffset)
        if dateTimeUtils.is24Hour() {
            dateFormatter.setLocalizedDateFormatFromTemplate("HH:mm")
        } else {
            dateFormatter.setLocalizedDateFormatFromTemplate("hh:mm")
        }
        
        //let date = Date(timeIntervalSince1970: epochTimezoneOffset)
        let date = Date(timeIntervalSince1970: time)
        let formattedDate = dateFormatter.string(from: date)

        return line1 + "\r\n" + formattedDate
    }
  
}
