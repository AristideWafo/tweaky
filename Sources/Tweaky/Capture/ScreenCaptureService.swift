import AppKit
import ScreenCaptureKit

enum ScreenCaptureError: LocalizedError {
    case permissionDenied, noDisplay

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Screen Recording permission is required for OCR."
        case .noDisplay: "No display is available for capture."
        }
    }
}

final class ScreenCaptureService: @unchecked Sendable {
    func captureMainDisplay() async throws -> CGImage {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            throw ScreenCaptureError.permissionDenied
        }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() }) ?? content.displays.first else {
            throw ScreenCaptureError.noDisplay
        }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height
        configuration.showsCursor = false
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    }
}
