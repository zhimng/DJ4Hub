import Foundation

enum PhonePresentation {
    static func caller(_ call: HubValue) -> String {
        let value = call["number"].text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty || value == "—" ? "未知／隐藏号码" : value
    }
    static func ringing(_ calls: [HubValue]) -> [HubValue] { calls.filter { ["4", "5"].contains($0["state"].text) } }
    static func simKey(_ status: HubValue) -> String {
        let key = status["iccid"].text
        return status["sim_inserted"].bool && key != "—" ? key : ""
    }
    static func ownNumber(_ status: HubValue, notes: [String: String]) -> String {
        let key = simKey(status)
        guard !key.isEmpty else { return "未识别 SIM" }
        if let value = notes[key], !value.isEmpty { return value }
        let value = status["phone_number"].text
        return value.isEmpty || value == "—" ? "未读取到号码" : value
    }
}
struct CallerAlertTracker {
    private var previous: [String: String] = [:]
    mutating func update(_ calls: [HubValue]) -> [(id: String, number: String)] {
        var current: [String: String] = [:]
        var events: [(id: String, number: String)] = []
        for call in PhonePresentation.ringing(calls) {
            let id = call["id"].text, number = PhonePresentation.caller(call)
            current[id] = number
            if previous[id] != number { events.append((id, number)) }
        }
        previous = current
        return events
    }
}
