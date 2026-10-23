//
//  MonitorService.swift
//  LightsOut
//
//  Created by DE4ME on 18.10.2026.
//

import AppKit


enum MonitorServiceKey: String, Hashable {
    case monitors
}


struct MonitorDescription: Identifiable, Equatable, Codable {
    let id: String
    let displayId: CGDirectDisplayID
    let name: String
}


extension MonitorDescription {
    
    init(_ screen: NSScreen) {
        self.displayId = screen.displayID
        self.name = screen.localizedName
        let uuid = CGDisplayCreateUUIDFromDisplayID(screen.displayID).takeRetainedValue()
        self.id = CFUUIDCreateString(nil, uuid) as String
    }
    
}


class MonitorService {
    
    var monitors: [MonitorDescription] {
        get {
            getMonitors()
        }
        
        set {
            setMonitors(newValue)
        }
    }
    
    
    var activeMonitors: [MonitorDescription] {
        NSScreen.screens.map { MonitorDescription($0) }
    }
    
    
    private func userDefaultsGetMonitors() -> [MonitorDescription] {
        guard let data = UserDefaults.standard.object(forKey: MonitorServiceKey.monitors.rawValue) as? Data else {
            return []
        }
        do {
            return try JSONDecoder().decode([MonitorDescription].self, from: data)
        }
        catch {
            #if DEBUG
            print(error)
            #endif
            return []
        }
    }
    
    
    private func userDefaultsSetMonitors(_ monitors: [MonitorDescription]) {
        do {
            let array = try JSONEncoder().encode(monitors)
            UserDefaults.standard.set(array, forKey: MonitorServiceKey.monitors.rawValue)
        }
        catch {
            #if DEBUG
            print(error)
            #endif
        }
    }
    
    
    private func setMonitors(_ monitors: [MonitorDescription]) {
        let old = userDefaultsGetMonitors()
        guard old != monitors else {
            return
        }
        userDefaultsSetMonitors(monitors)
    }
    
    
    private func getMonitors() -> [MonitorDescription] {
        let active = activeMonitors
        let restore = userDefaultsGetMonitors()
        let offline = restore.filter { !active.contains($0) }
        let result = offline + active
        return result.sorted { $0.id < $1.id }
    }
    
}
