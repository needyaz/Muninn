import Testing
import Foundation
@testable import Muninn

@Suite("DataPorter", .serialized)
struct DataPorterTests {

    // MARK: - Helpers

    private func withTempEnv(_ body: (URL) throws -> Void) throws {
        let dir = makeTempDir()
        StoragePaths.baseOverride = dir
        try FileManager.default.createDirectory(
            at: dir.appendingPathComponent("blobs", isDirectory: true),
            withIntermediateDirectories: true
        )
        defer {
            StoragePaths.baseOverride = nil
            removeTempDir(dir)
        }
        try body(dir)
    }

    private func writeExportFile(_ envelope: DataPorter.ExportEnvelope, in dir: URL) throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(envelope)
        let file = dir.appendingPathComponent("test.muninn")
        try data.write(to: file, options: .atomic)
        return file
    }

    private func makeEnvelope(
        history: [HistoryItem] = [],
        clips: [Clip] = [],
        excludedApps: [String] = [],
        excludedTypes: [String]? = nil,
        blobs: [String: String] = [:],
        settings: DataPorter.ExportEnvelope.Settings? = nil
    ) -> DataPorter.ExportEnvelope {
        DataPorter.ExportEnvelope(
            version: 1,
            exportDate: Date(),
            settings: settings ?? DataPorter.ExportEnvelope.Settings(
                historyLimit: 50,
                pasteAsPlainText: false
            ),
            history: history,
            clips: clips,
            excludedApps: excludedApps,
            excludedTypes: excludedTypes,
            blobs: blobs
        )
    }

    private func makeStores() -> (HistoryStore, ClipStore, ExcludedAppsStore, ExcludedTypesStore, SettingsStore) {
        let settings = SettingsStore()
        let history = HistoryStore(settingsStore: settings)
        let clips = ClipStore()
        let excludedApps = ExcludedAppsStore()
        let excludedTypes = ExcludedTypesStore()
        return (history, clips, excludedApps, excludedTypes, settings)
    }

    // MARK: - Import replace

    @Test("import replace with text history and clips")
    func importReplaceText() throws {
        try withTempEnv { dir in
            let historyItem = HistoryItem(
                id: UUID(),
                value: "copied text",
                timestamp: Date(),
                contentType: .text,
                sourceAppBundleID: "com.apple.Safari"
            )
            let clip = Clip(
                id: UUID(),
                name: "My Snippet",
                value: "snippet value",
                contentType: .text
            )
            let envelope = makeEnvelope(history: [historyItem], clips: [clip])
            let file = try writeExportFile(envelope, in: dir)

            let (historyStore, clipStore, excludedAppsStore, excludedTypesStore, settingsStore) = makeStores()
            let result = try DataPorter.importData(
                from: file,
                merge: false,
                historyStore: historyStore,
                clipStore: clipStore,
                excludedAppsStore: excludedAppsStore,
                excludedTypesStore: excludedTypesStore,
                settingsStore: settingsStore
            )

            #expect(result.historyCount == 1)
            #expect(result.clipCount == 1)
            #expect(historyStore.items.count == 1)
            #expect(historyStore.items.first?.value == "copied text")
            #expect(historyStore.items.first?.sourceAppBundleID == "com.apple.Safari")
            #expect(clipStore.clips.count == 1)
            #expect(clipStore.clips.first?.name == "My Snippet")
            #expect(clipStore.clips.first?.value == "snippet value")
        }
    }

    @Test("import replace with image history item and blob")
    func importReplaceImage() throws {
        try withTempEnv { dir in
            let blobID = UUID()
            let blobFilename = "\(blobID.uuidString).png"
            let imageData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG magic bytes
            let historyItem = HistoryItem(
                id: UUID(),
                value: "screenshot.png",
                timestamp: Date(),
                contentType: .image,
                blobFile: blobFilename,
                ocrText: "Hello World"
            )
            let envelope = makeEnvelope(
                history: [historyItem],
                blobs: [blobFilename: imageData.base64EncodedString()]
            )
            let file = try writeExportFile(envelope, in: dir)

            let (historyStore, clipStore, excludedAppsStore, excludedTypesStore, settingsStore) = makeStores()
            let result = try DataPorter.importData(
                from: file,
                merge: false,
                historyStore: historyStore,
                clipStore: clipStore,
                excludedAppsStore: excludedAppsStore,
                excludedTypesStore: excludedTypesStore,
                settingsStore: settingsStore
            )

            #expect(result.historyCount == 1)
            #expect(result.imageCount == 1)
            #expect(historyStore.items.first?.contentType == .image)
            #expect(historyStore.items.first?.ocrText == "Hello World")

            // Verify blob was written
            let blobPath = dir.appendingPathComponent("blobs").appendingPathComponent(blobFilename)
            #expect(FileManager.default.fileExists(atPath: blobPath.path))
            #expect(try Data(contentsOf: blobPath) == imageData)
        }
    }

    @Test("import replace with PDF history item")
    func importReplacePDF() throws {
        try withTempEnv { dir in
            let blobID = UUID()
            let blobFilename = "\(blobID.uuidString).pdf"
            let pdfData = Data("%PDF-1.4".utf8)
            let historyItem = HistoryItem(
                id: UUID(),
                timestamp: Date(),
                contentType: .pdf,
                blobFile: blobFilename
            )
            let envelope = makeEnvelope(
                history: [historyItem],
                blobs: [blobFilename: pdfData.base64EncodedString()]
            )
            let file = try writeExportFile(envelope, in: dir)

            let (historyStore, clipStore, excludedAppsStore, excludedTypesStore, settingsStore) = makeStores()
            let result = try DataPorter.importData(
                from: file,
                merge: false,
                historyStore: historyStore,
                clipStore: clipStore,
                excludedAppsStore: excludedAppsStore,
                excludedTypesStore: excludedTypesStore,
                settingsStore: settingsStore
            )

            #expect(result.historyCount == 1)
            #expect(result.pdfCount == 1)
            #expect(historyStore.items.first?.contentType == .pdf)
        }
    }

    @Test("import replace with color history item")
    func importReplaceColor() throws {
        try withTempEnv { dir in
            let historyItem = HistoryItem(
                id: UUID(),
                timestamp: Date(),
                contentType: .color,
                colorComponents: [1.0, 0.0, 0.0, 1.0]
            )
            let envelope = makeEnvelope(history: [historyItem])
            let file = try writeExportFile(envelope, in: dir)

            let (historyStore, clipStore, excludedAppsStore, excludedTypesStore, settingsStore) = makeStores()
            let result = try DataPorter.importData(
                from: file,
                merge: false,
                historyStore: historyStore,
                clipStore: clipStore,
                excludedAppsStore: excludedAppsStore,
                excludedTypesStore: excludedTypesStore,
                settingsStore: settingsStore
            )

            #expect(result.historyCount == 1)
            #expect(historyStore.items.first?.contentType == .color)
            #expect(historyStore.items.first?.colorComponents == [1.0, 0.0, 0.0, 1.0])
        }
    }

    @Test("import replace with fileURL history item restores file from blob")
    func importReplaceFileURL() throws {
        try withTempEnv { dir in
            let blobID = UUID()
            let blobFilename = "\(blobID.uuidString).png"
            let fileData = Data("file contents".utf8)
            let historyItem = HistoryItem(
                id: UUID(),
                timestamp: Date(),
                contentType: .fileURL,
                blobFile: blobFilename,
                fileURLs: ["/Users/test/Documents/photo.png"]
            )
            let envelope = makeEnvelope(
                history: [historyItem],
                blobs: [blobFilename: fileData.base64EncodedString()]
            )
            let file = try writeExportFile(envelope, in: dir)

            let (historyStore, clipStore, excludedAppsStore, excludedTypesStore, settingsStore) = makeStores()
            let result = try DataPorter.importData(
                from: file,
                merge: false,
                historyStore: historyStore,
                clipStore: clipStore,
                excludedAppsStore: excludedAppsStore,
                excludedTypesStore: excludedTypesStore,
                settingsStore: settingsStore
            )

            #expect(result.historyCount == 1)
            #expect(historyStore.items.first?.contentType == .fileURL)
            // fileURLs should be updated to point to the restored file in the files/ directory
            let restoredPath = historyStore.items.first?.fileURLs?.first
            #expect(restoredPath != nil)
            #expect(restoredPath!.hasSuffix("photo.png"))
            #expect(FileManager.default.fileExists(atPath: restoredPath!))
        }
    }

    @Test("import replace with rich text blob")
    func importReplaceRichText() throws {
        try withTempEnv { dir in
            let blobID = UUID()
            let blobFilename = "\(blobID.uuidString).rtf"
            let rtfData = Data("{\\rtf1 Hello}".utf8)
            let historyItem = HistoryItem(
                id: UUID(),
                value: "Hello",
                timestamp: Date(),
                contentType: .text,
                blobFile: blobFilename
            )
            let envelope = makeEnvelope(
                history: [historyItem],
                blobs: [blobFilename: rtfData.base64EncodedString()]
            )
            let file = try writeExportFile(envelope, in: dir)

            let (historyStore, clipStore, excludedAppsStore, excludedTypesStore, settingsStore) = makeStores()
            let result = try DataPorter.importData(
                from: file,
                merge: false,
                historyStore: historyStore,
                clipStore: clipStore,
                excludedAppsStore: excludedAppsStore,
                excludedTypesStore: excludedTypesStore,
                settingsStore: settingsStore
            )

            #expect(result.richTextCount == 1)
            #expect(historyStore.items.first?.value == "Hello")
            #expect(historyStore.items.first?.blobFile == blobFilename)
        }
    }

    @Test("import replace with image clip and blob")
    func importReplaceImageClip() throws {
        try withTempEnv { dir in
            let blobID = UUID()
            let blobFilename = "\(blobID.uuidString).tiff"
            let imageData = Data([0x49, 0x49, 0x2A, 0x00]) // TIFF magic bytes
            let clip = Clip(
                id: UUID(),
                name: "Logo",
                contentType: .image,
                blobFile: blobFilename
            )
            let envelope = makeEnvelope(
                clips: [clip],
                blobs: [blobFilename: imageData.base64EncodedString()]
            )
            let file = try writeExportFile(envelope, in: dir)

            let (historyStore, clipStore, excludedAppsStore, excludedTypesStore, settingsStore) = makeStores()
            let result = try DataPorter.importData(
                from: file,
                merge: false,
                historyStore: historyStore,
                clipStore: clipStore,
                excludedAppsStore: excludedAppsStore,
                excludedTypesStore: excludedTypesStore,
                settingsStore: settingsStore
            )

            #expect(result.clipCount == 1)
            #expect(result.imageCount == 1)
            #expect(clipStore.clips.count == 1)
            #expect(clipStore.clips.first?.name == "Logo")
            #expect(clipStore.clips.first?.contentType == .image)

            let blobPath = dir.appendingPathComponent("blobs").appendingPathComponent(blobFilename)
            #expect(try Data(contentsOf: blobPath) == imageData)
        }
    }

    @Test("import replace with color clip")
    func importReplaceColorClip() throws {
        try withTempEnv { dir in
            let clip = Clip(
                id: UUID(),
                name: "Brand Red",
                contentType: .color,
                colorComponents: [0.8, 0.1, 0.1, 1.0]
            )
            let envelope = makeEnvelope(clips: [clip])
            let file = try writeExportFile(envelope, in: dir)

            let (historyStore, clipStore, excludedAppsStore, excludedTypesStore, settingsStore) = makeStores()
            let _ = try DataPorter.importData(
                from: file,
                merge: false,
                historyStore: historyStore,
                clipStore: clipStore,
                excludedAppsStore: excludedAppsStore,
                excludedTypesStore: excludedTypesStore,
                settingsStore: settingsStore
            )

            #expect(clipStore.clips.count == 1)
            #expect(clipStore.clips.first?.name == "Brand Red")
            #expect(clipStore.clips.first?.colorComponents == [0.8, 0.1, 0.1, 1.0])
        }
    }

    @Test("import replace with fileURL clip restores file from blob")
    func importReplaceFileURLClip() throws {
        try withTempEnv { dir in
            let blobID = UUID()
            let blobFilename = "\(blobID.uuidString).png"
            let fileData = Data("clip file".utf8)
            let clip = Clip(
                id: UUID(),
                name: "My File",
                contentType: .fileURL,
                blobFile: blobFilename,
                fileURLs: ["/Users/test/readme.png"]
            )
            let envelope = makeEnvelope(
                clips: [clip],
                blobs: [blobFilename: fileData.base64EncodedString()]
            )
            let file = try writeExportFile(envelope, in: dir)

            let (historyStore, clipStore, excludedAppsStore, excludedTypesStore, settingsStore) = makeStores()
            let _ = try DataPorter.importData(
                from: file,
                merge: false,
                historyStore: historyStore,
                clipStore: clipStore,
                excludedAppsStore: excludedAppsStore,
                excludedTypesStore: excludedTypesStore,
                settingsStore: settingsStore
            )

            #expect(clipStore.clips.count == 1)
            let restoredPath = clipStore.clips.first?.fileURLs?.first
            #expect(restoredPath != nil)
            #expect(restoredPath!.hasSuffix("readme.png"))
        }
    }

    // MARK: - Excluded apps and types

    @Test("import replace with excluded apps and types")
    func importReplaceExclusions() throws {
        try withTempEnv { dir in
            let envelope = makeEnvelope(
                excludedApps: ["com.app.one", "com.app.two"],
                excludedTypes: ["image", "pdf"]
            )
            let file = try writeExportFile(envelope, in: dir)

            let (historyStore, clipStore, excludedAppsStore, excludedTypesStore, settingsStore) = makeStores()
            let result = try DataPorter.importData(
                from: file,
                merge: false,
                historyStore: historyStore,
                clipStore: clipStore,
                excludedAppsStore: excludedAppsStore,
                excludedTypesStore: excludedTypesStore,
                settingsStore: settingsStore
            )

            #expect(result.excludedAppCount == 2)
            #expect(result.excludedTypeCount == 2)
            #expect(excludedAppsStore.isExcluded("com.app.one"))
            #expect(excludedAppsStore.isExcluded("com.app.two"))
            #expect(excludedTypesStore.isExcluded(.image))
            #expect(excludedTypesStore.isExcluded(.pdf))
        }
    }

    // MARK: - Import merge

    @Test("import merge adds new items, keeps existing")
    func importMerge() throws {
        try withTempEnv { dir in
            // Pre-populate with existing data
            let existingHistoryID = UUID()
            let existingHistory = [HistoryItem(id: existingHistoryID, value: "existing", timestamp: Date(), contentType: .text)]
            let existingClipID = UUID()
            let existingClips = [Clip(id: existingClipID, name: "Existing Clip", value: "existing value")]

            let encoder = JSONEncoder()
            try encoder.encode(existingHistory).write(to: dir.appendingPathComponent("history.json"), options: .atomic)
            try encoder.encode(existingClips).write(to: dir.appendingPathComponent("clips.json"), options: .atomic)

            let (historyStore, clipStore, excludedAppsStore, excludedTypesStore, settingsStore) = makeStores()

            // Import new data (different IDs)
            let newHistoryItem = HistoryItem(id: UUID(), value: "imported", timestamp: Date(), contentType: .text)
            let newClip = Clip(id: UUID(), name: "Imported Clip", value: "imported value")
            let envelope = makeEnvelope(history: [newHistoryItem], clips: [newClip])
            let file = try writeExportFile(envelope, in: dir)

            let result = try DataPorter.importData(
                from: file,
                merge: true,
                historyStore: historyStore,
                clipStore: clipStore,
                excludedAppsStore: excludedAppsStore,
                excludedTypesStore: excludedTypesStore,
                settingsStore: settingsStore
            )

            #expect(result.historyCount == 1) // only new items counted
            #expect(result.clipCount == 1)
            #expect(historyStore.items.count == 2)
            #expect(clipStore.clips.count == 2)
            // Existing items still present
            #expect(historyStore.items.contains { $0.id == existingHistoryID })
            #expect(clipStore.clips.contains { $0.id == existingClipID })
        }
    }

    @Test("import merge deduplicates by ID")
    func importMergeDedup() throws {
        try withTempEnv { dir in
            let sharedID = UUID()
            let existingHistory = [HistoryItem(id: sharedID, value: "original", timestamp: Date(), contentType: .text)]
            try JSONEncoder().encode(existingHistory).write(to: dir.appendingPathComponent("history.json"), options: .atomic)

            let (historyStore, clipStore, excludedAppsStore, excludedTypesStore, settingsStore) = makeStores()

            // Import item with same ID
            let dupeItem = HistoryItem(id: sharedID, value: "duplicate", timestamp: Date(), contentType: .text)
            let envelope = makeEnvelope(history: [dupeItem])
            let file = try writeExportFile(envelope, in: dir)

            let result = try DataPorter.importData(
                from: file,
                merge: true,
                historyStore: historyStore,
                clipStore: clipStore,
                excludedAppsStore: excludedAppsStore,
                excludedTypesStore: excludedTypesStore,
                settingsStore: settingsStore
            )

            #expect(result.historyCount == 0) // duplicate not counted
            #expect(historyStore.items.count == 1)
            #expect(historyStore.items.first?.value == "original") // existing kept
        }
    }

    @Test("import merge does not overwrite existing blobs")
    func importMergePreservesBlobs() throws {
        try withTempEnv { dir in
            let blobFilename = "\(UUID().uuidString).png"
            let existingData = Data("existing blob".utf8)
            let importedData = Data("imported blob".utf8)

            // Write an existing blob
            let blobPath = dir.appendingPathComponent("blobs").appendingPathComponent(blobFilename)
            try existingData.write(to: blobPath, options: .atomic)

            let (historyStore, clipStore, excludedAppsStore, excludedTypesStore, settingsStore) = makeStores()

            let envelope = makeEnvelope(
                blobs: [blobFilename: importedData.base64EncodedString()]
            )
            let file = try writeExportFile(envelope, in: dir)

            let _ = try DataPorter.importData(
                from: file,
                merge: true,
                historyStore: historyStore,
                clipStore: clipStore,
                excludedAppsStore: excludedAppsStore,
                excludedTypesStore: excludedTypesStore,
                settingsStore: settingsStore
            )

            // Existing blob should NOT be overwritten
            #expect(try Data(contentsOf: blobPath) == existingData)
        }
    }

    @Test("import merge unions excluded apps")
    func importMergeExcludedApps() throws {
        try withTempEnv { dir in
            let existing: Set<String> = ["com.existing.app"]
            try JSONEncoder().encode(existing).write(to: dir.appendingPathComponent("excluded_apps.json"), options: .atomic)

            let (historyStore, clipStore, excludedAppsStore, excludedTypesStore, settingsStore) = makeStores()

            let envelope = makeEnvelope(excludedApps: ["com.existing.app", "com.new.app"])
            let file = try writeExportFile(envelope, in: dir)

            let result = try DataPorter.importData(
                from: file,
                merge: true,
                historyStore: historyStore,
                clipStore: clipStore,
                excludedAppsStore: excludedAppsStore,
                excludedTypesStore: excludedTypesStore,
                settingsStore: settingsStore
            )

            #expect(result.excludedAppCount == 1) // only the new one counted
            #expect(excludedAppsStore.isExcluded("com.existing.app"))
            #expect(excludedAppsStore.isExcluded("com.new.app"))
        }
    }

    // MARK: - Settings

    @Test("import replace applies settings")
    func importReplaceSettings() throws {
        try withTempEnv { dir in
            let settings = DataPorter.ExportEnvelope.Settings(
                historyLimit: 200,
                pasteAsPlainText: true,
                enableStats: false,
                enableRichPreviews: false,
                captureSound: "Pop",
                captureScreenshots: true,
                enableOCR: true,
                enableQRDetection: true,
                popoverHeight: 600.0,
                sensitiveHandling: "allow"
            )
            let envelope = makeEnvelope(settings: settings)
            let file = try writeExportFile(envelope, in: dir)

            let (historyStore, clipStore, excludedAppsStore, excludedTypesStore, settingsStore) = makeStores()
            let _ = try DataPorter.importData(
                from: file,
                merge: false,
                historyStore: historyStore,
                clipStore: clipStore,
                excludedAppsStore: excludedAppsStore,
                excludedTypesStore: excludedTypesStore,
                settingsStore: settingsStore
            )

            #expect(settingsStore.historyLimit == 200)
            #expect(settingsStore.pasteAsPlainText == true)
            #expect(settingsStore.enableStats == false)
            #expect(settingsStore.enableRichPreviews == false)
            #expect(settingsStore.captureSound == "Pop")
            #expect(settingsStore.captureScreenshots == true)
            #expect(settingsStore.enableOCR == true)
            #expect(settingsStore.enableQRDetection == true)
            #expect(settingsStore.popoverHeight == 600.0)
            #expect(settingsStore.sensitiveHandling == "allow")
        }
    }

    // MARK: - Error handling

    @Test("unsupported version throws")
    func unsupportedVersion() throws {
        try withTempEnv { dir in
            var envelope = makeEnvelope()
            envelope.version = 99
            let file = try writeExportFile(envelope, in: dir)

            let (historyStore, clipStore, excludedAppsStore, excludedTypesStore, settingsStore) = makeStores()
            #expect(throws: DataPorter.PorterError.self) {
                try DataPorter.importData(
                    from: file,
                    merge: false,
                    historyStore: historyStore,
                    clipStore: clipStore,
                    excludedAppsStore: excludedAppsStore,
                    excludedTypesStore: excludedTypesStore,
                    settingsStore: settingsStore
                )
            }
        }
    }

    // MARK: - Mixed content types

    @Test("import replace with all content types at once")
    func importReplaceAllTypes() throws {
        try withTempEnv { dir in
            let imgBlob = "\(UUID().uuidString).png"
            let pdfBlob = "\(UUID().uuidString).pdf"
            let rtfBlob = "\(UUID().uuidString).rtf"

            let history: [HistoryItem] = [
                HistoryItem(id: UUID(), value: "plain text", timestamp: Date(), contentType: .text),
                HistoryItem(id: UUID(), value: "screenshot.png", timestamp: Date(), contentType: .image, blobFile: imgBlob, ocrText: "OCR result"),
                HistoryItem(id: UUID(), timestamp: Date(), contentType: .pdf, blobFile: pdfBlob),
                HistoryItem(id: UUID(), timestamp: Date(), contentType: .color, colorComponents: [0.0, 1.0, 0.0, 1.0]),
                HistoryItem(id: UUID(), value: "rich text", timestamp: Date(), contentType: .text, blobFile: rtfBlob),
            ]
            let clips: [Clip] = [
                Clip(id: UUID(), name: "Text Clip", value: "clip text"),
                Clip(id: UUID(), name: "Color Clip", contentType: .color, colorComponents: [0.5, 0.5, 0.5, 1.0]),
            ]

            let blobs: [String: String] = [
                imgBlob: Data([0x89, 0x50]).base64EncodedString(),
                pdfBlob: Data("%PDF".utf8).base64EncodedString(),
                rtfBlob: Data("{\\rtf1}".utf8).base64EncodedString(),
            ]

            let envelope = makeEnvelope(
                history: history,
                clips: clips,
                excludedApps: ["com.test.app"],
                excludedTypes: ["color"],
                blobs: blobs
            )
            let file = try writeExportFile(envelope, in: dir)

            let (historyStore, clipStore, excludedAppsStore, excludedTypesStore, settingsStore) = makeStores()
            let result = try DataPorter.importData(
                from: file,
                merge: false,
                historyStore: historyStore,
                clipStore: clipStore,
                excludedAppsStore: excludedAppsStore,
                excludedTypesStore: excludedTypesStore,
                settingsStore: settingsStore
            )

            #expect(result.historyCount == 5)
            #expect(result.clipCount == 2)
            #expect(result.imageCount == 1)
            #expect(result.pdfCount == 1)
            #expect(result.richTextCount == 1)
            #expect(result.excludedAppCount == 1)
            #expect(result.excludedTypeCount == 1)
            #expect(historyStore.items.count == 5)
            #expect(clipStore.clips.count == 2)
        }
    }

    // MARK: - Export structure

    @Test("buildExportData produces valid JSON with expected fields")
    func exportStructure() throws {
        try withTempEnv { dir in
            // Write some test data
            let history = [HistoryItem(id: UUID(), value: "test", timestamp: Date(), contentType: .text)]
            let clips = [Clip(id: UUID(), name: "Test Clip", value: "test value")]
            let encoder = JSONEncoder()
            try encoder.encode(history).write(to: dir.appendingPathComponent("history.json"), options: .atomic)
            try encoder.encode(clips).write(to: dir.appendingPathComponent("clips.json"), options: .atomic)

            let exportData = try DataPorter.buildExportData()
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(DataPorter.ExportEnvelope.self, from: exportData)

            #expect(envelope.version == 1)
            #expect(envelope.history.count == 1)
            #expect(envelope.history.first?.value == "test")
            #expect(envelope.clips.count == 1)
            #expect(envelope.clips.first?.name == "Test Clip")
        }
    }

    @Test("export includes blobs as base64")
    func exportBlobsBase64() throws {
        try withTempEnv { dir in
            let blobData = Data("blob content".utf8)
            let blobFilename = "test-blob.png"
            try blobData.write(
                to: dir.appendingPathComponent("blobs").appendingPathComponent(blobFilename),
                options: .atomic
            )

            let exportData = try DataPorter.buildExportData()
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(DataPorter.ExportEnvelope.self, from: exportData)

            #expect(envelope.blobs[blobFilename] != nil)
            let decoded = Data(base64Encoded: envelope.blobs[blobFilename]!)
            #expect(decoded == blobData)
        }
    }

    // MARK: - Round-trip

    @Test("export then import round-trip preserves data")
    func roundTrip() throws {
        try withTempEnv { dir in
            // Write test data
            let originalHistory = [
                HistoryItem(id: UUID(), value: "round-trip text", timestamp: Date(), contentType: .text),
                HistoryItem(id: UUID(), timestamp: Date(), contentType: .color, colorComponents: [1.0, 0.0, 0.0, 1.0]),
            ]
            let originalClips = [
                Clip(id: UUID(), name: "RT Clip", value: "round-trip clip"),
            ]
            let encoder = JSONEncoder()
            try encoder.encode(originalHistory).write(to: dir.appendingPathComponent("history.json"), options: .atomic)
            try encoder.encode(originalClips).write(to: dir.appendingPathComponent("clips.json"), options: .atomic)
            try JSONEncoder().encode(["com.test.excluded"]).write(to: dir.appendingPathComponent("excluded_apps.json"), options: .atomic)

            let blobData = Data("round-trip blob".utf8)
            try blobData.write(to: dir.appendingPathComponent("blobs/test.png"), options: .atomic)

            // Export
            let exportData = try DataPorter.buildExportData()
            let exportFile = dir.appendingPathComponent("export.muninn")
            try exportData.write(to: exportFile, options: .atomic)

            // Clear the directory
            for file in ["history.json", "clips.json", "excluded_apps.json"] {
                try? FileManager.default.removeItem(at: dir.appendingPathComponent(file))
            }
            try? FileManager.default.removeItem(at: dir.appendingPathComponent("blobs/test.png"))

            // Import
            let (historyStore, clipStore, excludedAppsStore, excludedTypesStore, settingsStore) = makeStores()
            let _ = try DataPorter.importData(
                from: exportFile,
                merge: false,
                historyStore: historyStore,
                clipStore: clipStore,
                excludedAppsStore: excludedAppsStore,
                excludedTypesStore: excludedTypesStore,
                settingsStore: settingsStore
            )

            #expect(historyStore.items.count == 2)
            #expect(historyStore.items.contains { $0.value == "round-trip text" })
            #expect(historyStore.items.contains { $0.contentType == .color })
            #expect(clipStore.clips.count == 1)
            #expect(clipStore.clips.first?.name == "RT Clip")
            #expect(excludedAppsStore.isExcluded("com.test.excluded"))

            // Blob restored
            let restoredBlob = dir.appendingPathComponent("blobs/test.png")
            #expect(FileManager.default.fileExists(atPath: restoredBlob.path))
            #expect(try Data(contentsOf: restoredBlob) == blobData)
        }
    }
}
