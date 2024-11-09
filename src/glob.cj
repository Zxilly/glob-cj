package glob_cj

import std.regex.Regex
import std.collection.ArrayList
import std.fs.{Path}
import std.deriving.Derive

// cjlint-ignore -start !G.OPR.01 !G.NAM.04 !G.ITF.04 macro
@Derive[Equatable]
enum CharSpecifier {
    SingleChar(Rune)
    | CharRange(Rune, Rune)
}

@Derive[Equatable]
enum PatternToken {
    Char(Rune)
    | AnyChar
    | AnySequence
    | AnyRecursiveSequence
    | AnyWithin(Array<CharSpecifier>)
    | AnyExcept(Array<CharSpecifier>)
}
// cjlint-ignore -end macro

enum MatchResult {
    Match
    | SubPatternDoesntMatch
    | EntirePatternDoesntMatch
}

const ERROR_WILDCARDS = "wildcards are either regular `*` or recursive `**`";
const ERROR_RECURSIVE_WILDCARDS = "recursive wildcards must form a single path component";
const ERROR_INVALID_RANGE = "invalid range pattern";

class PatternException <: Exception {
    let pos: Int

    public init(pos: Int, message: String) {
        super(message)
        this.pos = pos
    }

    public override func getClassName(): String {
        "PatternException"
    }
}

func isSeparator(c: Rune): Bool {
    return Path.Separator == c.toString()
}

func parseCharSpecifiers(s: Array<Rune>): Array<CharSpecifier> {
    let ret = ArrayList<CharSpecifier>()
    var i = 0
    while (i < s.size) {
        if (i + 3 <= s.size && s[i + 1] == r'-') {
            ret.append(CharSpecifier.CharRange(s[i], s[i + 2]))
            i += 3
        } else {
            ret.append(CharSpecifier.SingleChar(s[i]))
            i += 1
        }
    }
    return ret.toArray()
}

struct Pattern {
    let original: String
    let tokens: ArrayList<PatternToken>
    let isRecursive: Bool

    // cjlint-ignore -start !G.FUN.01 init
    init(pattern: String) {
        let chars = pattern.toRuneArray()
        let tokens = ArrayList<PatternToken>()
        var is_recursive = false
        var i = 0

        while (i < chars.size) {
            match (chars[i]) {
                case r'?' =>
                    tokens.append(PatternToken.AnyChar)
                    i++
                case r'*' =>
                    let old = i

                    while (i < chars.size && chars[i] == r'*') {
                        i++
                    }

                    let count = i - old

                    if (count > 2) {
                        throw PatternException(old + 2, ERROR_WILDCARDS)
                    } else if (count == 2) {
                        let is_valid = if (i == 2 || isSeparator(chars[i - count - 1])) {
                            if (i < chars.size && isSeparator(chars[i])) {
                                i++
                                true
                            } else if (i == chars.size) {
                                true
                            } else {
                                throw PatternException(i, ERROR_RECURSIVE_WILDCARDS)
                            }
                        } else {
                            throw PatternException(old - 1, ERROR_RECURSIVE_WILDCARDS)
                        }

                        if (is_valid) {
                            let tokens_len = tokens.size

                            if (!(tokens_len > 1 && tokens.get(tokens_len - 1) == PatternToken.AnyRecursiveSequence)) {
                                is_recursive = true
                                tokens.append(PatternToken.AnyRecursiveSequence)
                            }
                        }
                    } else {
                        tokens.append(PatternToken.AnySequence)
                    }
                case r'[' =>
                    if (i + 4 <= chars.size && chars[i + 1] == r'!') {
                        match (chars[i + 3..].indexOf(r']')) {
                            case None => {=>}
                            case Some(j) =>
                                let subChars = chars[i + 2..i + 3 + j]
                                let cs = parseCharSpecifiers(subChars)
                                tokens.append(PatternToken.AnyExcept(cs))
                                i += 4 + j
                                continue
                        }
                    } else if (i + 3 <= chars.size && chars[i + 1] != r'!') {
                        match (chars[i + 2..].indexOf(r']')) {
                            case None => {=>}
                            case Some(j) =>
                                let subChars = chars[i + 1..i + 2 + j]
                                let cs = parseCharSpecifiers(subChars)
                                tokens.append(PatternToken.AnyWithin(cs))
                                i += 3 + j
                                continue
                        }
                    }

                    throw PatternException(i, ERROR_INVALID_RANGE)
                case c =>
                    tokens.append(PatternToken.Char(c))
                    i++
            }
        }

        this.original = pattern
        this.tokens = tokens
        this.isRecursive = is_recursive
    }
    // cjlint-ignore -end init
}
