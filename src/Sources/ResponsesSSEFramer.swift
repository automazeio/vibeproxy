import Foundation

final class ResponsesSSEFramer {
    private var pending = Data()

    func write(_ chunk: Data) -> [Data] {
        guard !chunk.isEmpty else { return [] }

        if Self.needsLineBreak(pending: pending, chunk: chunk) {
            pending.append(0x0A)
        }
        pending.append(chunk)

        var output: [Data] = []
        while let frameLength = Self.frameLength(in: pending) {
            let frame = Data(pending.prefix(frameLength))
            if Self.needsMoreData(frame) {
                guard Self.collapseIncompleteEventFrame(in: &pending, frameLength: frameLength) else {
                    break
                }
                continue
            }

            output.append(Self.normalizedChunk(frame))
            pending.removeFirst(frameLength)
        }

        if Self.trimmed(pending).isEmpty {
            pending.removeAll(keepingCapacity: true)
            return output
        }

        if Self.canEmitWithoutDelimiter(pending) {
            output.append(Self.normalizedChunk(pending))
            pending.removeAll(keepingCapacity: true)
        }

        return output
    }

    func flush() -> [Data] {
        guard !pending.isEmpty else { return [] }

        defer { pending.removeAll(keepingCapacity: true) }

        let trimmedPending = Self.trimmed(pending)
        guard !trimmedPending.isEmpty, Self.canEmitWithoutDelimiter(pending) else {
            return []
        }

        return [Self.normalizedChunk(pending)]
    }

    private static func normalizedChunk(_ chunk: Data) -> Data {
        if chunk.hasDataSuffix(Data("\n\n".utf8)) || chunk.hasDataSuffix(Data("\r\n\r\n".utf8)) {
            return chunk
        }

        var result = chunk
        if chunk.hasDataSuffix(Data("\r\n".utf8)) {
            result.append(contentsOf: "\r\n".utf8)
        } else if chunk.hasDataSuffix(Data("\n".utf8)) {
            result.append(contentsOf: "\n".utf8)
        } else {
            result.append(contentsOf: "\n\n".utf8)
        }
        return result
    }

    private static func frameLength(in chunk: Data) -> Int? {
        guard !chunk.isEmpty else { return nil }

        let lfRange = chunk.range(of: Data("\n\n".utf8))
        let crlfRange = chunk.range(of: Data("\r\n\r\n".utf8))

        switch (lfRange, crlfRange) {
        case (nil, nil):
            return nil
        case (nil, let crlf?):
            return chunk.distance(from: chunk.startIndex, to: crlf.upperBound)
        case (let lf?, nil):
            return chunk.distance(from: chunk.startIndex, to: lf.upperBound)
        case (let lf?, let crlf?):
            let selectedRange = lf.lowerBound < crlf.lowerBound ? lf : crlf
            return chunk.distance(from: chunk.startIndex, to: selectedRange.upperBound)
        }
    }

    private static func needsMoreData(_ chunk: Data) -> Bool {
        let trimmedChunk = trimmed(chunk)
        guard !trimmedChunk.isEmpty else { return false }
        return hasField(trimmedChunk, prefix: "event:") && !hasField(trimmedChunk, prefix: "data:")
    }

    private static func collapseIncompleteEventFrame(in data: inout Data, frameLength: Int) -> Bool {
        let crlfDelimiter = Data("\r\n\r\n".utf8)
        if Data(data.prefix(frameLength)).hasDataSuffix(crlfDelimiter) {
            let collapseStart = data.index(data.startIndex, offsetBy: frameLength - 2)
            let collapseEnd = data.index(data.startIndex, offsetBy: frameLength)
            data.removeSubrange(collapseStart..<collapseEnd)
            return true
        }

        let lfDelimiter = Data("\n\n".utf8)
        if Data(data.prefix(frameLength)).hasDataSuffix(lfDelimiter) {
            let collapseStart = data.index(data.startIndex, offsetBy: frameLength - 1)
            let collapseEnd = data.index(data.startIndex, offsetBy: frameLength)
            data.removeSubrange(collapseStart..<collapseEnd)
            return true
        }

        return false
    }

    private static func hasField(_ chunk: Data, prefix: String) -> Bool {
        for line in lines(of: chunk) {
            let trimmedLine = trimmed(line)
            if trimmedLine.starts(with: Data(prefix.utf8)) {
                return true
            }
        }
        return false
    }

    private static func canEmitWithoutDelimiter(_ chunk: Data) -> Bool {
        let trimmedChunk = trimmed(chunk)
        guard !trimmedChunk.isEmpty else { return false }
        guard !needsMoreData(trimmedChunk), hasField(trimmedChunk, prefix: "data:") else {
            return false
        }
        return dataLinesAreValid(trimmedChunk)
    }

    private static func dataLinesAreValid(_ chunk: Data) -> Bool {
        for line in lines(of: chunk) {
            let trimmedLine = trimmed(line)
            guard !trimmedLine.isEmpty else { continue }
            let prefix = Data("data:".utf8)
            guard trimmedLine.starts(with: prefix) else { continue }

            let payload = trimmed(Data(trimmedLine.dropFirst(prefix.count)))
            if payload.isEmpty || payload == Data("[DONE]".utf8) {
                continue
            }
            if (try? JSONSerialization.jsonObject(with: payload)) == nil {
                return false
            }
        }
        return true
    }

    private static func needsLineBreak(pending: Data, chunk: Data) -> Bool {
        guard !pending.isEmpty, !chunk.isEmpty else { return false }
        guard !pending.hasDataSuffix(Data("\n".utf8)), !pending.hasDataSuffix(Data("\r".utf8)) else {
            return false
        }
        guard chunk.first != 0x0A, chunk.first != 0x0D else {
            return false
        }

        let trimmedChunk = chunk.drop(while: { $0 == 0x20 || $0 == 0x09 })
        guard !trimmedChunk.isEmpty else { return false }

        let prefixes = ["data:", "event:", "id:", "retry:", ":"]
        return prefixes.contains { trimmedChunk.starts(with: Data($0.utf8)) }
    }

    private static func lines(of chunk: Data) -> [Data] {
        guard !chunk.isEmpty else { return [] }

        var lines: [Data] = []
        var startIndex = chunk.startIndex

        for index in chunk.indices where chunk[index] == 0x0A {
            lines.append(Data(chunk[startIndex..<index]))
            startIndex = chunk.index(after: index)
        }

        if startIndex < chunk.endIndex {
            lines.append(Data(chunk[startIndex..<chunk.endIndex]))
        }

        return lines
    }

    private static func trimmed(_ data: Data) -> Data {
        var lower = data.startIndex
        var upper = data.endIndex

        while lower < upper, isWhitespace(data[lower]) {
            lower = data.index(after: lower)
        }

        while lower < upper {
            let previous = data.index(before: upper)
            guard isWhitespace(data[previous]) == true else { break }
            upper = previous
        }

        return Data(data[lower..<upper])
    }

    private static func isWhitespace(_ byte: UInt8) -> Bool {
        byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D
    }
}

final class HTTPChunkedDecoder {
    private var pending = Data()
    private var expectedChunkLength: Int?
    private var finished = false

    func decode(_ chunk: Data, isComplete: Bool) -> [Data] {
        guard !finished else { return [] }

        if !chunk.isEmpty {
            pending.append(chunk)
        }

        var output: [Data] = []

        while true {
            if let expectedChunkLength {
                if expectedChunkLength == 0 {
                    guard consumeTrailersIfAvailable() else { break }
                    finished = true
                    break
                }

                let requiredLength = expectedChunkLength + 2
                guard pending.count >= requiredLength else { break }

                output.append(Data(pending.prefix(expectedChunkLength)))
                pending.removeFirst(expectedChunkLength)

                guard pending.hasDataPrefix(Data("\r\n".utf8)) else {
                    break
                }
                pending.removeFirst(2)
                self.expectedChunkLength = nil
                continue
            }

            guard let lineLength = Self.lineLength(in: pending) else { break }

            let sizeLine = Data(pending.prefix(lineLength - 2))
            pending.removeFirst(lineLength)

            guard let size = Self.parseChunkLength(from: sizeLine) else { break }

            expectedChunkLength = size
        }

        if isComplete {
            pending.removeAll(keepingCapacity: true)
            expectedChunkLength = nil
            finished = true
        }

        return output
    }

    private func consumeTrailersIfAvailable() -> Bool {
        if pending.hasDataPrefix(Data("\r\n".utf8)) {
            pending.removeFirst(2)
            return true
        }

        guard let trailerLength = Self.delimiterLength(in: pending, delimiter: Data("\r\n\r\n".utf8)) else {
            return false
        }

        pending.removeFirst(trailerLength)
        return true
    }

    private static func parseChunkLength(from data: Data) -> Int? {
        guard let line = String(data: data, encoding: .utf8) else { return nil }
        let sizeToken = line.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
        return Int(sizeToken.trimmingCharacters(in: .whitespacesAndNewlines), radix: 16)
    }

    private static func lineLength(in data: Data) -> Int? {
        delimiterLength(in: data, delimiter: Data("\r\n".utf8))
    }

    private static func delimiterLength(in data: Data, delimiter: Data) -> Int? {
        guard let range = data.range(of: delimiter) else { return nil }
        return data.distance(from: data.startIndex, to: range.upperBound)
    }
}

final class HTTPResponseRelay {
    private enum BodyMode {
        case passthrough
        case responsesSSE
        case chunkedResponsesSSE
    }

    private var headerBuffer = Data()
    private var headersParsed = false
    private var bodyMode: BodyMode = .passthrough
    private let chunkedDecoder = HTTPChunkedDecoder()
    private let responsesFramer = ResponsesSSEFramer()

    init(requestPath: String) {
        _ = requestPath
    }

    func process(_ data: Data, isComplete: Bool) -> [Data] {
        if headersParsed {
            return processBody(data, isComplete: isComplete)
        }

        if !data.isEmpty {
            headerBuffer.append(data)
        }

        guard let headerRange = headerBuffer.range(of: Data("\r\n\r\n".utf8)) else {
            if isComplete {
                let buffered = headerBuffer
                headerBuffer.removeAll(keepingCapacity: true)
                headersParsed = true
                return buffered.isEmpty ? [] : [buffered]
            }
            return []
        }

        let headerEnd = headerBuffer.distance(from: headerBuffer.startIndex, to: headerRange.upperBound)
        let (headerData, resolvedBodyMode) = Self.rewriteHeaders(Data(headerBuffer.prefix(headerEnd)))
        let bodyData = Data(headerBuffer.dropFirst(headerEnd))
        headerBuffer.removeAll(keepingCapacity: true)
        headersParsed = true
        bodyMode = resolvedBodyMode

        var output = [headerData]
        output.append(contentsOf: processBody(bodyData, isComplete: isComplete))
        return output
    }

    private func processBody(_ data: Data, isComplete: Bool) -> [Data] {
        switch bodyMode {
        case .passthrough:
            return data.isEmpty ? [] : [data]
        case .responsesSSE:
            var output: [Data] = []
            if !data.isEmpty {
                output.append(contentsOf: responsesFramer.write(data))
            }
            if isComplete {
                output.append(contentsOf: responsesFramer.flush())
            }
            return output
        case .chunkedResponsesSSE:
            var output: [Data] = []
            for decodedChunk in chunkedDecoder.decode(data, isComplete: isComplete) {
                output.append(contentsOf: responsesFramer.write(decodedChunk))
            }
            if isComplete {
                output.append(contentsOf: responsesFramer.flush())
            }
            return output
        }
    }

    private static func rewriteHeaders(_ headerData: Data) -> (Data, BodyMode) {
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            return (headerData, .passthrough)
        }

        let rawLines = headerString.components(separatedBy: "\r\n")
        guard let statusLine = rawLines.first else {
            return (headerData, .passthrough)
        }

        let hasEventStream = rawLines.contains {
            $0.lowercased().hasPrefix("content-type:") && $0.lowercased().contains("text/event-stream")
        }
        let hasChunkedTransferEncoding = rawLines.contains {
            $0.lowercased().hasPrefix("transfer-encoding:") && $0.lowercased().contains("chunked")
        }

        guard hasEventStream else {
            return (headerData, .passthrough)
        }

        var rewrittenLines = [statusLine]
        var insertedConnectionClose = false

        for line in rawLines.dropFirst() {
            if line.isEmpty { continue }

            let lowercasedLine = line.lowercased()
            if lowercasedLine.hasPrefix("transfer-encoding:") || lowercasedLine.hasPrefix("content-length:") {
                continue
            }
            if lowercasedLine.hasPrefix("connection:") {
                rewrittenLines.append("Connection: close")
                insertedConnectionClose = true
                continue
            }

            rewrittenLines.append(line)
        }

        if !insertedConnectionClose {
            rewrittenLines.append("Connection: close")
        }

        let rewrittenHeaderData = Data((rewrittenLines + ["", ""]).joined(separator: "\r\n").utf8)
        let bodyMode: BodyMode = hasChunkedTransferEncoding ? .chunkedResponsesSSE : .responsesSSE
        return (rewrittenHeaderData, bodyMode)
    }
}

private extension Data {
    func hasDataSuffix(_ expectedSuffix: Data) -> Bool {
        guard count >= expectedSuffix.count else { return false }
        return suffix(expectedSuffix.count).elementsEqual(expectedSuffix)
    }

    func hasDataPrefix(_ expectedPrefix: Data) -> Bool {
        guard count >= expectedPrefix.count else { return false }
        return prefix(expectedPrefix.count).elementsEqual(expectedPrefix)
    }
}
