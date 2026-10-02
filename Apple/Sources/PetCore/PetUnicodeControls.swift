// SPDX-License-Identifier: Apache-2.0
/// Restrict actual C0/C1 controls while preserving format scalars such as emoji joiners.
enum PetUnicodeControls {
    static func contains(_ text:String,allowTextWhitespace:Bool=false) -> Bool {
        text.unicodeScalars.contains { scalar in
            let value=scalar.value
            return (value<32 || (127...159).contains(value)) && !(allowTextWhitespace && [9,10,13].contains(value))
        }
    }
}
