package glob

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

public struct MatchOptions {
    /**
     * 是否以大小写敏感的方式匹配模式。
     * 目前只考虑 ASCII 字符之间的大/小写关系，
     * 但将来可能会扩展到适用于 Unicode。
     */
    var caseSensitive: Bool = false

    /**
     * 是否要求路径分隔符字符（例如 Posix 上的 `/`）必须由字面量 `/` 匹配，
     * 而不是由 `*` 或 `?` 或 `[...]` 匹配。
     */
    var requireLiteralSeparator: Bool = false

    /**
     * 是否要求路径组件的开头是 `.` 字符，必须由字面量 `.` 匹配，
     * 而不是由 `*` 或 `?` 或 `**` 或 `[...]` 匹配。
     * 这对于 Unix 系统上被传统认为是隐藏的文件很有用，
     * 可能希望在列出文件时跳过它们。
     */
    var requireLiteralLeadingDot: Bool = false
}

@Derive[Equatable]
public enum MatchResult {
    Match
    | SubPatternDoesntMatch
    | EntirePatternDoesntMatch
}

// cjlint-ignore -end macro

const ERROR_WILDCARDS = "wildcards are either regular `*` or recursive `**`";
const ERROR_RECURSIVE_WILDCARDS = "recursive wildcards must form a single path component";
const ERROR_INVALID_RANGE = "invalid range pattern";

public class PatternException <: Exception {
    public let pos: Int

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

public class CharsIterator <: Iterator<Rune> {
    let chars: Array<Rune>
    var i: Int

    init(c: Array<Rune>, i!: Int = 0) {
        this.chars = c
        this.i = i
    }

    public func clone(): CharsIterator {
        return CharsIterator(this.chars, i: this.i)
    }

    public func next(): Option<Rune> {
        if (this.i < this.chars.size) {
            let c = this.chars[this.i]
            this.i++
            return Some(c)
        } else {
            return None
        }
    }
}

func charsEq(a: Rune, b: Rune, caseSensitive: Bool): Bool {
    if (!caseSensitive && a.isAscii() && b.isAscii()) {
        a.toAsciiLowerCase() == b.toAsciiLowerCase()
    } else {
        a == b
    }
}

// cjlint-ignore -start !G.FUN.01 fun
func inCharSpecifiers(cs: Array<CharSpecifier>, c: Rune, options: MatchOptions): Bool {
    for (spec in cs) {
        match (spec) {
            case CharSpecifier.SingleChar(cs) =>
                if (charsEq(c, cs, options.caseSensitive)) {
                    return true
                } else {
                    continue
                }

            case CharSpecifier.CharRange(start, end) =>
                if (!options.caseSensitive && c.isAscii() && start.isAscii() && end.isAscii()) {
                    let sl = start.toAsciiLowerCase()
                    let el = end.toAsciiLowerCase()

                    let su = start.toAsciiUpperCase()
                    let eu = end.toAsciiUpperCase()

                    if (start != su && end != eu) {
                        let cl = c.toAsciiLowerCase()
                        if (c >= start && c <= end) {
                            return true;
                        }
                    }
                }

                if (c >= start && c <= end) {
                    return true
                }
        }
    }

    return false
}

public struct Pattern {
    let original: String
    let tokens: ArrayList<PatternToken>
    let isRecursive: Bool

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

    public func matches(str: String): Bool {
        this.matchesWith(str, MatchOptions())
    }

    public func matchesWith(
        str: String,
        options: MatchOptions
    ) : Bool {
        this.matchesFrom(true, CharsIterator(str.toRuneArray()), 0, options) == MatchResult.Match
    }

    public func matchesFrom(
        followsSeparator: Bool,
        file: CharsIterator,
        i: Int,
        options: MatchOptions
    ): MatchResult {
        var ti = i
        var fs = followsSeparator
        for (token in this.tokens) {
            ti++
            match (token) {
                case AnySequence | AnyRecursiveSequence =>
                    match (this.matchesFrom(fs, file, i + ti + 1, options)) {
                        case MatchResult.SubPatternDoesntMatch => {=>}
                        case m => return m
                    }

                    while (let Some(c) <- file.next()) {
                        if (fs && options.requireLiteralLeadingDot && c == r'.') {
                            return MatchResult.SubPatternDoesntMatch
                        }
                        fs = isSeparator(c)
                        match (token) {
                            case PatternToken.AnyRecursiveSequence =>
                                if (!fs) {
                                    continue
                                }
                            case PatternToken.AnySequence =>
                                if (options.requireLiteralSeparator && fs) {
                                    return MatchResult.SubPatternDoesntMatch
                                }
                            case _ => {=>}
                        }

                        match (this.matchesFrom(fs, file.clone(), i + ti + 1, options)) {
                            case MatchResult.SubPatternDoesntMatch => {=>}
                            case m => return m
                        }
                    }
                case _ =>
                    let c = match (file.next()) {
                        case Some(c) => c
                        case None => return MatchResult.EntirePatternDoesntMatch
                    }

                    let is_sep = isSeparator(c)

                    if (!match (token) {
                        case PatternToken.AnyChar | PatternToken.AnyWithin(_) | AnyExcept(_) =>
                            if ((options.requireLiteralSeparator && is_sep) || (fs && options.requireLiteralLeadingDot &&
                                c == r'.')) {
                                false
                            } else {
                                true
                            }
                        case _ => true
                    }) {
                        return MatchResult.SubPatternDoesntMatch
                    }

                    if (!match(token) {
                        case PatternToken.AnyChar => true
                        case PatternToken.AnyWithin(cs) => inCharSpecifiers(cs, c, options)
                        case PatternToken.AnyExcept(cs) => !inCharSpecifiers(cs, c, options)
                        case PatternToken.Char(tc) => charsEq(c, tc, options.caseSensitive)
                        case _ => throw Exception("unreachable")

                    }) {
                        return MatchResult.SubPatternDoesntMatch
                    }
                    fs = is_sep
            }
        }

        if (file.next().isNone()) {
            return MatchResult.Match
        } else {
            return MatchResult.SubPatternDoesntMatch
        }
    }
}

// cjlint-ignore -end fun