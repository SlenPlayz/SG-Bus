import ActivityKit
import WidgetKit
import SwiftUI

// IMPORTANT: This struct MUST be named exactly "LiveActivitiesAppAttributes"
// for the live_activities Flutter package to work correctly.
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState
    
    public struct ContentState: Codable, Hashable { }
    
    var id = UUID()
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        return "\(id)_\(key)"
    }
}

// Shared UserDefaults for data from Flutter
let sharedDefault = UserDefaults(suiteName: "group.com.slen.sgbus")!

@available(iOS 16.1, *)
struct NavigationWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    expandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    expandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    expandedCenter(context: context)
                }
            } compactLeading: {
                compactLeading(context: context)
            } compactTrailing: {
                compactTrailing(context: context)
            } minimal: {
                minimalView(context: context)
            }
        }
    }
    
    // MARK: - Data helpers
    
    private func str(_ context: ActivityViewContext<LiveActivitiesAppAttributes>, _ key: String, _ fallback: String = "") -> String {
        sharedDefault.string(forKey: context.attributes.prefixedKey(key)) ?? fallback
    }
    
    private func int(_ context: ActivityViewContext<LiveActivitiesAppAttributes>, _ key: String, _ fallback: Int = 0) -> Int {
        sharedDefault.integer(forKey: context.attributes.prefixedKey(key))
    }
    
    private func bool(_ context: ActivityViewContext<LiveActivitiesAppAttributes>, _ key: String) -> Bool {
        sharedDefault.bool(forKey: context.attributes.prefixedKey(key))
    }
    
    // MARK: - Mode helpers
    
    private func modeIcon(_ mode: String) -> String {
        switch mode {
        case "BUS": return "bus.fill"
        case "SUBWAY": return "tram.fill"
        case "WALK": return "figure.walk"
        default: return "location.fill"
        }
    }
    
    private func modeColor(_ mode: String) -> Color {
        switch mode {
        case "BUS": return .blue
        case "SUBWAY": return .green
        case "WALK": return .orange
        default: return .gray
        }
    }
    
    private func modeLabel(_ mode: String, route: String) -> String {
        switch mode {
        case "BUS": return "Bus \(route)"
        case "SUBWAY": return "\(route) Line"
        case "WALK": return "Walk"
        default: return "Navigate"
        }
    }
    
    // MARK: - Timing pill
    
    @ViewBuilder
    private func timingPills(nextMin: String, next2Min: String) -> some View {
        if !nextMin.isEmpty {
            HStack(spacing: 4) {
                timingBadge(nextMin, primary: true)
                if !next2Min.isEmpty {
                    timingBadge(next2Min, primary: false)
                }
            }
        }
    }
    
    @ViewBuilder
    private func timingBadge(_ label: String, primary: Bool) -> some View {
        Text(label)
            .font(.caption2)
            .fontWeight(primary ? .bold : .medium)
            .foregroundColor(primary ? .white : .secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(primary ? Color.blue : Color(.systemGray5))
            .cornerRadius(6)
    }
    
    // MARK: - Lock Screen View
    
    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
        let mode    = str(context, "legMode", "WALK")
        let route   = str(context, "legRoute")
        let stopsLeft = int(context, "stopsLeft")
        let destName  = str(context, "destName", "Destination")
        let elapsed   = int(context, "elapsedMinutes")
        let arrived   = bool(context, "arrived")
        let totalLegs   = max(int(context, "totalLegs"), 1)
        let currentLeg  = int(context, "currentLegIndex")
        let alightStop  = str(context, "alightStop")
        let nextMin     = str(context, "nextBusMin")
        let next2Min    = str(context, "nextBus2Min")
        let progress    = Double(currentLeg + 1) / Double(totalLegs)
        
        if arrived {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("You've arrived!")
                        .font(.headline).fontWeight(.semibold)
                    Text(destName)
                        .font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Text("\(elapsed) min")
                    .font(.caption).foregroundColor(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color(.systemGray5)).cornerRadius(8)
            }
            .padding(16)
        } else {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    // Mode icon badge
                    Image(systemName: modeIcon(mode))
                        .font(.title2)
                        .foregroundColor(modeColor(mode))
                        .frame(width: 36, height: 36)
                        .background(modeColor(mode).opacity(0.15))
                        .cornerRadius(10)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(modeLabel(mode, route: route))
                            .font(.headline).fontWeight(.semibold)
                        
                        if mode == "WALK" {
                            Text("to \(alightStop.isEmpty ? destName : alightStop)")
                                .font(.subheadline).foregroundColor(.secondary).lineLimit(1)
                        } else if mode == "BUS" {
                            // Show "3 stops" when on bus, hide timings while aboard
                            Text(stopsLeft > 0
                                 ? "\(stopsLeft) stop\(stopsLeft == 1 ? "" : "s") to \(alightStop.isEmpty ? destName : alightStop)"
                                 : "Arriving soon")
                                .font(.subheadline).foregroundColor(.secondary).lineLimit(1)
                        } else {
                            Text(stopsLeft > 0
                                 ? "\(stopsLeft) stop\(stopsLeft == 1 ? "" : "s") to \(alightStop.isEmpty ? destName : alightStop)"
                                 : "Arriving soon")
                                .font(.subheadline).foregroundColor(.secondary).lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    // Show bus timing pills when walking/waiting at stop; elapsed when riding
                    if mode == "WALK" && !nextMin.isEmpty {
                        timingPills(nextMin: nextMin, next2Min: next2Min)
                    } else {
                        Text("\(elapsed) min")
                            .font(.caption).fontWeight(.medium).foregroundColor(.secondary)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color(.systemGray5)).cornerRadius(8)
                    }
                }
                
                // When walking to stop: show "Next bus: 5 min, 12 min" row
                if mode == "WALK" && !nextMin.isEmpty {
                    HStack {
                        Image(systemName: "bus.fill")
                            .font(.caption2).foregroundColor(.blue)
                        Text("Next bus")
                            .font(.caption2).foregroundColor(.secondary)
                        timingPills(nextMin: nextMin, next2Min: next2Min)
                        Spacer()
                        Text("\(elapsed) min elapsed")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                }
                
                // When on bus: show stops left row
                if mode == "BUS" {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption2).foregroundColor(.blue)
                        Text("\(stopsLeft) stop\(stopsLeft == 1 ? "" : "s") remaining")
                            .font(.caption2).foregroundColor(.secondary)
                        Spacer()
                        Text("Step \(currentLeg + 1)/\(totalLegs)")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray4)).frame(height: 5)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(modeColor(mode))
                            .frame(width: geometry.size.width * min(progress, 1.0), height: 5)
                    }
                }
                .frame(height: 5)
                
                HStack {
                    Text("🏁 \(destName)")
                        .font(.caption2).foregroundColor(.secondary).lineLimit(1)
                    Spacer()
                    if mode != "BUS" {
                        Text("Step \(currentLeg + 1) of \(totalLegs)")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Dynamic Island Compact
    
    @ViewBuilder
    private func compactLeading(context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
        let mode = str(context, "legMode", "WALK")
        let route = str(context, "legRoute")
        let arrived = bool(context, "arrived")
        
        if arrived {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        } else {
            HStack(spacing: 4) {
                Image(systemName: modeIcon(mode)).foregroundColor(modeColor(mode))
                if mode != "WALK" && !route.isEmpty {
                    Text(route).font(.caption2).fontWeight(.bold)
                }
            }
        }
    }
    
    @ViewBuilder
    private func compactTrailing(context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
        let stopsLeft = int(context, "stopsLeft")
        let mode = str(context, "legMode", "WALK")
        let arrived = bool(context, "arrived")
        let nextMin = str(context, "nextBusMin")
        
        if arrived {
            Text("Done").font(.caption2).fontWeight(.semibold).foregroundColor(.green)
        } else if mode == "WALK" && !nextMin.isEmpty {
            // Show next bus time when walking to stop
            Text(nextMin).font(.caption2).fontWeight(.bold).foregroundColor(.blue)
        } else if mode == "WALK" {
            Text("Walking").font(.caption2).foregroundColor(.secondary)
        } else {
            Text("\(stopsLeft)🚏").font(.caption2).fontWeight(.medium)
        }
    }
    
    // MARK: - Dynamic Island Minimal
    
    @ViewBuilder
    private func minimalView(context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
        let mode = str(context, "legMode", "WALK")
        let arrived = bool(context, "arrived")
        let nextMin = str(context, "nextBusMin")
        
        if arrived {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        } else if mode == "WALK" && !nextMin.isEmpty {
            Text(nextMin).font(.caption2).fontWeight(.bold).foregroundColor(.blue)
        } else {
            Image(systemName: modeIcon(mode)).foregroundColor(modeColor(mode))
        }
    }
    
    // MARK: - Dynamic Island Expanded
    
    @ViewBuilder
    private func expandedLeading(context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
        let mode = str(context, "legMode", "WALK")
        let arrived = bool(context, "arrived")
        
        if arrived {
            Image(systemName: "checkmark.circle.fill").font(.title2).foregroundColor(.green)
        } else {
            Image(systemName: modeIcon(mode)).font(.title2).foregroundColor(modeColor(mode))
        }
    }
    
    @ViewBuilder
    private func expandedTrailing(context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
        let mode = str(context, "legMode", "WALK")
        let elapsed = int(context, "elapsedMinutes")
        let nextMin = str(context, "nextBusMin")
        
        if mode == "WALK" && !nextMin.isEmpty {
            // Show next bus timing prominently in expanded trailing
            VStack(alignment: .trailing, spacing: 2) {
                Text(nextMin)
                    .font(.title2).fontWeight(.bold).foregroundColor(.blue)
                Text("next bus")
                    .font(.caption2).foregroundColor(.secondary)
            }
        } else {
            VStack(alignment: .trailing) {
                Text("\(elapsed)")
                    .font(.title2).fontWeight(.bold)
                Text("min")
                    .font(.caption2).foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func expandedCenter(context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
        let mode = str(context, "legMode", "WALK")
        let route = str(context, "legRoute")
        let destName = str(context, "destName", "Destination")
        let arrived = bool(context, "arrived")
        
        if arrived {
            Text("Arrived at \(destName)").font(.headline).lineLimit(1)
        } else {
            Text("\(modeLabel(mode, route: route)) → \(destName)")
                .font(.headline).lineLimit(1)
        }
    }
    
    @ViewBuilder
    private func expandedBottom(context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
        let stopsLeft = int(context, "stopsLeft")
        let mode = str(context, "legMode", "WALK")
        let totalLegs = max(int(context, "totalLegs"), 1)
        let currentLeg = int(context, "currentLegIndex")
        let arrived = bool(context, "arrived")
        let alightStop = str(context, "alightStop")
        let nextMin = str(context, "nextBusMin")
        let next2Min = str(context, "nextBus2Min")
        let elapsed = int(context, "elapsedMinutes")
        let progress = Double(currentLeg + 1) / Double(totalLegs)
        
        if !arrived {
            VStack(spacing: 8) {
                ProgressView(value: min(progress, 1.0)).tint(modeColor(mode))
                
                HStack {
                    if mode == "WALK" && !nextMin.isEmpty {
                        // Walking to stop: show next bus timing
                        HStack(spacing: 4) {
                            Image(systemName: "bus.fill")
                                .font(.caption).foregroundColor(.blue)
                            Text("Next:")
                                .font(.caption).foregroundColor(.secondary)
                            Text(nextMin)
                                .font(.caption).fontWeight(.bold).foregroundColor(.blue)
                            if !next2Min.isEmpty {
                                Text("· \(next2Min)")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    } else if mode == "BUS" {
                        Text("\(stopsLeft) stop\(stopsLeft == 1 ? "" : "s") remaining")
                            .font(.caption).foregroundColor(.secondary)
                    } else {
                        Text("Walking to \(alightStop)")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("\(elapsed) min • Step \(currentLeg + 1)/\(totalLegs)")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }
}
