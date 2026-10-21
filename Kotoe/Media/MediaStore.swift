//
//  MediaStore.swift
//  Kōtoe
//
//  Created by Simon Weber on 21.10.26.
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Stores card media (photos, drawings, PDFs) as files in the app's iCloud
/// Drive container instead of inline in the SwiftData store.
///
/// CloudKit limits a record to 1 MB, which forced photos to be downscaled
/// before they could sync. Files in the ubiquity container sync separately and
/// keep their original resolution. When iCloud Drive is unavailable, media
/// stays in Application Support on the current device.
enum MediaStore {

    // MARK: - Locations

    private static let containerIdentifier = "iCloud.com.erebur.kotoe"
    private static let folderName = "Media"

    /// Resolved once. `nil` means iCloud Drive is unavailable, so media is
    /// kept on this device only.
    private static let iCloudDirectory: URL? = {
        guard
            let container = FileManager.default.url(
                forUbiquityContainerIdentifier: containerIdentifier
            )
        else {
            print("[Media] iCloud Drive is unavailable; using local storage.")
            return nil
        }

        let media = container
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent(folderName, isDirectory: true)

        do {
            try FileManager.default.createDirectory(
                at: media,
                withIntermediateDirectories: true
            )
            return media
        } catch {
            print("[Media] Could not create the iCloud folder: \(error)")
            return nil
        }
    }()

    private static let localDirectory: URL = {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        let media = base.appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: media,
            withIntermediateDirectories: true
        )
        return media
    }()

    /// Folder that receives new media. Existing files keep the folder they
    /// were written to, which `url(named:)` resolves by name.
    private static var directory: URL { iCloudDirectory ?? localDirectory }

    static var isUsingICloud: Bool { iCloudDirectory != nil }

    // MARK: - URLs

    static func url(named name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    // MARK: - Writing

    /// Writes `data` to the media folder and returns the generated file name.
    /// Returns `nil` when the file could not be written.
    static func save(data: Data, fileExtension: String) -> String? {
        let name = "\(UUID().uuidString).\(fileExtension)"
        let target = url(named: name)

        var coordinationError: NSError?
        var writeError: Error?

        NSFileCoordinator().coordinate(
            writingItemAt: target,
            options: .forReplacing,
            error: &coordinationError
        ) { coordinatedURL in
            do {
                try data.write(to: coordinatedURL, options: .atomic)
            } catch {
                writeError = error
            }
        }

        if let coordinationError {
            print("[Media] Could not coordinate \(name): \(coordinationError)")
            return nil
        }

        if let writeError {
            print("[Media] Could not write \(name): \(writeError)")
            return nil
        }

        return name
    }

    /// Removes a media file. Missing files are ignored.
    static func remove(named name: String) {
        let target = url(named: name)

        var coordinationError: NSError?
        NSFileCoordinator().coordinate(
            writingItemAt: target,
            options: .forDeleting,
            error: &coordinationError
        ) { coordinatedURL in
            try? FileManager.default.removeItem(at: coordinatedURL)
        }

        if let coordinationError {
            print("[Media] Could not remove \(name): \(coordinationError)")
        }
    }

    // MARK: - Reading

    /// Number of media files currently on this device (including files that
    /// are still only present as iCloud placeholders).
    static func hasFile(named name: String) -> Bool {
        let target = url(named: name)
        if FileManager.default.fileExists(atPath: target.path) {
            return true
        }

        // A file that has not been downloaded yet is represented by a
        // `.name.icloud` placeholder in the same folder.
        let placeholder = directory.appendingPathComponent(".\(name).icloud")
        return FileManager.default.fileExists(atPath: placeholder.path)
    }

    /// Data for a file that is already on this device. Returns `nil` for
    /// iCloud placeholders, so callers never block on a download.
    static func dataIfDownloaded(named name: String) -> Data? {
        let target = url(named: name)
        guard FileManager.default.fileExists(atPath: target.path) else {
            return nil
        }
        return read(target)
    }

    /// Loads a file, asking iCloud Drive to download it first when needed.
    static func loadData(named name: String) async -> Data? {
        if let data = dataIfDownloaded(named: name) {
            return data
        }

        let target = url(named: name)

        // The model record can arrive before iCloud Drive finishes uploading
        // the file, so wait briefly before giving up.
        if await waitForFile(at: target, attempts: 8) {
            return read(target)
        }

        // Reading a placeholder makes iCloud download it. The read can block,
        // so keep it off the main actor.
        return await Task.detached(priority: .userInitiated) {
            read(target)
        }.value
    }

    /// Resolves a file URL for readers that need a URL (PDFKit), waiting for
    /// an iCloud download when necessary.
    static func loadURL(named name: String) async -> URL? {
        let target = url(named: name)

        if FileManager.default.fileExists(atPath: target.path) {
            return target
        }

        if await waitForFile(at: target) {
            return target
        }

        // Last resort: a coordinated read waits for a slow download.
        _ = await Task.detached(priority: .userInitiated) {
            read(target)
        }.value

        return FileManager.default.fileExists(atPath: target.path)
            ? target
            : nil
    }

    /// Polls for a file while asking iCloud Drive to download it.
    private static func waitForFile(
        at url: URL,
        attempts: Int = 40
    ) async -> Bool {
        for _ in 0..<attempts {
            if FileManager.default.fileExists(atPath: url.path) {
                return true
            }

            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            try? await Task.sleep(for: .milliseconds(250))
        }

        return FileManager.default.fileExists(atPath: url.path)
    }

    private static func read(_ url: URL) -> Data? {
        var coordinationError: NSError?
        var data: Data?

        NSFileCoordinator().coordinate(
            readingItemAt: url,
            options: [],
            error: &coordinationError
        ) { coordinatedURL in
            data = try? Data(contentsOf: coordinatedURL)
        }

        if let coordinationError {
            print("[Media] Could not read \(url.lastPathComponent): "
                + "\(coordinationError)")
        }

        return data
    }

    // MARK: - File Type Helpers

    /// File extension that matches the encoded image, so originals keep their
    /// format (JPEG, HEIC, PNG) instead of being re-encoded.
    static func imageExtension(for data: Data) -> String {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let identifier = CGImageSourceGetType(source) as String?,
            let type = UTType(identifier),
            let fileExtension = type.preferredFilenameExtension
        else {
            return "jpg"
        }

        return fileExtension
    }
}
