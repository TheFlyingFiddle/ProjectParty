//          Copyright Juan Manuel Cabo 2012.
//          Copyright Mario Kröplin 2013.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module dunit.framework;

import dunit.assertion;
import dunit.attributes;
import dunit.color;

import core.time;
import std.algorithm;
import std.array;
import std.conv;
import std.stdio;
import std.string;
public import std.typetuple;

struct TestClass
{
    string[] tests;
    string[string] ignoredTests;

    Object function() create;
    void function(Object o) beforeClass;
    void function(Object o) before;
    void function(Object o, string testName) test;
    void function(Object o) after;
    void function(Object o) afterClass;
}

string[] testClassOrder;
TestClass[string] testClasses;

struct TestSelection
{
    string className;
    string[] testNames;
}

mixin template Main()
{
    int main (string[] args)
    {
        import std.stdio;
        int rval;
        try {
            rval = dunit_main(args);
        } catch (Throwable t) {
            writeln(t);
        }
        readln;
        return rval;
    }
}

public int dunit_main(string[] args)
{
    import std.getopt;
    import std.path;
    import std.regex;

    string[] filters = null;
    bool help = false;
    bool list = false;
    string report = null;
    bool verbose = false;

    try
    {
        getopt(args,
                "filter|f", &filters,
                "help|h", &help,
                "list|l", &list,
                "report", &report,
                "verbose|v", &verbose);
    }
    catch (Exception exception)
    {
        stderr.writeln("error: ", exception.msg);
        return 1;
    }

    if (help)
    {
        writefln("Usage: %s [options]", args.empty ? "testrunner" : baseName(args[0]));
        writeln("Run the functions with @Test attribute of all classes that mix in UnitTest.");
        writeln();
        writeln("Options:");
        writeln("  -f, --filter REGEX    Select test functions matching the regular expression");
        writeln("                        Multiple selections are processed in sequence");
        writeln("  -h, --help            Display usage information, then exit");
        writeln("  -l, --list            Display the test functions, then exit");
        writeln("  --report FILE         Write JUnit-style XML test report");
        writeln("  -v, --verbose         Display more information as the tests are run");
        return 0;
    }

    TestSelection[] testSelections = null;

    if (filters is null)
    {
        foreach (className; testClassOrder)
        {
            string[] testNames = testClasses[className].tests;

            testSelections ~= TestSelection(className, testNames);
        }
    }
    else
    {
        foreach (filter; filters)
        {
            foreach (className; testClassOrder)
            {
                foreach (testName; testClasses[className].tests)
                {
                    string fullyQualifiedName = className ~ '.' ~ testName;

                    if (match(fullyQualifiedName, filter))
                    {
                        auto result = testSelections.find!"a.className == b"(className);

                        if (result.empty)
                            testSelections ~= TestSelection(className, [testName]);
                        else
                            result.front.testNames ~= testName;
                    }
                }
            }
        }
    }

    if (list)
    {
        foreach (testSelection; testSelections) with (testSelection)
        {
            foreach (testName; testNames)
            {
                string fullyQualifiedName = className ~ '.' ~ testName;

                writeln(fullyQualifiedName);
            }
        }
        return 0;
    }

    TestListener[] testListeners = null;

    if (verbose)
    {
        testListeners ~= new DetailReporter();
    }
    else
    {
        testListeners ~= new IssueReporter();
    }

    if (!report.empty)
    {
        testListeners ~= new XmlReporter(report);
    }

    auto reporter = new ResultReporter();

    testListeners ~= reporter;
    runTests(testSelections, testListeners);
    return (reporter.errors > 0) ? 1 : (reporter.failures > 0) ? 2 : 0;
}

public static void runTests(TestSelection[] testSelections, TestListener[] testListeners)
in
{
    assert(all!"a !is null"(testListeners));
}
body
{
    bool tryRun(string phase, void delegate() action)
    {
        try
        {
            action();
            return true;
        }
        catch (AssertException exception)
        {
            foreach (testListener; testListeners)
                testListener.addFailure(phase, exception);
            return false;
        }
        catch (Throwable throwable)
        {
            foreach (testListener; testListeners)
                testListener.addError(phase, throwable);
            return false;
        }
    }

    foreach (testSelection; testSelections) with (testSelection)
    {
        foreach (testListener; testListeners)
            testListener.enterClass(className);

        Object testObject = null;
        bool classSetUp = true;  // not yet failed

        // run each @Test of the class
        foreach (testName; testNames)
        {
            bool success = true;
            bool ignore = cast(bool)(testName in testClasses[className].ignoredTests);

            foreach (testListener; testListeners)
                testListener.enterTest(testName);
            scope (exit)
                foreach (testListener; testListeners)
                    testListener.exitTest(success);

            // create test object on demand
            if (!ignore && testObject is null)
            {
                if (classSetUp)
                {
                    classSetUp = tryRun("this",
                            { testObject = testClasses[className].create(); });
                }
                if (classSetUp)
                {
                    classSetUp = tryRun("@BeforeClass",
                            { testClasses[className].beforeClass(testObject); });
                }
            }

            if (ignore || !classSetUp)
            {
                string reason = testClasses[className].ignoredTests.get(testName, null);

                foreach (testListener; testListeners)
                    testListener.skip(reason);
                success = false;
                continue;
            }

            success = tryRun("@Before",
                    { testClasses[className].before(testObject); });

            if (success)
            {
                success = tryRun("@Test",
                        { testClasses[className].test(testObject, testName); });
                // run @After even if @Test failed
                success = tryRun("@After",
                        { testClasses[className].after(testObject); })
                        && success;
            }
        }

        if (testObject !is null && classSetUp)
        {
            tryRun("@AfterClass",
                    { testClasses[className].afterClass(testObject); });
        }
    }

    foreach (testListener; testListeners)
        testListener.exit();
}

interface TestListener
{
    public void enterClass(string className);
    public void enterTest(string testName);
    public void skip(string reason);
    public void addFailure(string phase, AssertException exception);
    public void addError(string phase, Throwable throwable);
    public void exitTest(bool success);
    public void exit();

    public static string prettyOrigin(string className, string testName, string phase)
    {
        string origin = prettyOrigin(testName, phase);

        if (origin.startsWith('@'))
            return className ~ origin;
        else
            return className ~ '.' ~ origin;
    }

    public static string prettyOrigin(string testName, string phase)
    {
        switch (phase)
        {
            case "@Test":
                return testName;
            case "this":
            case "@BeforeClass":
            case "@AfterClass":
                return phase;
            default:
                return testName ~ phase;
        }
    }

    public static string description(Throwable throwable)
    {
        with (throwable)
        {
            if (file.empty)
                return typeid(throwable).name;
            else
                return "%s@%s(%d)".format(typeid(throwable).name, file, line);
        }
    }
}

class IssueReporter : TestListener
{
    private struct Issue
    {
        string testClass;
        string testName;
        string phase;
        Throwable throwable;
    }

    private Issue[] failures = null;
    private Issue[] errors = null;
    private string className;
    private string testName;

    public void enterClass(string className)
    {
        this.className = className;
    }

    public void enterTest(string testName)
    {
        this.testName = testName;
    }

    public void skip(string reason)
    {
        writec(Color.onYellow, "S");
    }

    public void addFailure(string phase, AssertException exception)
    {
        this.failures ~= Issue(this.className, this.testName, phase, exception);
        writec(Color.onRed, "F");
    }

    public void addError(string phase, Throwable throwable)
    {
        this.errors ~= Issue(this.className, this.testName, phase, throwable);
        writec(Color.onRed, "E");
    }

    public void exitTest(bool success)
    {
        if (success)
            writec(Color.onGreen, ".");
    }

    public void exit()
    {
        writeln();

        // report errors
        if (!this.errors.empty)
        {
            writeln();
            if (this.errors.length == 1)
                writeln("There was 1 error:");
            else
                writefln("There were %d errors:", this.errors.length);

            foreach (i, issue; this.errors)
            {
                writefln("%d) %s", i + 1,
                        prettyOrigin(issue.testClass, issue.testName, issue.phase));
                writeln(issue.throwable.toString);
                writeln("----------------");
            }
        }

        // report failures
        if (!this.failures.empty)
        {
            writeln();
            if (this.failures.length == 1)
                writeln("There was 1 failure:");
            else
                writefln("There were %d failures:", this.failures.length);

            foreach (i, issue; this.failures)
            {
                Throwable throwable = issue.throwable;

                writefln("%d) %s", i + 1,
                        prettyOrigin(issue.testClass, issue.testName, issue.phase));
                writefln("%s: %s", description(throwable), throwable.msg);
            }
        }
    }
}

class DetailReporter : TestListener
{
    private string testName;
    private TickDuration startTime;

    public void enterClass(string className)
    {
        writeln(className);
    }

    public void enterTest(string testName)
    {
        this.testName = testName;
        this.startTime = TickDuration.currSystemTick();
    }

    public void skip(string reason)
    {
        writec(Color.yellow, "    SKIP: ");
        writeln(this.testName);
        if (!reason.empty)
            writeln(indent(`"%s"`.format(reason)));
    }

    public void addFailure(string phase, AssertException exception)
    {
        writec(Color.red, "    FAILURE: ");
        writeln(prettyOrigin(this.testName, phase));
        writeln(indent("%s: %s".format(description(exception), exception.msg)));
    }

    public void addError(string phase, Throwable throwable)
    {
        writec(Color.red, "    ERROR: ");
        writeln(prettyOrigin(this.testName, phase));
        writeln("        ", throwable.toString);
        writeln("----------------");
    }

    public void exitTest(bool success)
    {
        if (success)
        {
            double elapsed = (TickDuration.currSystemTick() - this.startTime).usecs() / 1_000.0;

            writec(Color.green, "    OK: ");
            writefln("%6.2f ms  %s", elapsed, this.testName);
        }
    }

    public void exit()
    {
        // do nothing
    }

    private string indent(string s, string indent = "        ")
    {
        return s.splitLines(KeepTerminator.yes).map!(line => indent ~ line).join;
    }
 }

class ResultReporter : TestListener
{
    private uint tests = 0;
    private uint failures = 0;
    private uint errors = 0;
    private uint skips = 0;

    public void enterClass(string className)
    {
        // do nothing
    }

    public void enterTest(string testName)
    {
        ++this.tests;
    }

    public void skip(string reason)
    {
        ++this.skips;
    }

    public void addFailure(string phase, AssertException exception)
    {
        ++this.failures;
    }

    public void addError(string phase, Throwable throwable)
    {
        ++this.errors;
    }

    public void exitTest(bool success)
    {
        // do nothing
    }

    public void exit()
    {
        writeln();
        writefln("Tests run: %d, Failures: %d, Errors: %d, Skips: %d",
                this.tests, this.failures, this.errors, this.skips);

        if (this.failures + this.errors == 0)
        {
            writec(Color.onGreen, "OK");
            writeln();
        }
        else
        {
            writec(Color.onRed, "NOT OK");
            writeln();
        }
    }
}

class XmlReporter : TestListener
{
    import std.xml;

    private string fileName;
    private Document document;
    private Element testSuite;
    private Element testCase;
    private string className;
    private TickDuration startTime;

    public this(string fileName)
    {
        this.fileName = fileName;
        this.document = new Document(new Tag("testsuites"));
        this.testSuite = new Element("testsuite");
        this.testSuite.tag.attr["name"] = "dunit";
        this.document ~= this.testSuite;
    }

    public void enterClass(string className)
    {
        this.className = className;
    }

    public void enterTest(string testName)
    {
        this.testCase = new Element("testcase");
        this.testCase.tag.attr["classname"] = this.className;
        this.testCase.tag.attr["name"] = testName;
        this.testSuite ~= this.testCase;
        this.startTime = TickDuration.currSystemTick();
    }

    public void skip(string reason)
    {
        // avoid wrong interpretation of more than one child
        if (this.testCase.elements.empty)
        {
            auto element = new Element("skipped");

            element.tag.attr["message"] = reason;
            this.testCase ~= element;
        }
    }

    public void addFailure(string phase, AssertException exception)
    {
        // avoid wrong interpretation of more than one child
        if (this.testCase.elements.empty)
        {
            auto element = new Element("failure");
            string message = "%s %s: %s".format(phase,
                    description(exception), exception.msg);

            element.tag.attr["message"] = message;
            this.testCase ~= element;
        }
    }

    public void addError(string phase, Throwable throwable)
    {
        // avoid wrong interpretation of more than one child
        if (this.testCase.elements.empty)
        {
            auto element = new Element("error", throwable.info.toString);
            string message = "%s %s: %s".format(phase,
                    description(throwable), throwable.msg);

            element.tag.attr["message"] = message;
            this.testCase ~= element;
        }
    }

    public void exitTest(bool success)
    {
        double elapsed = (TickDuration.currSystemTick() - this.startTime).msecs() / 1_000.0;

        this.testCase.tag.attr["time"] = "%.3f".format(elapsed);
    }

    public void exit()
    {
        import std.file;

        string report = join(this.document.pretty(4), "\n") ~ "\n";

        write(this.fileName, report);
    }
}

/**
 * Registers a class as a unit test.
 */
mixin template UnitTest()
{
    private static this()
    {
        import std.range;

        alias TypeTuple!(__traits(allMembers, typeof(this))) allMembers;

        TestClass testClass;
        string[] ignoredTests = _annotations!(typeof(this), Ignore, allMembers).dup;

        testClass.tests = _memberFunctions!(typeof(this), Test, allMembers).dup;
        foreach (chunk; chunks(ignoredTests, 2))
        {
            string testName = chunk[0];
            string reason = chunk[1];

            testClass.ignoredTests[testName] = reason;
        }

        static Object create()
        {
            mixin("return new " ~ typeof(this).stringof ~ "();");
        }

        static void beforeClass(Object o)
        {
            mixin(_sequence(_memberFunctions!(typeof(this), BeforeClass, allMembers)));
        }

        static void before(Object o)
        {
            mixin(_sequence(_memberFunctions!(typeof(this), Before, allMembers)));
        }

        static void test(Object o, string name)
        {
            mixin(_choice(_memberFunctions!(typeof(this), Test, allMembers)));
        }

        static void after(Object o)
        {
            mixin(_sequence(_memberFunctions!(typeof(this), After, allMembers)));
        }

        static void afterClass(Object o)
        {
            mixin(_sequence(_memberFunctions!(typeof(this), AfterClass, allMembers)));
        }

        testClass.create = &create;
        testClass.beforeClass = &beforeClass;
        testClass.before = &before;
        testClass.test = &test;
        testClass.after = &after;
        testClass.afterClass = &afterClass;

        testClassOrder ~= this.classinfo.name;
        testClasses[this.classinfo.name] = testClass;
    }

    private static string _choice(const string[] memberFunctions)
    {
        string block = "auto testObject = cast(" ~ typeof(this).stringof ~ ") o;\n";

        block ~= "switch (name)\n{\n";
        foreach (memberFunction; memberFunctions)
            block ~= `case "` ~ memberFunction ~ `": testObject.` ~ memberFunction ~ "(); break;\n";
        block ~= "default: break;\n}\n";
        return block;
    }

    private static string _sequence(const string[] memberFunctions)
    {
        string block = "auto testObject = cast(" ~ typeof(this).stringof ~ ") o;\n";

        foreach (memberFunction; memberFunctions)
            block ~= "testObject." ~ memberFunction ~ "();\n";
        return block;
    }

    private template _memberFunctions(alias T, attribute, names...)
    {
        static if (names.length == 0)
            immutable(string[]) _memberFunctions = [];
        else
            static if (__traits(compiles, mixin("(new " ~ T.stringof ~ "())." ~ names[0] ~ "()"))
                    && _hasAttribute!(T, names[0], attribute))
                immutable(string[]) _memberFunctions = [names[0]] ~ _memberFunctions!(T, attribute, names[1 .. $]);
            else
                immutable(string[]) _memberFunctions = _memberFunctions!(T, attribute, names[1 .. $]);
    }

    private template _hasAttribute(alias T, string name, attribute)
    {
        alias TypeTuple!(__traits(getMember, T, name)) member;
        alias TypeTuple!(__traits(getAttributes, member)) attributes;

        enum _hasAttribute = staticIndexOf!(attribute, attributes) != -1;
    }

    private template _annotations(alias T, attribute, names...)
    {
        static if (names.length == 0)
            immutable(string[]) _annotations = [];
        else
            static if (__traits(compiles, mixin("(new " ~ T.stringof ~ "())." ~ names[0] ~ "()")))
            {
                alias TypeTuple!(__traits(getMember, T, names[0])) member;
                alias TypeTuple!(__traits(getAttributes, member)) attributes;
                enum index = _indexOfValue!(attribute, attributes);

                static if (index != -1)
                    immutable(string[]) _annotations = [names[0], attributes[index].reason]
                            ~ _annotations!(T, attribute, names[1 .. $]);
                else
                    immutable(string[]) _annotations = _annotations!(T, attribute, names[1 .. $]);
            }
            else
                immutable(string[]) _annotations = _annotations!(T, attribute, names[1 .. $]);
    }

    private template _indexOfValue(attribute, T...)
    {
        static if (T.length == 0)
            enum _indexOfValue = -1;
        else
            static if (is(typeof(T[0]) : attribute))
                enum _indexOfValue = 0;
            else
            {
                enum index = _indexOfValue!(attribute, T[1 .. $]);
                enum _indexOfValue = (index == -1) ? -1 : index + 1;
            }
    }
}
