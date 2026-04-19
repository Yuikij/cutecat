import Foundation

final class ModelDownloadService: NSObject, @unchecked Sendable, URLSessionDownloadDelegate, URLSessionTaskDelegate {
    static let shared = ModelDownloadService()
    static let sessionIdentifier = "com.soukon.cutecat.model-download"

    private let stateQueue = DispatchQueue(label: "com.soukon.cutecat.model-download.state")
    private var continuation: CheckedContinuation<URL, Error>?
    private var progressHandler: (@MainActor (Double, Int64, Int64) -> Void)?
    private var backgroundCompletionHandler: (() -> Void)?

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = true
        configuration.timeoutIntervalForResource = 60 * 60 * 6
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    func registerBackgroundCompletionHandler(
        identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard identifier == Self.sessionIdentifier else {
            completionHandler()
            return
        }

        nonisolated(unsafe) let handler = completionHandler
        stateQueue.async {
            self.backgroundCompletionHandler = handler
        }
    }

    func download(
        from url: URL,
        forceRestart: Bool = false,
        progressHandler: @escaping @MainActor (Double, Int64, Int64) -> Void
    ) async throws -> URL {
        setProgressHandler(progressHandler)

        if forceRestart {
            try await cancelActiveDownload(resetResumeData: true)
            clearResumeData()
        }

        if let existingTask = await activeDownloadTask() {
            publishExistingTaskProgress(existingTask)
            return try await awaitDownloadResult(resuming: existingTask)
        }

        let task: URLSessionDownloadTask
        if forceRestart == false, let resumeData = loadResumeData() {
            clearResumeData()
            task = session.downloadTask(withResumeData: resumeData)
        } else {
            task = session.downloadTask(with: url)
        }

        return try await awaitDownloadResult(resuming: task)
    }

    func cancelActiveDownload(resetResumeData: Bool) async throws {
        guard let task = await activeDownloadTask() else {
            return
        }

        if resetResumeData {
            task.cancel()
            return
        }

        let resumeData = await withCheckedContinuation { continuation in
            task.cancel { data in
                continuation.resume(returning: data)
            }
        }

        if let resumeData {
            try saveResumeData(resumeData)
        }
    }

    func hasActiveDownloadTask() async -> Bool {
        await activeDownloadTask() != nil
    }

    private func awaitDownloadResult(resuming task: URLSessionDownloadTask) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            storeContinuation(continuation)
            task.resume()
        }
    }

    private func activeDownloadTask() async -> URLSessionDownloadTask? {
        let tasks = await allTasks()
        return tasks
            .compactMap { $0 as? URLSessionDownloadTask }
            .first { $0.state == .running || $0.state == .suspended }
    }

    private func allTasks() async -> [URLSessionTask] {
        await withCheckedContinuation { continuation in
            session.getAllTasks { tasks in
                continuation.resume(returning: tasks)
            }
        }
    }

    private func publishExistingTaskProgress(_ task: URLSessionDownloadTask) {
        let expectedBytes = task.countOfBytesExpectedToReceive
        let writtenBytes = task.countOfBytesReceived
        let progress = expectedBytes > 0 ? min(1, Double(writtenBytes) / Double(expectedBytes)) : 0

        Task { @MainActor in
            self.progressHandler?(progress, writtenBytes, expectedBytes)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let expected = max(totalBytesExpectedToWrite, 0)
        let progress = expected > 0 ? min(1, Double(totalBytesWritten) / Double(expected)) : 0
        let handler = currentProgressHandler()

        Task { @MainActor in
            handler?(progress, totalBytesWritten, expected)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let tempURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)

        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }

            try FileManager.default.copyItem(at: location, to: tempURL)
            clearResumeData()
            takeContinuation()?.resume(returning: tempURL)
        } catch {
            takeContinuation()?.resume(throwing: error)
        }

        clearProgressHandler()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }

        if let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
            try? saveResumeData(resumeData)
        }

        takeContinuation()?.resume(throwing: error)
        clearProgressHandler()
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        takeBackgroundCompletionHandler()?()
    }

    private func storeContinuation(_ continuation: CheckedContinuation<URL, Error>) {
        stateQueue.sync {
            self.continuation = continuation
        }
    }

    private func takeContinuation() -> CheckedContinuation<URL, Error>? {
        stateQueue.sync {
            let value = continuation
            continuation = nil
            return value
        }
    }

    private func setProgressHandler(_ handler: @escaping @MainActor (Double, Int64, Int64) -> Void) {
        stateQueue.sync {
            progressHandler = handler
        }
    }

    private func clearProgressHandler() {
        stateQueue.sync {
            progressHandler = nil
        }
    }

    private func currentProgressHandler() -> (@MainActor (Double, Int64, Int64) -> Void)? {
        stateQueue.sync {
            progressHandler
        }
    }

    private func takeBackgroundCompletionHandler() -> (() -> Void)? {
        stateQueue.sync {
            let value = backgroundCompletionHandler
            backgroundCompletionHandler = nil
            return value
        }
    }

    private func saveResumeData(_ data: Data) throws {
        let url = try resumeDataURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    private func loadResumeData() -> Data? {
        guard let url = try? resumeDataURL() else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    private func clearResumeData() {
        guard let url = try? resumeDataURL() else {
            return
        }
        try? FileManager.default.removeItem(at: url)
    }

    private func resumeDataURL() throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return root
            .appending(path: "Downloads", directoryHint: .isDirectory)
            .appending(path: "qwen-model.resume", directoryHint: .notDirectory)
    }
}
