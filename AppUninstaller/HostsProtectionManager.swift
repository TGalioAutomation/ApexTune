import Foundation
import AppKit

/// Chặn quảng cáo và ngăn chặn theo dõi bằng cách ghi danh mục hostname vào /etc/hosts
/// (trỏ về 0.0.0.0). Mỗi tính năng có một khối riêng được đánh dấu bằng marker để
/// bật/tắt mà không đụng vào phần nội dung khác của người dùng trong file hosts.
///
/// Trạng thái nguồn sự thật là chính file /etc/hosts, không phải UserDefaults.
final class HostsProtectionManager: ObservableObject {
    static let shared = HostsProtectionManager()

    @Published private(set) var adBlockEnabled = false
    @Published private(set) var antiTrackEnabled = false
    @Published private(set) var adBlockDomainCount = 0
    @Published private(set) var antiTrackDomainCount = 0
    @Published private(set) var isApplying = false
    @Published var lastMessage: String?

    static let adBlockMarker = "MacOptimizer AdBlock"
    static let antiTrackMarker = "MacOptimizer AntiTrack"
    private static let hostsPath = "/etc/hosts"
    private static let backupPath = "/etc/hosts.macoptimizer.bak"

    // MARK: - Danh mục hostname chặn (hosts chỉ chặn đúng từng hostname, không có wildcard)

    /// Hostname phục vụ quảng cáo
    static let adBlockHosts: [String] = [
        "pagead2.googlesyndication.com",
        "tpc.googlesyndication.com",
        "adservice.google.com",
        "adservice.google.com.vn",
        "googleads.g.doubleclick.net",
        "securepubads.g.doubleclick.net",
        "pubads.g.doubleclick.net",
        "stats.g.doubleclick.net",
        "ad.doubleclick.net",
        "googleadservices.com",
        "www.googleadservices.com",
        "an.facebook.com",
        "www.facebook.com/tr",
        "ads-twitter.com",
        "static.ads-twitter.com",
        "ads.linkedin.com",
        "px.ads.linkedin.com",
        "adnxs.com",
        "secure.adnxs.com",
        "ib.adnxs.com",
        "criteo.com",
        "static.criteo.net",
        "cas.criteo.com",
        "pubmatic.com",
        "ads.pubmatic.com",
        "rubiconproject.com",
        "ads.rubiconproject.com",
        "amazon-adsystem.com",
        "c.amazon-adsystem.com",
        "ads.yahoo.com",
        "adtechus.com",
        "adform.net",
        "ads.adfox.ru",
        "taboola.com",
        "cdn.taboola.com",
        "trc.taboola.com",
        "outbrain.com",
        "widgets.outbrain.com",
        "teads.tv",
        "cdn.teads.tv",
        "sharethrough.com",
        "spotxchange.com",
        "indexww.com",
        "casalemedia.com",
        "openx.net",
        "us.openx.net",
        "smartadserver.com",
        "prg.smartadserver.com",
        "adcolony.com",
        "unityads.unity3d.com",
        "applovin.com",
        "ads.applovin.com",
        "vungle.com",
        "api.vungle.com",
        "ironsrc.com",
        "sdk.adincube.com",
        "inmobi.com",
        "api.inmobi.com",
        "mopub.com",
        "ads.mopub.com",
        "scorecardresearch.com",
        "sb.scorecardresearch.com",
        "zedo.com",
        "ads.zedo.com",
        "2mdn.net",
        "media.net",
        "static.media.net",
    ]

    /// Hostname thu thập dữ liệu hành vi / theo dõi người dùng
    static let antiTrackHosts: [String] = [
        "google-analytics.com",
        "www.google-analytics.com",
        "ssl.google-analytics.com",
        "analytics.google.com",
        "googletagmanager.com",
        "www.googletagmanager.com",
        "doubleclick.net",
        "connect.facebook.net",
        "graph.facebook.com",
        "analytics.tiktok.com",
        "ads.tiktok.com",
        "business-api.tiktok.com",
        "sc-static.net",
        "tr.snapchat.com",
        "app-measurement.com",
        "firebase-settings.crashlytics.com",
        "mixpanel.com",
        "api.mixpanel.com",
        "cdn.mxpnl.com",
        "segment.io",
        "cdn.segment.com",
        "api.segment.io",
        "amplitude.com",
        "api.amplitude.com",
        "cdn.amplitude.com",
        "heapanalytics.com",
        "api.heapanalytics.com",
        "fullstory.com",
        "rs.fullstory.com",
        "hotjar.com",
        "static.hotjar.com",
        "events.hotjar.io",
        "clarity.ms",
        "c.clarity.ms",
        "bat.bing.com",
        "www.clarity.ms",
        "quantserve.com",
        "pixel.quantserve.com",
        "chartbeat.com",
        "static.chartbeat.com",
        "ping.chartbeat.net",
        "nr-data.net",
        "js-agent.newrelic.com",
        "branch.io",
        "app.link",
        "adjust.com",
        "app.adjust.com",
        "appsflyer.com",
        "register.appsflyer.com",
        "kochava.com",
        "control.kochava.com",
        "matomo.cloud",
        "plausible.io",
    ]

    // MARK: - Đọc trạng thái

    /// Đọc /etc/hosts và cập nhật trạng thái hiện tại của từng khối.
    func refresh() {
        guard let content = try? String(contentsOfFile: Self.hostsPath, encoding: .utf8) else {
            adBlockEnabled = false
            antiTrackEnabled = false
            adBlockDomainCount = 0
            antiTrackDomainCount = 0
            return
        }
        let sections = Self.parseSections(in: content)
        adBlockEnabled = sections[Self.adBlockMarker] != nil
        antiTrackEnabled = sections[Self.antiTrackMarker] != nil
        adBlockDomainCount = sections[Self.adBlockMarker]?.count ?? 0
        antiTrackDomainCount = sections[Self.antiTrackMarker]?.count ?? 0
    }

    // MARK: - Bật / tắt

    func setAdBlock(_ enabled: Bool) {
        apply(adBlockEnabled: enabled, antiTrackEnabled: antiTrackEnabled)
    }

    func setAntiTrack(_ enabled: Bool) {
        apply(adBlockEnabled: adBlockEnabled, antiTrackEnabled: enabled)
    }

    /// Ghi lại toàn bộ file hosts với các khối theo trạng thái mong muốn.
    /// Yêu cầu quyền quản trị (người dùng sẽ thấy hộp thoại mật khẩu của macOS).
    private func apply(adBlockEnabled: Bool, antiTrackEnabled: Bool) {
        guard !isApplying else { return }
        isApplying = true
        defer { isApplying = false }

        guard var lines = Self.readHostLines() else {
            lastMessage = L("Không đọc được /etc/hosts")
            return
        }

        lines = Self.stripManagedSections(from: lines)

        if adBlockEnabled {
            lines.append(contentsOf: Self.sectionLines(marker: Self.adBlockMarker, hosts: Self.adBlockHosts))
        }
        if antiTrackEnabled {
            lines.append(contentsOf: Self.sectionLines(marker: Self.antiTrackMarker, hosts: Self.antiTrackHosts))
        }

        let newContent = lines.joined(separator: "\n") + "\n"
        let tmpPath = NSTemporaryDirectory() + "hosts.macoptimizer"
        do {
            try newContent.write(toFile: tmpPath, atomically: true, encoding: .utf8)
        } catch {
            lastMessage = String(format: L("Không ghi được file tạm: %@"), error.localizedDescription)
            return
        }

        let quotedTmp = tmpPath.replacingOccurrences(of: " ", with: "\\ ")
        let command = "cp /etc/hosts \(Self.backupPath) 2>/dev/null; cp \(quotedTmp) /etc/hosts && dscacheutil -flushcache && killall -HUP mDNSResponder"
        if PrivilegedShell.run(command) {
            lastMessage = L("Đã cập nhật danh sách chặn và xóa bộ nhớ đệm DNS")
        } else {
            lastMessage = L("Đã hủy — không có thay đổi nào được ghi")
        }
        refresh()
    }

    // MARK: - Phân tích file hosts

    private static func readHostLines() -> [String]? {
        guard let content = try? String(contentsOfFile: hostsPath, encoding: .utf8) else { return nil }
        return content.components(separatedBy: "\n")
    }

    /// Cắt bỏ các khối do MacOptimizer quản lý, giữ nguyên phần còn lại
    private static func stripManagedSections(from lines: [String]) -> [String] {
        var result: [String] = []
        var currentMarker: String?
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let begin = managedMarker(in: trimmed, prefix: "BEGIN") {
                currentMarker = begin
                continue
            }
            if let end = managedMarker(in: trimmed, prefix: "END") {
                if currentMarker == end { currentMarker = nil }
                continue
            }
            if currentMarker == nil {
                result.append(line)
            }
        }
        // Dọn các dòng trống thừa ở cuối
        while result.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            result.removeLast()
        }
        if let last = result.last, !last.isEmpty {
            result.append("")
        }
        return result
    }

    private static func managedMarker(in line: String, prefix: String) -> String? {
        guard line.hasPrefix("#") else { return nil }
        let body = line.dropFirst().trimmingCharacters(in: .whitespaces)
        for marker in [adBlockMarker, antiTrackMarker] {
            if body == "\(prefix) \(marker)" || body == "\(prefix): \(marker)" {
                return marker
            }
        }
        return nil
    }

    private static func sectionLines(marker: String, hosts: [String]) -> [String] {
        var lines: [String] = []
        lines.append("# BEGIN \(marker)")
        for host in hosts {
            lines.append("0.0.0.0 \(host)")
        }
        lines.append("# END \(marker)")
        lines.append("")
        return lines
    }

    /// Trả về danh sách hostname trong từng khối managed hiện có
    private static func parseSections(in content: String) -> [String: [String]] {
        var sections: [String: [String]] = [:]
        var currentMarker: String?
        for rawLine in content.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if let begin = managedMarker(in: line, prefix: "BEGIN") {
                currentMarker = begin
                sections[begin] = []
            } else if let end = managedMarker(in: line, prefix: "END") {
                if currentMarker == end { currentMarker = nil }
            } else if let marker = currentMarker, !line.isEmpty, !line.hasPrefix("#") {
                let parts = line.split(separator: " ").map(String.init)
                if parts.count >= 2 {
                    sections[marker]?.append(parts[1])
                }
            }
        }
        return sections
    }
}
