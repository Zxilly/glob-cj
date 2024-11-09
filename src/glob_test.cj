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
}
