import Foundation

struct MelangeEncodedToken {
    let id: Int
    let rawToken: String?
    let characterRange: Range<Int>?
}

final class MelangeTextTokenizer {
    private var vocab: [String: Int] = [:]
    private var idToToken: [Int: String] = [:]

    var bosId = 0
    var eosId = 2
    var unkId = 3
    var padId = 1

    init(
        tokenizerResourceName: String = "ResourcesTextAnonymizer_tokenizer",
        bundle: Bundle = .main
    ) throws {
        try loadVocab(resourceName: tokenizerResourceName, bundle: bundle)
    }

    func encodeDetailed(_ text: String) -> [MelangeEncodedToken] {
        var tokens: [MelangeEncodedToken] = [
            MelangeEncodedToken(id: bosId, rawToken: nil, characterRange: nil)
        ]

        var cleanCharacters: [Character] = ["\u{0120}"]
        var characterMappings: [Int?] = [nil]
        let textCharacters = Array(text)

        for (offset, character) in textCharacters.enumerated() {
            cleanCharacters.append(character == " " ? "\u{0120}" : character)
            characterMappings.append(offset)
        }

        var index = 0
        while index < cleanCharacters.count {
            var matchedToken: MelangeEncodedToken?
            let maxSearchLength = min(cleanCharacters.count - index, 20)

            for length in stride(from: maxSearchLength, through: 1, by: -1) {
                let candidate = String(cleanCharacters[index..<(index + length)])
                guard let tokenId = vocab[candidate] else {
                    continue
                }

                let mappedOffsets = characterMappings[index..<(index + length)].compactMap { $0 }
                let range: Range<Int>?
                if let first = mappedOffsets.first, let last = mappedOffsets.last {
                    range = first..<(last + 1)
                } else {
                    range = nil
                }

                matchedToken = MelangeEncodedToken(
                    id: tokenId,
                    rawToken: candidate,
                    characterRange: range
                )
                index += length
                break
            }

            if let matchedToken {
                tokens.append(matchedToken)
            } else {
                tokens.append(
                    MelangeEncodedToken(
                        id: unkId,
                        rawToken: nil,
                        characterRange: nil
                    )
                )
                index += 1
            }
        }

        tokens.append(MelangeEncodedToken(id: eosId, rawToken: nil, characterRange: nil))
        return tokens
    }

    private func loadVocab(resourceName: String, bundle: Bundle) throws {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw NSError(
                domain: "MelangeTextTokenizer",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "Missing tokenizer resource \(resourceName).json"]
            )
        }

        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(
                domain: "MelangeTextTokenizer",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "Invalid tokenizer JSON format."]
            )
        }

        let vocabDict: [String: Any]?
        if let model = json["model"] as? [String: Any], let nestedVocab = model["vocab"] as? [String: Any] {
            vocabDict = nestedVocab
        } else {
            vocabDict = json["vocab"] as? [String: Any]
        }

        guard let vocabDict else {
            throw NSError(
                domain: "MelangeTextTokenizer",
                code: 1003,
                userInfo: [NSLocalizedDescriptionKey: "Tokenizer JSON did not contain a vocab dictionary."]
            )
        }

        for (token, idValue) in vocabDict {
            if let id = idValue as? Int {
                vocab[token] = id
                idToToken[id] = token
            } else if let number = idValue as? NSNumber {
                vocab[token] = number.intValue
                idToToken[number.intValue] = token
            }
        }

        bosId = vocab["<s>"] ?? vocab["[CLS]"] ?? bosId
        eosId = vocab["</s>"] ?? vocab["[SEP]"] ?? eosId
        unkId = vocab["<unk>"] ?? vocab["[UNK]"] ?? unkId
        padId = vocab["<pad>"] ?? vocab["[PAD]"] ?? padId
    }
}
