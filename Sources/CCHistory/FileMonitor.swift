import Foundation

/// Monitors a directory for file system changes using DispatchSourceFileSystemObject.
/// Triggers a callback when files in the monitored directory are modified.
final class FileMonitor {
  // MARK: - Properties

  private var fileDescriptor: Int32 = -1
  private var source: DispatchSourceFileSystemObject?
  private let path: String
  private let onChange: () -> Void

  /// Debounce timer to prevent rapid successive callbacks
  private var debounceWorkItem: DispatchWorkItem?

  // MARK: - Initialization

  /// Initialize a file monitor for the specified path
  /// - Parameters:
  ///   - path: The directory path to monitor
  ///   - onChange: Callback to execute when file changes are detected
  init?(path: String, onChange: @escaping () -> Void) {
    self.path = path
    self.onChange = onChange

    // Verify path exists and is a directory
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
      print("[FileMonitor] Path does not exist or is not a directory: \(path)")
      return nil
    }

    // Open file descriptor for the directory
    fileDescriptor = open(path, O_EVTONLY)
    guard fileDescriptor != -1 else {
      print("[FileMonitor] Failed to open directory: \(path)")
      return nil
    }

    setupSource()
  }

  deinit {
    stopMonitoring()
    if fileDescriptor != -1 {
      close(fileDescriptor)
    }
  }

  // MARK: - Setup

  private func setupSource() {
    // Create dispatch source for file system events
    source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: fileDescriptor,
      eventMask: .write,
      queue: .main
    )

    // Set event handler with debouncing
    source?.setEventHandler { [weak self] in
      self?.handleEvent()
    }

    // Set cancellation handler
    source?.setCancelHandler { [weak self] in
      print("[FileMonitor] Monitoring cancelled for: \(self?.path ?? "unknown")")
    }

    // Start monitoring
    source?.resume()
    print("[FileMonitor] Started monitoring: \(path)")
  }

  // MARK: - Event Handling

  private func handleEvent() {
    // Cancel any pending debounce work item
    debounceWorkItem?.cancel()

    // Create new debounce work item
    let workItem = DispatchWorkItem { [weak self] in
      self?.onChange()
    }

    debounceWorkItem = workItem

    // Execute after debounce delay (500ms)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
  }

  // MARK: - Control

  /// Stop monitoring the directory
  func stopMonitoring() {
    source?.cancel()
    source = nil
    debounceWorkItem?.cancel()
    debounceWorkItem = nil
    print("[FileMonitor] Stopped monitoring: \(path)")
  }

  /// Restart monitoring (useful if directory was temporarily unavailable)
  func restart() {
    stopMonitoring()
    if fileDescriptor != -1 {
      close(fileDescriptor)
    }

    // Reopen file descriptor
    fileDescriptor = open(path, O_EVTONLY)
    guard fileDescriptor != -1 else {
      print("[FileMonitor] Failed to reopen directory: \(path)")
      return
    }

    setupSource()
  }
}
