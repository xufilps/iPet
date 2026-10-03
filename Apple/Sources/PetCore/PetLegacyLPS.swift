// iPet native compatibility decoder. Source contracts: LinePutScript 1.11.9.
// SPDX-License-Identifier: Apache-2.0
import Foundation

/// Structure only: callers must validate mapped fields and preserve source bytes before import.
public struct PetLegacyLPSDocument: Sendable {
    public enum DecodeError: Error, Equatable {
        case invalidUTF8, byteLimit, lineLimit, fieldLimit, unsupportedStoredNumber
    }
    public struct Field: Sendable {
        public let name: String
        public let rawInfo: String
        public var info: String { PetLegacyLPSDocument.decodeText(rawInfo) }
    }
    public struct Line: Sendable {
        public let name: String
        public let rawInfo: String
        public let rawText: String
        public let comment: String
        public let fields: [Field]
        public var info: String { PetLegacyLPSDocument.decodeText(rawInfo) }
        public var text: String { PetLegacyLPSDocument.decodeText(rawText) }
        /// Original Line.Find is case-sensitive and returns the first duplicate.
        public func firstField(named name: String) -> Field? { fields.first { $0.name.utf8.elementsEqual(name.utf8) } }
    }
    public let lines: [Line]

    public static func parse(_ data: Data) throws -> Self {
        guard data.count <= 8*1024*1024 else { throw DecodeError.byteLimit }
        guard var input=String(data:data,encoding:.utf8) else { throw DecodeError.invalidUTF8 }
        if input.first == "\u{feff}" { input.removeFirst() }
        // Normalize continuations before splitting, as LpsDocument.Load does.
        input=input.replacingOccurrences(of:"\r",with:"")
            .replacingOccurrences(of:":\n|",with:"/n")
            .replacingOccurrences(of:":\n:",with:"")
        let rows=input.split(separator:"\n",maxSplits:10000,omittingEmptySubsequences:true)
        guard rows.count <= 10000 else { throw DecodeError.lineLimit }
        var lines=[Line]();lines.reserveCapacity(rows.count)
        for row in rows {
            let source=String(row)
            let body: String, comment: String
            if let marker=source.range(of:"///",options:.literal) {
                body=String(source[..<marker.lowerBound]);comment=String(source[marker.upperBound...])
            } else { body=source;comment="" }
            let parts=try splitFields(body)
            let header=field(parts[0])
            let fields=parts.count > 2 ? parts.dropFirst().dropLast().map(field) : []
            lines.append(Line(name:header.name,rawInfo:header.rawInfo,rawText:parts[parts.count-1],comment:comment,fields:fields))
        }
        return Self(lines:lines)
    }

    /// Canonical strings written by FInt64.ToStoreString, not human decimal values.
    /// Noncanonical culture-dependent fallback and special sentinels require explicit import diagnostics.
    public static func storedFloat(_ raw: String) throws -> Double {
        guard let integer=Int64(raw),String(integer)==raw,
              integer != Int64.max,integer != Int64.max-1,integer != Int64.min+1 else {
            throw DecodeError.unsupportedStoredNumber
        }
        return Double(integer)/1_000_000_000.0
    }

    private static func field(_ raw: String) -> Field {
        if let marker=raw.range(of:"#",options:.literal) {
            return Field(name:String(raw[..<marker.lowerBound]),rawInfo:String(raw[marker.upperBound...]))
        }
        return Field(name:raw,rawInfo:"")
    }
    private static func splitFields(_ raw: String) throws -> [String] {
        var parts=[String](),start=raw.startIndex
        while let marker=raw.range(of:":|",options:.literal,range:start..<raw.endIndex) {
            // At most a header, 2000 fields, and a trailing text segment.
            guard parts.count < 2001 else { throw DecodeError.fieldLimit }
            parts.append(String(raw[start..<marker.lowerBound]));start=marker.upperBound
        }
        parts.append(String(raw[start...]))
        return parts
    }
    private static func decodeText(_ raw: String) -> String {
        var result=raw
        // Order is intentional: /!n denotes literal /n, not a newline.
        for (from,to) in [("/stop",":|"),("/equ","="),("/tab","\t"),("/n","\n"),("/r","\r"),("/id","#"),("/com",","),("/!","/"),("/|","|")] {
            result=result.replacingOccurrences(of:from,with:to,options:.literal)
        }
        return result
    }
}

extension PetLegacyLPSDocument {
    /// Matches LpsDocument.ToString (the StringBuilder overload), not the raw input file.
    public var canonicalString: String {
        lines.map { line in
            var value=line.name+(line.rawInfo.isEmpty ? "":"#"+line.rawInfo)+":|"
            for field in line.fields { value+=field.name+(field.rawInfo.isEmpty ? "":"#"+field.rawInfo)+":|" }
            value+=line.rawText
            if !line.comment.isEmpty { value+="///"+line.comment }
            return value
        }.joined(separator:"\n").trimmingCharacters(in:CharacterSet(charactersIn:"\n"))
    }
}
