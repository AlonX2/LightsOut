//
//  DisplaysViewModel.swift
//  BlackoutTest

import CoreGraphics
import SwiftUI

@_silgen_name("CGSConfigureDisplayEnabled")
func CGSConfigureDisplayEnabled(_ cid: CGDisplayConfigRef, _ display: UInt32, _ enabled: Bool) -> Int

private let displayReconfigurationCallback: CGDisplayReconfigurationCallBack = { _, flags, userInfo in
    guard !flags.contains(.beginConfigurationFlag), let userInfo = userInfo else { return }
    let viewModel = Unmanaged<DisplaysViewModel>.fromOpaque(userInfo).takeUnretainedValue()
    DispatchQueue.main.async {
        viewModel.fetchDisplays()
    }
}

class DisplaysViewModel: ObservableObject {
    @Published var displays: [DisplayInfo] = []
    private var gammaService = GammaUpdateService()
    private var arrengementCache = DisplayArrangementCacheService()

    init() {
        fetchDisplays()
        CGDisplayRegisterReconfigurationCallback(displayReconfigurationCallback, Unmanaged.passUnretained(self).toOpaque())
    }

    deinit {
        CGDisplayRemoveReconfigurationCallback(displayReconfigurationCallback, Unmanaged.passUnretained(self).toOpaque())
    }
    
    func fetchDisplays() {
        print("Fetching displays.")
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        var activeDisplays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &activeDisplays, &displayCount)
        
        var new_displays: Set<DisplayInfo> = Set()
        
        let primaryDisplayID = CGMainDisplayID()
        
        new_displays = Set(activeDisplays.compactMap { displayID in
            var displayName = "Display \(displayID)"
            if let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) {
                displayName = screen.localizedName
            }
            return DisplayInfo(
                id: displayID,
                name: displayName,
                state: .active,
                isPrimary: displayID == primaryDisplayID
            )
        })
        
        // Ensuring the off/pending displays are not "deleted" - manually adding them to the new list.
        for display in displays {
            if display.state.isOff() || display.state == .pending {
                display.isPrimary = false
                new_displays.insert(display)
            }
        }
        
        displays = Array(new_displays)
        
        displays.sort {
            if $0.isPrimary {
                return true
            }
            if $1.isPrimary {
                return false
            }
            return $0.id < $1.id
        }
        
        try! arrengementCache.cache()
    }
    
    func disconnectDisplay(display: DisplayInfo) throws(DisplayError) {
        display.state = .pending
        var cid: CGDisplayConfigRef?
        let beginStatus = CGBeginDisplayConfiguration(&cid)
        
        guard beginStatus == .success, let config = cid else {
            throw DisplayError(msg: "Failed to begin configuring '\(display.name)'.")
        }
        
        let status = CGSConfigureDisplayEnabled(config, display.id, false)
        guard status == 0 else {
            CGCancelDisplayConfiguration(config)
            throw DisplayError(msg: "Failed to disconnect '\(display.name)'.")
        }
        
        let completeStatus = CGCompleteDisplayConfiguration(config, .forAppOnly)
        guard completeStatus == .success else {
            throw DisplayError(msg: "Failed to finish configuring '\(display.name)'.")
        }
        
        display.state = .disconnected
        unRegisterMirrors(display: display)
    }

    
    func disableDisplay(display: DisplayInfo) throws(DisplayError) {
        display.state = .pending
        
        
        do {
            try mirrorDisplay(display)
            gammaService.setZeroGamma(for: display)
        } catch {
            throw DisplayError(msg: "Faild to apply a mirror-based disable to '\(display.name)'.")
        }
        unRegisterMirrors(display: display)
    }
    
    func turnOnDisplay(display: DisplayInfo) throws(DisplayError) {
        switch display.state {
        case .disconnected:
            try reconnectDisplay(display: display)
        case .mirrored:
            try enableDisplay(display: display)
        default:
            break
        }
    }
    
    func resetAllDisplays() {
        for display in displays {
            try? turnOnDisplay(display: display)
        }
        CGDisplayRestoreColorSyncSettings()
        CGRestorePermanentDisplayConfiguration()
    }
    
    func unRegisterMirrors(display: DisplayInfo) {
        for mirror in display.mirroredTo {
            mirror.state = .active
        }
    }
    
}

// MARK: - TurnOn logic

extension DisplaysViewModel {
    fileprivate func reconnectDisplay(display: DisplayInfo) throws(DisplayError) {
        var cid: CGDisplayConfigRef?
        let beginStatus = CGBeginDisplayConfiguration(&cid)
        guard beginStatus == .success, let config = cid else {
            throw DisplayError(
                msg: "Failed to begin configuration for '\(display.name)'."
            )
        }
        
        let status = CGSConfigureDisplayEnabled(config, display.id, true)
        guard status == 0 else {
            CGCancelDisplayConfiguration(config)
            throw DisplayError(
                msg: "Failed to reconnect '\(display.name)'."
            )
        }
        
        let completeStatus = CGCompleteDisplayConfiguration(config, .forAppOnly)
        guard completeStatus == .success else {
            throw DisplayError(
                msg: "Failed to complete configuration for '\(display.name)'.")
        }
        
        display.state = .active
    }
    
    fileprivate func enableDisplay(display: DisplayInfo) throws(DisplayError) {
        gammaService.restoreGamma(for: display)
        
        do {
            try unmirrorDisplay(display)
            try arrengementCache.restore()
            print("Unmirrored display \(display.name)!")
        } catch {
            throw DisplayError(
                msg: "Failed to enable '\(display.name)'."
            )
        }
        
        display.state = .active
    }
}

// MARK: - Mirroring Extention

extension DisplaysViewModel {
    fileprivate func mirrorDisplay(_ display: DisplayInfo) throws {
        let targetDisplayID = display.id
        
        guard let alternateDisplay = selectAlternateDisplay(excluding: targetDisplayID) else {
            throw DisplayError(msg: "No suitable alternate display found for mirroring.")
        }
        
        var configRef: CGDisplayConfigRef?
        let beginConfigError = CGBeginDisplayConfiguration(&configRef)
        guard beginConfigError == .success, let config = configRef else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(beginConfigError.rawValue), userInfo: [
                NSLocalizedDescriptionKey: "Failed to begin display configuration."
            ])
        }
        
        let mirrorError = CGConfigureDisplayMirrorOfDisplay(config, targetDisplayID, alternateDisplay.id)
        guard mirrorError == .success else {
            CGCancelDisplayConfiguration(config)
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(mirrorError.rawValue), userInfo: [
                NSLocalizedDescriptionKey: "Failed to mirror display \(alternateDisplay.name) to display \(display.name)."
            ])
        }
        
        let completeConfigError = CGCompleteDisplayConfiguration(config, .forAppOnly)
        guard completeConfigError == .success else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(completeConfigError.rawValue), userInfo: [
                NSLocalizedDescriptionKey: "Failed to complete display configuration."
            ])
        }
        
        alternateDisplay.mirroredTo.append(display)
        print("Successfully mirrored display \(display.name) to \(alternateDisplay.name).")
    }
    
    fileprivate func unmirrorDisplay(_ display: DisplayInfo) throws {
        var configRef: CGDisplayConfigRef?
        let beginConfigError = CGBeginDisplayConfiguration(&configRef)
        guard beginConfigError == .success, let config = configRef else {
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(beginConfigError.rawValue),
                userInfo: [NSLocalizedDescriptionKey: "Failed to begin display configuration."]
            )
        }

        let unmirrorError = CGConfigureDisplayMirrorOfDisplay(config, display.id, kCGNullDirectDisplay)
        guard unmirrorError == .success else {
            CGCancelDisplayConfiguration(config)
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(unmirrorError.rawValue),
                userInfo: [NSLocalizedDescriptionKey: "Failed to unmirror display \(display.name)."]
            )
        }

        let completeConfigError = CGCompleteDisplayConfiguration(config, .forAppOnly)
        guard completeConfigError == .success else {
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(completeConfigError.rawValue),
                userInfo: [NSLocalizedDescriptionKey: "Failed to complete display configuration."]
            )
        }

        // Update the mirroredTo and mirrorSource relationships
        display.mirrorSource?.mirroredTo.remove(at: display.mirrorSource!.mirroredTo.firstIndex(of: display)!)

        print("Successfully unmirrored display \(display.name).")
    }
    
    private func selectAlternateDisplay(excluding currentDisplayID: CGDirectDisplayID) -> DisplayInfo? {
        return displays.first { $0.id != currentDisplayID && $0.state == .active}
    }
}

// MARK: - NScreen Extentrion

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as! CGDirectDisplayID
    }
}
