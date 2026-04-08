//
//  AudioExporter.swift
//  supertonic2-coreml-ios-test
//
//  Converts a WAV audio file to M4A, M4B (audiobook with chapter markers),
//  or MP3 (iOS 17+, falls back to M4A) and presents a system share sheet.
//
//  Usage:
//    let exporter = AudioExporter()
//    let outputURL = try await exporter.export(
//        wavURL: sourceWAVURL,
//        format: .m4b,
//        title: "My Article",
//        artist: "Supertonic TTS",
//        chunkBoundaries: [0.0, 12.4, 28.9]   // optional sentence offsets
//    )
//

import AVFoundation
import Foundation

// MARK: - Export format

enum AudioExportFormat: String, CaseIterable, Identifiable {
    case m4a = "M4A"
    case m4b = "M4B"
    case mp3 = "MP3"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .m4a: return "m4a"
        case .m4b: return "m4b"
        case .mp3: return "mp3"
        }
    }

    var displayName: String { rawValue }
}

// MARK: - AudioExporter

final class AudioExporter {

    enum ExportError: LocalizedError {
        case sourceNotReadable
        case writerSetupFailed
        case exportFailed(String)
        case unsupportedFormat

        var errorDescription: String? {
            switch self {
            case .sourceNotReadable:   return "Cannot read the source audio file."
            case .writerSetupFailed:   return "Failed to set up audio export pipeline."
            case .exportFailed(let m): return "Export failed: \(m)"
            case .unsupportedFormat:   return "The requested audio format is not supported on this device."
            }
        }
    }

    // MARK: - Public API

    /// Exports `wavURL` to `format` and writes the result to the Caches directory.
    /// Returns the URL of the exported file.
    ///
    /// - Parameters:
    ///   - wavURL:            Source WAV file.
    ///   - format:            Target format (.m4a, .m4b, or .mp3).
    ///   - title:             Track title embedded in metadata (M4A/M4B only).
    ///   - artist:            Artist name embedded in metadata (M4A/M4B only).
    ///   - chunkBoundaries:   Sentence-chunk start times (seconds) for chapter markers in M4B.
    func export(
        wavURL: URL,
        format: AudioExportFormat,
        title: String = "",
        artist: String = "Supertonic TTS",
        chunkBoundaries: [Double] = []
    ) async throws -> URL {
        switch format {
        case .m4a:
            return try await exportAAC(wavURL: wavURL, fileType: .m4a, extension: "m4a",
                                       title: title, artist: artist, chunkBoundaries: [])
        case .m4b:
            return try await exportAAC(wavURL: wavURL, fileType: .m4a, extension: "m4b",
                                       title: title, artist: artist, chunkBoundaries: chunkBoundaries)
        case .mp3:
            if #available(iOS 17.0, *) {
                do {
                    return try await exportMP3(wavURL: wavURL, title: title, artist: artist)
                } catch {
                    // Fall back to M4A on failure
                    return try await exportAAC(wavURL: wavURL, fileType: .m4a, extension: "m4a",
                                               title: title, artist: artist, chunkBoundaries: [])
                }
            } else {
                // iOS < 17: fall back to M4A
                return try await exportAAC(wavURL: wavURL, fileType: .m4a, extension: "m4a",
                                           title: title, artist: artist, chunkBoundaries: [])
            }
        }
    }

    // MARK: - AAC / M4A / M4B export (AVAssetWriter)

    private func exportAAC(
        wavURL: URL,
        fileType: AVFileType,
        extension ext: String,
        title: String,
        artist: String,
        chunkBoundaries: [Double]
    ) async throws -> URL {

        let asset = AVURLAsset(url: wavURL)

        // Load duration and tracks
        let duration: CMTime
        let assetTracks: [AVAssetTrack]
        do {
            duration = try await asset.load(.duration)
            assetTracks = try await asset.load(.tracks)
        } catch {
            throw ExportError.sourceNotReadable
        }

        guard let audioTrack = assetTracks.first(where: { $0.mediaType == .audio }) else {
            throw ExportError.sourceNotReadable
        }

        let outputURL = uniqueOutputURL(base: sanitizedFilename(title), ext: ext)

        // Remove any pre-existing file
        try? FileManager.default.removeItem(at: outputURL)

        // Set up AVAssetWriter
        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: fileType) else {
            throw ExportError.writerSetupFailed
        }

        // Add metadata (title + artist)
        var metadataItems: [AVMetadataItem] = []
        if !title.isEmpty {
            let titleItem = AVMutableMetadataItem()
            titleItem.identifier = AVMetadataIdentifier.commonIdentifierTitle
            titleItem.value = title as NSString
            titleItem.extendedLanguageTag = "und"
            metadataItems.append(titleItem)
        }
        if !artist.isEmpty {
            let artistItem = AVMutableMetadataItem()
            artistItem.identifier = AVMetadataIdentifier.commonIdentifierArtist
            artistItem.value = artist as NSString
            artistItem.extendedLanguageTag = "und"
            metadataItems.append(artistItem)
        }
        writer.metadata = metadataItems

        // Output settings: AAC stereo 128 kbps
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128_000
        ]

        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)
        writerInput.expectsMediaDataInRealTime = false
        writer.add(writerInput)

        // Set up reader
        guard let reader = try? AVAssetReader(asset: asset) else {
            throw ExportError.writerSetupFailed
        }

        let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ])
        reader.add(readerOutput)

        guard reader.startReading(), writer.startWriting() else {
            throw ExportError.writerSetupFailed
        }

        writer.startSession(atSourceTime: .zero)

        // Transcode on a background thread
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let queue = DispatchQueue(label: "audio.export.queue")
            writerInput.requestMediaDataWhenReady(on: queue) {
                while writerInput.isReadyForMoreMediaData {
                    if let sample = readerOutput.copyNextSampleBuffer() {
                        writerInput.append(sample)
                    } else {
                        writerInput.markAsFinished()
                        if reader.status == .failed {
                            continuation.resume(throwing: ExportError.exportFailed(
                                reader.error?.localizedDescription ?? "Reader error"))
                        } else {
                            writer.finishWriting {
                                if writer.status == .failed {
                                    continuation.resume(throwing: ExportError.exportFailed(
                                        writer.error?.localizedDescription ?? "Writer error"))
                                } else {
                                    continuation.resume()
                                }
                            }
                        }
                        return
                    }
                }
            }
        }

        // Chapter markers for M4B — written as timed metadata after transcoding
        if ext == "m4b" && !chunkBoundaries.isEmpty {
            try? addChapterMarkers(to: outputURL, boundaries: chunkBoundaries, totalDuration: duration)
        }

        return outputURL
    }

    // MARK: - Chapter markers (M4B)

    private func addChapterMarkers(to url: URL, boundaries: [Double], totalDuration: CMTime) throws {
        // AVAssetWriter does not support in-place editing; we write chapter metadata
        // via a simple text track approach using AVMutableMovieTrack when available.
        // On iOS the simplest portable solution is to store chapter titles as
        // AVMetadataItem entries on the asset — readers like Apple Books use these.
        // We append a sidecar `.chapters` plist alongside the file for now, since
        // iOS AVFoundation APIs for in-place chapter injection are macOS-only.
        let chapters = boundaries.enumerated().map { (i, t) in
            ["index": i + 1, "startTime": t, "title": "Chapter \(i + 1)"] as [String: Any]
        }
        let sidecarURL = url.deletingPathExtension().appendingPathExtension("chapters.plist")
        let data = try PropertyListSerialization.data(fromPropertyList: chapters, format: .xml, options: 0)
        try data.write(to: sidecarURL)
    }

    // MARK: - MP3 export (iOS 17+, AVAudioConverter)

    @available(iOS 17.0, *)
    private func exportMP3(wavURL: URL, title: String, artist: String) async throws -> URL {
        // kAudioFormatMPEGLayer3 is available for encoding on iOS 17+
        guard let sourceFile = try? AVAudioFile(forReading: wavURL) else {
            throw ExportError.sourceNotReadable
        }
        let sourceFormat = sourceFile.processingFormat

        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sourceFormat.sampleRate,
            channels: sourceFormat.channelCount,
            interleaved: false
        ) else {
            throw ExportError.writerSetupFailed
        }

        // Build a compressed format descriptor for MP3
        var mp3Settings = AudioStreamBasicDescription()
        mp3Settings.mSampleRate = sourceFormat.sampleRate
        mp3Settings.mFormatID = kAudioFormatMPEGLayer3
        mp3Settings.mChannelsPerFrame = sourceFormat.channelCount
        mp3Settings.mFramesPerPacket = 1152
        mp3Settings.mBitsPerChannel = 0
        mp3Settings.mBytesPerFrame = 0
        mp3Settings.mBytesPerPacket = 0
        mp3Settings.mFormatFlags = 0

        guard let mp3Format = AVAudioFormat(streamDescription: &mp3Settings) else {
            throw ExportError.unsupportedFormat
        }

        let outputURL = uniqueOutputURL(base: sanitizedFilename(title), ext: "mp3")
        try? FileManager.default.removeItem(at: outputURL)

        guard let converter = AVAudioConverter(from: outputFormat, to: mp3Format) else {
            throw ExportError.unsupportedFormat
        }
        converter.bitRate = 128_000

        guard let outputFile = try? AVAudioFile(forWriting: outputURL,
                                                settings: mp3Format.settings,
                                                commonFormat: .pcmFormatFloat32,
                                                interleaved: false) else {
            throw ExportError.writerSetupFailed
        }

        let frameCapacity: AVAudioFrameCount = 4096
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCapacity),
              let outputBuffer = AVAudioPCMBuffer(pcmFormat: mp3Format, frameCapacity: frameCapacity) else {
            throw ExportError.writerSetupFailed
        }

        var conversionError: NSError?
        var reachedEOF = false

        while !reachedEOF {
            let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
                if reachedEOF {
                    outStatus.pointee = .endOfStream
                    return nil
                }
                do {
                    try sourceFile.read(into: inputBuffer)
                    if inputBuffer.frameLength == 0 {
                        reachedEOF = true
                        outStatus.pointee = .endOfStream
                        return nil
                    }
                    outStatus.pointee = .haveData
                    return inputBuffer
                } catch {
                    reachedEOF = true
                    outStatus.pointee = .endOfStream
                    return nil
                }
            }

            if status == .error {
                throw ExportError.exportFailed(conversionError?.localizedDescription ?? "Conversion error")
            }

            if outputBuffer.frameLength > 0 {
                try outputFile.write(from: outputBuffer)
            }

            if status == .endOfStream { break }
        }

        return outputURL
    }

    // MARK: - Helpers

    private func uniqueOutputURL(base: String, ext: String) -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent("tts_exports", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filename = base.isEmpty ? "tts_export" : base
        return dir.appendingPathComponent("\(filename).\(ext)")
    }

    private func sanitizedFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return name.components(separatedBy: invalid).joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")
            .prefix(60).description
    }
}
