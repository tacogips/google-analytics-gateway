import Darwin
import Foundation

/// Local filesystem primitives for credential-bearing files.
///
/// Every read walks the path one component at a time through `openat` with
/// `O_NOFOLLOW`, so no symlink anywhere in the path can redirect the operation,
/// and every read re-verifies the file identity after the bytes are consumed so
/// a swap during the read is rejected rather than decoded. Writes are atomic
/// 0600 replacements inside a directory that must already be private.
public enum SecureLocalFiles {
  /// Reads bounded request input from one no-follow descriptor and rejects any
  /// observable metadata change before its bytes can be decoded.
  ///
  /// `afterRead` runs while the descriptor is still open; it exists so callers
  /// can interleave a check whose result must be invalidated by any concurrent
  /// change to the file.
  public static func readStableRegularFile(
    path: String,
    maximumBytes: Int,
    afterRead: (() throws -> Void)? = nil
  ) throws -> Data {
    let target = try Target(path: path)
    let directory = try openDirectory(target.directory)
    defer { close(directory) }
    // O_NONBLOCK makes FIFO and similar non-regular entries fail closed at the
    // fstat check below instead of allowing an attacker-controlled pathname to
    // stall the caller while opening it.
    let fd = openat(directory, target.name, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
    guard fd >= 0 else { throw fileError("Unable to open request file") }
    defer { close(fd) }
    var before = stat()
    guard fstat(fd, &before) == 0, before.st_mode & S_IFMT == S_IFREG,
      before.st_size <= off_t(maximumBytes) else {
      throw fileError("Request file is not a bounded regular file")
    }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 16_384)
    while true {
      let count = read(fd, &buffer, buffer.count)
      guard count >= 0 else { throw fileError("Unable to read request file") }
      if count == 0 { break }
      guard data.count + count <= maximumBytes else {
        throw sizeError("Request file exceeds the allowed size")
      }
      data.append(buffer, count: count)
    }
    try afterRead?()
    var after = stat()
    var currentEntry = stat()
    guard fstat(fd, &after) == 0,
      fstatat(directory, target.name, &currentEntry, AT_SYMLINK_NOFOLLOW) == 0,
      before.st_dev == after.st_dev, before.st_ino == after.st_ino,
      before.st_dev == currentEntry.st_dev, before.st_ino == currentEntry.st_ino,
      before.st_mode & S_IFMT == currentEntry.st_mode & S_IFMT,
      before.st_mode == after.st_mode, before.st_size == after.st_size,
      before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
      before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
      before.st_ctimespec.tv_sec == after.st_ctimespec.tv_sec,
      before.st_ctimespec.tv_nsec == after.st_ctimespec.tv_nsec else {
      throw fileError("Request file changed while being read")
    }
    return data
  }

  /// Reads a configured file, optionally requiring that it belongs to the
  /// current user, carries no group or other permission bits, and lives in a
  /// directory that is itself private.
  public static func readRegularFile(
    path: String,
    maximumBytes: Int,
    requireCurrentUser: Bool = false,
    requirePrivateMode: Bool = false,
    requirePrivateParent: Bool = false
  ) throws -> Data {
    let target = try Target(path: path)
    let directory = try openDirectory(target.directory)
    defer { close(directory) }
    if requirePrivateParent { try validatePrivateDirectory(directory) }
    let fd = openat(directory, target.name, O_RDONLY | O_NOFOLLOW)
    guard fd >= 0 else { throw fileError("Unable to open configured file") }
    defer { close(fd) }
    var metadata = stat()
    guard fstat(fd, &metadata) == 0, metadata.st_mode & S_IFMT == S_IFREG,
      !requireCurrentUser || metadata.st_uid == getuid(),
      !requirePrivateMode || metadata.st_mode & 0o077 == 0 else {
      throw fileError("Configured path is not a regular file")
    }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 16_384)
    while true {
      let count = read(fd, &buffer, buffer.count)
      guard count >= 0 else { throw fileError("Unable to read configured file") }
      if count == 0 { break }
      guard data.count + count <= maximumBytes else {
        throw sizeError("Configured file exceeds the allowed size")
      }
      data.append(buffer, count: count)
    }
    var verified = stat()
    guard fstat(fd, &verified) == 0, metadata.st_dev == verified.st_dev,
      metadata.st_ino == verified.st_ino else {
      throw fileError("Configured file changed while being read")
    }
    return data
  }

  /// Writes `data` to `path` as a 0600 file owned by the current user.
  ///
  /// The bytes land in a temporary sibling first; the destination is only
  /// created by `linkat` (which fails if something appeared meanwhile) or
  /// replaced by `renameat` after re-checking that the destination is still the
  /// same private regular file that was inspected before the write.
  public static func writePrivateFile(_ data: Data, path: String) throws {
    let target = try Target(path: path)
    let directory = try openDirectory(target.directory)
    defer { close(directory) }
    try validatePrivateDirectory(directory)
    var original = stat()
    let originalResult = fstatat(directory, target.name, &original, AT_SYMLINK_NOFOLLOW)
    let replacing: Bool
    if originalResult == 0 {
      guard (original.st_mode & S_IFMT) == S_IFREG, original.st_uid == getuid(),
        (original.st_mode & 0o077) == 0 else {
        throw fileError("OAuth token store is not a private regular file")
      }
      replacing = true
    } else if errno == ENOENT {
      replacing = false
    } else {
      throw fileError("Unable to inspect token store destination")
    }
    let temporary = ".gateway-token-\(UUID().uuidString)"
    let fd = openat(directory, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR)
    guard fd >= 0 else { throw fileError("Unable to create token store") }
    defer { close(fd) }
    var offset = 0
    try data.withUnsafeBytes { raw in
      while offset < data.count {
        let count = write(fd, raw.baseAddress!.advanced(by: offset), data.count - offset)
        guard count > 0 else { throw fileError("Unable to write token store") }
        offset += count
      }
    }
    guard fsync(fd) == 0 else {
      unlinkat(directory, temporary, 0)
      throw fileError("Unable to persist token store")
    }
    if replacing {
      var current = stat()
      guard fstatat(directory, target.name, &current, AT_SYMLINK_NOFOLLOW) == 0,
        (current.st_mode & S_IFMT) == S_IFREG,
        current.st_dev == original.st_dev, current.st_ino == original.st_ino,
        current.st_uid == getuid(), (current.st_mode & 0o077) == 0,
        renameat(directory, temporary, directory, target.name) == 0 else {
        unlinkat(directory, temporary, 0)
        throw fileError("OAuth token store destination changed before replacement")
      }
    } else {
      // linkat creates the destination only when it is still absent, so a file
      // appearing after validation cannot be overwritten by this persistence step.
      guard linkat(directory, temporary, directory, target.name, 0) == 0 else {
        unlinkat(directory, temporary, 0)
        throw fileError("OAuth token store destination already exists or changed")
      }
      guard unlinkat(directory, temporary, 0) == 0 else {
        throw fileError("Unable to finalize token store")
      }
    }
    guard fsync(directory) == 0 else {
      throw fileError("Unable to finalize token store")
    }
  }

  /// Removes a private regular file, returning false when it was already absent.
  public static func deleteRegularFile(path: String) throws -> Bool {
    try readAndDeletePrivateFile(path: path, maximumBytes: 0) { _ in }
  }

  /// Reads a private file, hands the bytes to `validate`, and unlinks the entry
  /// only if it is still the same inode that was validated.
  public static func readAndDeletePrivateFile(
    path: String,
    maximumBytes: Int,
    validate: (Data) throws -> Void
  ) throws -> Bool {
    let target = try Target(path: path)
    let directory = try openDirectory(target.directory)
    defer { close(directory) }
    try validatePrivateDirectory(directory)
    let fd = openat(directory, target.name, O_RDONLY | O_NOFOLLOW)
    if fd < 0 {
      if errno == ENOENT { return false }
      throw fileError("Unable to inspect token store")
    }
    defer { close(fd) }
    var metadata = stat()
    guard fstat(fd, &metadata) == 0, (metadata.st_mode & S_IFMT) == S_IFREG,
      metadata.st_uid == getuid(), (metadata.st_mode & 0o077) == 0 else {
      throw fileError("OAuth token store is not a regular file")
    }
    var data = Data()
    if maximumBytes > 0 {
      var buffer = [UInt8](repeating: 0, count: 16_384)
      while true {
        let count = read(fd, &buffer, buffer.count)
        guard count >= 0 else { throw fileError("Unable to read token store") }
        if count == 0 { break }
        guard data.count + count <= maximumBytes else {
          throw sizeError("OAuth token store exceeds the allowed size")
        }
        data.append(buffer, count: count)
      }
    }
    try validate(data)
    var verified = stat()
    guard fstat(fd, &verified) == 0,
      metadata.st_dev == verified.st_dev, metadata.st_ino == verified.st_ino else {
      throw fileError("OAuth token store changed before deletion")
    }
    var entry = stat()
    guard fstatat(directory, target.name, &entry, AT_SYMLINK_NOFOLLOW) == 0,
      (entry.st_mode & S_IFMT) == S_IFREG,
      entry.st_dev == metadata.st_dev, entry.st_ino == metadata.st_ino else {
      throw fileError("OAuth token store changed before deletion")
    }
    guard unlinkat(directory, target.name, 0) == 0 else {
      throw fileError("Unable to remove token store")
    }
    return true
  }

  /// Reports whether a path entry exists without following a final symlink.
  ///
  /// Used only for status reporting, never as a precondition for an operation:
  /// the answer is stale the moment it is returned.
  public static func pathEntryExists(path: String) -> Bool {
    var metadata = stat()
    return lstat(path, &metadata) == 0
  }

  /// Rejects empty, oversized, and control-character-bearing path strings
  /// before any of them reaches a syscall.
  public static func isSafePath(_ value: String) -> Bool {
    !value.isEmpty && value.utf8.count <= 1_024 && !value.utf8.contains(where: { $0 < 32 || $0 == 127 })
  }

  private static func validatePrivateDirectory(_ fd: Int32) throws {
    var metadata = stat()
    guard fstat(fd, &metadata) == 0, (metadata.st_mode & S_IFMT) == S_IFDIR,
      metadata.st_uid == getuid(), (metadata.st_mode & 0o077) == 0 else {
      throw fileError("OAuth token-store directory is not private")
    }
  }

  private static func openDirectory(_ components: [String]) throws -> Int32 {
    var fd = open("/", O_RDONLY | O_DIRECTORY)
    guard fd >= 0 else { throw fileError("Unable to open filesystem root") }
    for component in components {
      let next = openat(fd, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
      close(fd)
      guard next >= 0 else { throw fileError("Configured path contains an unsafe directory") }
      fd = next
    }
    return fd
  }

  private static func fileError(_ message: String) -> GatewayError {
    GatewayError(code: .fileOperationFailed, message: message)
  }

  private static func sizeError(_ message: String) -> GatewayError {
    GatewayError(code: .validationError, message: message)
  }

  private struct Target {
    let directory: [String]
    let name: String
    init(path: String) throws {
      guard SecureLocalFiles.isSafePath(path) else {
        throw GatewayError(code: .validationError, message: "Configured path is invalid")
      }
      let resolved = path.hasPrefix("/") ? path : FileManager.default.currentDirectoryPath + "/" + path
      let parts = resolved.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
      guard !parts.isEmpty, parts.allSatisfy({ $0 != "." && $0 != ".." }), let name = parts.last else {
        throw GatewayError(code: .validationError, message: "Configured path is invalid")
      }
      directory = Array(parts.dropLast())
      self.name = name
    }
  }
}
