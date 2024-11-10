package glob

import std.unittest.*
import std.unittest.testmacro.*

@Test
class PatternTests {
    @TestCase
    func testPatternFromStr() {
        let p1 = Pattern("a*b")
        @Assert(p1.matches("a_b"), true)

        let e = @AssertThrows[PatternException]({
            Pattern("a/**b")
        })
        @Assert(e.pos, 4)
    }

    func assertInitException(pattern: String, pos: Int) {
        let e = @AssertThrows[PatternException]({
            Pattern(pattern)
        })
        @Assert(e.pos, pos)
    }

    @TestCase
    func testWildcardErrors() {
        assertInitException("a/**b", 4)
        assertInitException("a/bc**", 3)
        assertInitException("a/*****", 4)
        assertInitException("a/b**c**d", 2)
        assertInitException("a**b", 0)
    }

    @TestCase
    func testUnclosedBracketErrors() {
        assertInitException("abc[def", 3)
        assertInitException("abc[!def", 3)
        assertInitException("abc[", 3)
        assertInitException("abc[!", 3)
        assertInitException("abc[d", 3)
        assertInitException("abc[!d", 3)
        assertInitException("abc[]", 3)
        assertInitException("abc[!]", 3)
    }

    @TestCase
    func testWildcards() {
        let p1 = Pattern("a*b")
        @Assert(p1.matches("a_b"), true)

        let p2 = Pattern("a*b*c")
        @Assert(p2.matches("abc"), true)
        @Assert(p2.matches("abcd"), false)
        @Assert(p2.matches("a_b_c"), true)
        @Assert(p2.matches("a___b___c"), true)

        let p3 = Pattern("abc*abc*abc")
        @Assert(p3.matches("abcabcabcabcabcabcabc"), true)
        @Assert(p3.matches("abcabcabcabcabcabcabca"), false)

        let p4 = Pattern("a*a*a*a*a*a*a*a*a")
        @Assert(p4.matches("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"), true)

        let p5 = Pattern("a*b[xyz]c*d")
        @Assert(p5.matches("abxcdbxcddd"), true)
    }

    @TestCase
    func testRecursiveWildcards() {
        let pat = Pattern("some/**/needle.txt")
        @Assert(pat.matches("some/needle.txt"), true)
        @Assert(pat.matches("some/one/needle.txt"), true)
        @Assert(pat.matches("some/one/two/needle.txt"), true)
        @Assert(pat.matches("some/other/needle.txt"), true)
        @Assert(pat.matches("some/other/notthis.txt"), false)

        let pat2 = Pattern("**")
        @Assert(pat2.matches("abcde"), true)
        @Assert(pat2.matches(""), true)
        @Assert(pat2.matches(".asdf"), true)
        @Assert(pat2.matches("/x/.asdf"), true)

        let pat3 = Pattern("some/**/**/needle.txt")
        @Assert(pat3.matches("some/needle.txt"), true)
        @Assert(pat3.matches("some/one/needle.txt"), true)
        @Assert(pat3.matches("some/one/two/needle.txt"), true)
        @Assert(pat3.matches("some/other/needle.txt"), true)
        @Assert(pat3.matches("some/other/notthis.txt"), false)

        let pat4 = Pattern("**/test")
        @Assert(pat4.matches("one/two/test"), true)
        @Assert(pat4.matches("one/test"), true)
        @Assert(pat4.matches("test"), true)

        let pat5 = Pattern("/**/test")
        @Assert(pat5.matches("/one/two/test"), true)
        @Assert(pat5.matches("/one/test"), true)
        @Assert(pat5.matches("/test"), true)
        @Assert(pat5.matches("/one/notthis"), false)
        @Assert(pat5.matches("/notthis"), false)

        let pat6 = Pattern("**/.*")
        @Assert(pat6.matches(".abc"), true)
        @Assert(pat6.matches("abc/.abc"), true)
        @Assert(pat6.matches("ab.c"), false)
        @Assert(pat6.matches("abc/ab.c"), false)
    }
}
