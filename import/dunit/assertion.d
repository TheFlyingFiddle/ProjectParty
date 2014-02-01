//          Copyright Juan Manuel Cabo 2012.
//          Copyright Mario Kröplin 2013.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dunit.assertion;

import dunit.diff;

import core.thread;
import core.time;
import std.algorithm;
import std.array;
import std.conv;
import std.string;
import std.traits;

version (unittest) import std.exception;

/**
 * Thrown on an assertion failure.
 */
class AssertException : Exception
{
    this(string msg = null,
            string file = __FILE__,
            size_t line = __LINE__)
    {
        super(msg.empty ? "Assertion failure" : msg, file, line);
    }
}

/**
 * Asserts that a condition is true.
 * Throws: AssertException otherwise
 */
void assertTrue(bool condition, lazy string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    if (condition)
        return;

    fail(msg, file, line);
}

///
unittest
{
    assertTrue(true);
    assertEquals("Assertion failure",
            collectExceptionMsg!AssertException(assertTrue(false)));
}

/**
 * Asserts that a condition is false.
 * Throws: AssertException otherwise
 */
void assertFalse(bool condition, lazy string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    if (!condition)
        return;

    fail(msg, file, line);
}

///
unittest
{
    assertFalse(false);
    assertEquals("Assertion failure",
            collectExceptionMsg!AssertException(assertFalse(true)));
}

/**
 * Asserts that the string values are equal.
 * Throws: AssertException otherwise
 */
void assertEquals(T, U)(T expected, U actual, lazy string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
    if (isSomeString!T)
{
    if (expected == actual)
        return;

    string header = (msg.empty) ? null : msg ~ "; ";

    fail(header ~ description(expected.to!string, actual.to!string),
            file, line);
}

///
unittest
{
    assertEquals("foo", "foo");
    assertEquals("expected: <ba<r>> but was: <ba<z>>",
            collectExceptionMsg!AssertException(assertEquals("bar", "baz")));
}

/**
 * Asserts that the string values are equal.
 * Throws: AssertException otherwise
 */
void assertEquals(T, U)(T expected, U actual, lazy string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
    if (!isSomeString!T)
{
    if (expected == actual)
        return;

    string header = (msg.empty) ? null : msg ~ "; ";

    fail(header ~ "expected: <" ~ expected.to!string ~ "> but was: <"~ actual.to!string ~ ">",
            file, line);
}

///
unittest
{
    assertEquals(42, 42);
    assertEquals("expected: <42> but was: <24>",
            collectExceptionMsg!AssertException(assertEquals(42, 24)));

    assertEquals(42.0, 42.0);

    Object foo = new Object();
    Object bar = null;

    assertEquals(foo, foo);
    assertEquals(bar, bar);
    assertEquals("expected: <object.Object> but was: <null>",
            collectExceptionMsg!AssertException(assertEquals(foo, bar)));
}

/**
 * Asserts that the arrays are equal.
 * Throws: AssertException otherwise
 */
void assertArrayEquals(T, U)(T[] expected, U[] actual, lazy string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    string header = (msg.empty) ? null : msg ~ "; ";

    foreach (index; 0 .. min(expected.length, actual.length))
    {
        assertEquals(expected[index], actual[index],
                header ~ "array mismatch at index " ~ index.to!string,
                file, line);
    }
    assertEquals(expected.length, actual.length,
            header ~ "array length mismatch",
            file, line);
}

///
unittest
{
    double[] expected = [1, 2, 3];

    assertArrayEquals(expected, [1, 2, 3]);
    assertEquals("array mismatch at index 1; expected: <2> but was: <2.3>",
            collectExceptionMsg!AssertException(assertArrayEquals(expected, [1, 2.3])));
    assertEquals("array length mismatch; expected: <3> but was: <2>",
            collectExceptionMsg!AssertException(assertArrayEquals(expected, [1, 2])));
    assertEquals("array mismatch at index 2; expected: <r> but was: <z>",
            collectExceptionMsg!AssertException(assertArrayEquals("bar", "baz")));
}

/**
 * Asserts that the associative arrays are equal.
 * Throws: AssertException otherwise
 */
void assertArrayEquals(T, U, V)(T[V] expected, U[V] actual, lazy string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    string header = (msg.empty) ? null : msg ~ "; ";

    foreach (key; expected.byKey)
        if (key in actual)
        {
            assertEquals(expected[key], actual[key],
                    // format string key with double quotes
                    format(header ~ `array mismatch at key %(%s%)`, [key]),
                    file, line);
        }

    auto difference = setSymmetricDifference(expected.keys.sort, actual.keys.sort);

    assertEmpty(difference,
            "key mismatch; difference: %(%s, %)".format(difference));
}

///
unittest
{
    double[string] expected = ["foo": 1, "bar": 2];

    assertArrayEquals(expected, ["foo": 1, "bar": 2]);
    assertEquals(`array mismatch at key "foo"; expected: <1> but was: <2>`,
            collectExceptionMsg!AssertException(assertArrayEquals(expected, ["foo": 2])));
    assertEquals(`key mismatch; difference: "bar"`,
            collectExceptionMsg!AssertException(assertArrayEquals(expected, ["foo": 1])));
}

/**
 * Asserts that the value is empty.
 * Throws: AssertException otherwise
 */
void assertEmpty(T)(T actual, lazy string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    if (actual.empty)
        return;

    fail(msg, file, line);
}

///
unittest
{
    assertEmpty([]);
    assertEquals("Assertion failure",
            collectExceptionMsg!AssertException(assertEmpty([1, 2, 3])));
}

/**
 * Asserts that the value is not empty.
 * Throws: AssertException otherwise
 */
void assertNotEmpty(T)(T actual, lazy string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    if (!actual.empty)
        return;

    fail(msg, file, line);
}

///
unittest
{
    assertNotEmpty([1, 2, 3]);
    assertEquals("Assertion failure",
            collectExceptionMsg!AssertException(assertNotEmpty([])));
}

/**
 * Asserts that the value is null.
 * Throws: AssertException otherwise
 */
void assertNull(T)(T actual, lazy string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    if (actual is null)
        return;

    fail(msg, file, line);
}

///
unittest
{
    Object foo = new Object();

    assertNull(null);
    assertEquals("Assertion failure",
            collectExceptionMsg!AssertException(assertNull(foo)));
}

/**
 * Asserts that the value is not null.
 * Throws: AssertException otherwise
 */
void assertNotNull(T)(T actual, lazy string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    if (actual !is null)
        return;

    fail(msg, file, line);
}

///
unittest
{
    Object foo = new Object();

    assertNotNull(foo);
    assertEquals("Assertion failure",
            collectExceptionMsg!AssertException(assertNotNull(null)));
}

/**
 * Asserts that the values are the same.
 * Throws: AssertException otherwise
 */
void assertSame(T, U)(T expected, U actual, lazy string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    if (expected is actual)
        return;

    string header = (msg.empty) ? null : msg ~ "; ";

    fail(header ~ "expected same: <" ~ expected.to!string ~ "> was not: <"~ actual.to!string ~ ">",
            file, line);
}

///
unittest
{
    Object foo = new Object();
    Object bar = new Object();

    assertSame(foo, foo);
    assertEquals("expected same: <object.Object> was not: <object.Object>",
            collectExceptionMsg!AssertException(assertSame(foo, bar)));
}

/**
 * Asserts that the values are not the same.
 * Throws: AssertException otherwise
 */
void assertNotSame(T, U)(T expected, U actual, lazy string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    if (expected !is actual)
        return;

    string header = (msg.empty) ? null : msg ~ "; ";

    fail(header ~ "expected not same",
            file, line);
}

///
unittest
{
    Object foo = new Object();
    Object bar = new Object();

    assertNotSame(foo, bar);
    assertEquals("expected not same",
            collectExceptionMsg!AssertException(assertNotSame(foo, foo)));
}

/**
 * Fails a test.
 * Throws: AssertException
 */
void fail(string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    throw new AssertException(msg, file, line);
}

///
unittest
{
    assertEquals("Assertion failure",
            collectExceptionMsg!AssertException(fail()));
}

alias assertOp!">" assertGreaterThan;
alias assertOp!">=" assertGreaterThanOrEqual;
alias assertOp!"<" assertLessThan;
alias assertOp!"<=" assertLessThanOrEqual;

/**
 * Asserts that the condition (lhs op rhs) is satisfied.
 * Throws: AssertException otherwise
 * See_Also: http://d.puremagic.com/issues/show_bug.cgi?id=4653
 */
template assertOp(string op)
{
    void assertOp(T, U)(T lhs, U rhs, lazy string msg = null,
            string file = __FILE__,
            size_t line = __LINE__)
    {
        mixin("if (lhs " ~ op ~ " rhs) return;");

        string header = (msg.empty) ? null : msg ~ "; ";

        fail("%scondition (%s %s %s) not satisfied".format(header, lhs, op, rhs),
                file, line);
    }
}

///
unittest
{
    assertOp!"<"(2, 3);
    assertEquals("condition (2 >= 3) not satisfied",
            collectExceptionMsg!AssertException(assertOp!">="(2, 3)));
}

/**
 * Checks a probe until the timeout expires. The assert error is produced
 * if the probe fails to return 'true' before the timeout.
 *
 * The parameter timeout determines the maximum timeout to wait before
 * asserting a failure (default is 500ms).
 *
 * The parameter delay determines how often the predicate will be
 * checked (default is 10ms).
 *
 * This kind of assertion is very useful to check on code that runs in another
 * thread. For instance, the thread that listens to a socket.
 *
 * Throws: AssertException when the probe fails to become true before timeout
 */
public static void assertEventually(bool delegate() probe,
        Duration timeout = msecs(500), Duration delay = msecs(10),
        lazy string msg = null,
        string file = __FILE__,
        size_t line = __LINE__)
{
    TickDuration startTime = TickDuration.currSystemTick();

    while (!probe())
    {
        Duration elapsedTime = cast(Duration)(TickDuration.currSystemTick() - startTime);

        if (elapsedTime >= timeout)
            fail(msg.empty ? "timed out" : msg, file, line);

        Thread.sleep(delay);
    }
}

///
unittest
{
    assertEventually({ static count = 0; return ++count > 42; });

    assertEquals("timed out",
            collectExceptionMsg!AssertException(assertEventually({ return false; })));
}

/**
*   Asserts that the template function will return true when called with params
 * Throws: AssertException otherwise
*/
public void assertFun(alias fun, string msg = null, string file = __FILE__,
                      size_t line = __LINE__, T...)(T args)
{
    if(fun(args))
        return;

    fail(text(msg,"Predicate ",__traits(identifier, fun)," returned false with args: ",argsString(args)), file, line);
}

private string argsString(T...)(T args)
{
    string s = "(";
    foreach(arg; args) {
        s ~= to!string(arg) ~ ", ";
        
    }
    s.length -= ", ".length;
    s ~= ")";

    return s;
}
