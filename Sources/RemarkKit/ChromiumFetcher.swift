#if os(Linux)
import Foundation

/// Fetches HTML content using headless Chromium subprocess.
/// Available only on Linux for server/Cloud Run deployments.
final class ChromiumFetcher: HTMLFetching {

    /// Paths to search for the Chromium binary.
    private static let chromiumPaths = [
        "/usr/bin/chromium",
        "/usr/bin/chromium-browser",
        "/usr/bin/google-chrome",
        "/usr/bin/google-chrome-stable",
    ]

    /// Locates the Chromium binary on the system.
    private static func findChromium() throws -> String {
        for path in chromiumPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["chromium"]
        let pipe = Pipe()
        whichProcess.standardOutput = pipe
        whichProcess.standardError = FileHandle.nullDevice
        do {
            try whichProcess.run()
            whichProcess.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        } catch {
            // Fall through to error
        }
        throw FetcherError("Chromium not found. Install chromium or google-chrome.")
    }

    func fetchHTML(
        from url: URL,
        referer: URL? = nil,
        timeout: TimeInterval = 15,
        customHeaders: [String: String]? = nil
    ) async throws -> String {
        let chromiumPath = try Self.findChromium()

        var arguments = [
            "--headless",
            "--dump-dom",
            "--no-sandbox",
            "--disable-gpu",
            "--disable-dev-shm-usage",
            "--disable-extensions",
            "--disable-background-networking",
            "--disable-default-apps",
            "--no-first-run",
        ]

        if let userAgent = customHeaders?["User-Agent"] {
            arguments.append("--user-agent=\(userAgent)")
        }

        let timeoutMs = Int(timeout * 1000)
        arguments.append("--virtual-time-budget=\(timeoutMs)")

        arguments.append(url.absoluteString)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: chromiumPath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try process.run()
                process.waitUntilExit()

                let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()

                guard process.terminationStatus == 0 else {
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrString = String(data: stderrData, encoding: .utf8) ?? "Unknown error"
                    throw FetcherError("Chromium exited with status \(process.terminationStatus): \(stderrString)")
                }

                guard let html = String(data: data, encoding: .utf8), !html.isEmpty else {
                    throw FetcherError("Chromium returned empty output")
                }

                return html
            }

            // Timeout watchdog
            group.addTask {
                try await Task.sleep(for: .seconds(timeout + 5))
                process.terminate()
                throw FetcherError("Timeout: Chromium did not respond within \(Int(timeout)) seconds")
            }

            guard let result = try await group.next() else {
                throw FetcherError("No result from Chromium")
            }
            group.cancelAll()
            return result
        }
    }
}
#endif
