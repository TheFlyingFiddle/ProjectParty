module sdltest;


version(unittest) {	

	import dunit, content.sdl, allocation, collections;
	class TestSDL 
	{


		mixin UnitTest;


		@Test public void testNumbers() {
			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);
			auto obj = fromSDL(app, 
							   "numberone 	    = 123456
							   numbertwo 	    = 1234.234
							   numberthree      = 1234.34e234
							   numberfour 	    = 1234.34E-234
							   numberfive 	    = -1234
							   numbersix 	    = 0xfF
							   numberseven 	    = 0x1_0000"
							   );

			assertEquals(obj.numberone 	 .as!int, 123456);

			import std.math : approxEqual;
			assertFun!(approxEqual)(obj.numbertwo.as!double, 1234.234);
			assertFun!(approxEqual)(obj.numberthree.as!double, 1234.34e234);
			assertFun!(approxEqual)(obj.numberfour.as!double, 1234.34E-234);
			assertEquals(obj.numberfive	.as!int, -1234);
			assertEquals(obj.numbersix	.as!int, 0xfF);
			assertEquals(obj.numberseven.as!int, 0x10000);
		}


		@Test public void testSample() {

			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);
			auto obj = fromSDL(app, 
							   "
							   map = 
							   {
							   width  = 800
							   height = 600
							   }

							   snakes =
							   [
							   {	
							   posx = 400
							   posy = 10
							   dirx = 1
							   diry = 0.
							   color = 42131241
							   leftKey = 65
							   rightKey = 68
							   },
							   {
							   posx = 100
							   posy = 50
							   dirx = 1.
							   diry = 0
							   color = 51231241
							   leftKey = 263
							   rightKey = 262
							   }
							   ]
							   turnSpeed = 0.02
							   freeColor = 0
							   title = |i am string|");

			assertEquals(obj.map.width        .as!int, 800);
			assertEquals(obj.map.height       .as!int, 600);

			assertEquals(obj.snakes[0].posx 	.as!int, 400);
			assertEquals(obj.snakes[0].posy     .as!int, 10);

			import std.math : approxEqual;
			assertFun!(approxEqual)(obj.snakes[0].dirx       .as!double, 1.);
			assertFun!(approxEqual)(obj.snakes[0].diry       .as!double, 0);
			assertEquals(obj.snakes[0].color 	.as!int, 42131241);
			assertEquals(obj.snakes[0].leftKey 	.as!int, 65);
			assertEquals(obj.snakes[0].rightKey .as!int, 68);

			assertEquals(obj.snakes[1].posx.as!int, 100);
			assertEquals(obj.snakes[1].posy.as!int, 50);
			assertFun!(approxEqual)(obj.snakes[1].dirx.as!double, 1.);
			assertFun!(approxEqual)(obj.snakes[1].diry.as!double, 0);
			assertEquals(obj.snakes[1].color    .as!int, 51231241);
			assertEquals(obj.snakes[1].leftKey 	.as!int, 263);
			assertEquals(obj.snakes[1].rightKey .as!int, 262);

			assertTrue(approxEqual(obj.turnSpeed.as!double, 0.02));
			assertEquals(obj.freeColor.as!int, 0);

			auto stringBuf = new void[1024];
			auto allocString = RegionAllocator(stringBuf);
			assertEquals(obj.title.as!string(allocString), "i am string");
		}

		@Test public void testBooleans() {

			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);
			auto obj = fromSDL(app, 
							   "
							   booleans =
							   [
							   {	
							   testfalse = false
							   testFalse = False
							   },
							   {
							   testtrue = true
							   testTrue = True
							   }
							   ]"
							   );

			assertFalse(obj.booleans[0].testfalse.as!bool);
			assertFalse(obj.booleans[0].testFalse.as!bool);
			assertTrue(obj.booleans[1].testtrue.as!bool);
			assertTrue(obj.booleans[1].testTrue.as!bool);
		}

		@Test public void testUnderscores() {
			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);
			auto obj = fromSDL(app, 
							   "numberone 	    = 123_456
							   numbertwo 	    = 1_234.234
							   numberthree      = 1_234._3_4e2_34
							   numberfour 	    = 123_4.3_4E-23_4
							   numberfive 	    = -1_234
							   numbersix 	    = 0xf_F
							   numberseven 	    = 0x10_000"
							   );

			assertEquals(obj.numberone.as!int, 123456);

			import std.math : approxEqual;
			assertFun!(approxEqual)(obj.numbertwo 	 .as!double, 1234.234);
			assertFun!(approxEqual)(obj.numberthree   .as!double, 1234.34e234);
			assertFun!(approxEqual)(obj.numberfour 	 .as!double, 1234.34E-234);
			assertEquals(obj.numberfive 	.as!int, -1234);
			assertEquals(obj.numbersix 		.as!int, 0xfF);
			assertEquals(obj.numberseven 	.as!int, 0x10000);
		}

		@Test public void testVectors() {
			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);
			auto obj = fromSDL(app,
							   "pos = "
							   ~"{"
							   ~"x = 4 "
							   ~"y = 5"
							   ~"}"
							   ~"floats ="
							   ~"{"
							   ~"x = 234.2 "
							   ~"y = 123.4"
							   ~"}"
							   );
			import math.vector;
			auto vec = obj.pos.as!int2;
			auto vecFloat = obj.floats.as!float2;
			assertEquals(vec, int2(4,5));
			assertEquals(vecFloat, float2(234.2f,123.4f));
		}

		@Test public void testOptional() {
			struct OptionalFields {
				@Optional(7) int totallyOptional;
				int notOptional;
				@Optional(7) int alsoOptional;
			}

			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);
			auto obj = fromSDL(app, "notOptional = 4 alsoOptional = 4");
			auto test = obj.as!OptionalFields;
			assertEquals(test.totallyOptional, 7);
			assertEquals(test.notOptional, 4);
			assertEquals(test.alsoOptional, 4);
		}

		@Test public void testOptionalArray() {
			struct OptionalArrs {
				@Optional([1,2,3]) int[] opt;
				int[] notOpt;
			}
			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);
			auto obj = fromSDL(app, "notOpt = [1,2,4]");
			auto buf2 = new void[1024];
			auto alloc2 = RegionAllocator(buf2);
			auto test = obj.as!OptionalArrs(alloc2);
			assertArrayEquals(test.opt, [1,2,3]);
			assertArrayEquals(test.notOpt, [1,2,4]);
		}

		@Test public void testToSdlSample() {
			struct Snake
			{
				long posx;
				long posy;
				double dirx;
				double diry;
				long color;
				long leftKey;
				long rightKey;

			}
			import math.vector;
			struct AchtungConfig
			{
				int2 map;
				Snake[] snakes;
				double turnSpeed;
				long freeColor;
			}

			Snake s1 = Snake(400, 10, 1, 0., 42131241, 65, 68);
			Snake s2 = Snake(100, 50, 1., 0., 51231241, 263, 262);

			auto config = AchtungConfig(int2(800,600), [s1,s2], 0.02, 0);

			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!char(alloc);
			toSDL(config, app);
			auto source = app.data;
			import collections.list;
			auto checkSource = "
map=
{
	x=800
	y=600
}
snakes=[
	{
		posx=400
		posy=10
		dirx=1.
		diry=0.
		color=42131241
		leftKey=65
		rightKey=68
	},
	{
		posx=100
		posy=50
		dirx=1.
		diry=0.
		color=51231241
		leftKey=263
		rightKey=262
	}]
turnSpeed=0.02
freeColor=0"; // Significant whitespace.

			List!(T) from(T)(T[] content) {
				return List!T(content.ptr, cast(uint)content.length, cast(uint)content.length);
			}

			auto check = from(cast(char[])checkSource);
			assertEquals(check, source);
		}

		@Test public void testArrayAsList()
		{
			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);
			auto obj = fromSDL(app, "arr = [1,2,4]");

			auto buf2 = new void[1024];
			auto alloc2 = RegionAllocator(buf2);
			auto list = List!long(alloc2, 3);
			list.put(1);
			list.put(2);
			list.put(4);

			auto sList = obj.arr.as!(List!long)(alloc2);

			assertEquals(sList, list);
		}

		@Test public void testOnlyArrayStruct()
		{

			struct ListStruct {
				List!long longList;
			}

			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);
			auto obj = fromSDL(app, "lstruct = { longList = [1,2,5] }");
		}

		@Test public void testStructWithLists()
		{
			struct ListStruct {
				List!long longList;
				int integer;
			}

			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);
			auto obj = fromSDL(app, "lstruct = { 
							   longList=[1,2,5] 
							   integer=5
							   }");

			auto buf2 = new void[1024];
			auto alloc2 = RegionAllocator(buf2);
			auto list = List!long(alloc2, 3);
			list.put(1);
			list.put(2);
			list.put(5);
			auto ls = ListStruct(list, 5);

			auto sourceLs = obj.lstruct.as!(ListStruct)(alloc2);
			assertEquals(ls, sourceLs);
		}

		@Test public void testEnum()
		{

			enum Q {a,b,c}
			struct EnumStruct {
				Q enumField;
			}

			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);
			auto obj = fromSDL(app, "estruct = { enumField = a }");

			assertEquals(obj.estruct.enumField.as!Q, Q.a);
		}

		@Test public void testNoStringSeparators()
		{

			enum Q {a,b,c}

			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);
			auto obj = fromSDL(app, "teststring = { s = nowhitespace }");

			auto buf2 = new void[1024];
			auto alloc2 = RegionAllocator(buf2);

			assertEquals(obj.teststring.s.as!string(alloc2), "nowhitespace");
		}

		@Test public void testRecursiveStruct()
		{

			struct StructB
			{
				int i;
				int j;
			}

			struct StructC
			{
				string asdf;
			}

			struct StructA
			{
				StructB b;
				StructC c;
			}


			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);
			import collections.list;
			auto source = 
				"structa = {"
				~"	b = { i = 5 j = 3 }"
				~"	c = { asdf = asdf }"
				~"}";
			auto obj = fromSDL(app, source);

			auto a = StructA(StructB(5,3), StructC("asdf"));

			auto buf2 = new void[1024];
			auto alloc2 = RegionAllocator(buf2);

			assertEquals(a, obj.structa.as!StructA(alloc2));
		}

		@Test public void testStringArray()
		{
			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);
			import collections.list;

			struct StructA  { string[] phoneResources; }
			auto source = 
				"phoneResources = [
				|achtung/scripts/main.lua|,
				|achtung/scripts/rendertime.lua|,
				|achtung/scripts/button.lua|,
				|achtung/scripts/rect.lua|,
				|achtung/fonts/Segoe54.fnt|,
				|achtung/fonts/Segoe54_0.png|,
				|achtung/textures/wallpaper.png|
				]";
			auto obj = fromSDL(app, source);

			auto a = StructA();
			a.phoneResources = [
				"achtung/scripts/main.lua",
				"achtung/scripts/rendertime.lua",
				"achtung/scripts/button.lua",
				"achtung/scripts/rect.lua",
				"achtung/fonts/Segoe54.fnt",
				"achtung/fonts/Segoe54_0.png",
				"achtung/textures/wallpaper.png"
			];

			auto buf2 = new void[1024];
			auto alloc2 = RegionAllocator(buf2);

			assertEquals(a, obj.as!StructA(alloc2));
		}

		@Test public void testColor()
		{
			import graphics.color;
			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);
			import collections.list;

			struct StructA  { string[] phoneResources; }
			auto source = "packedValue = 0xFFFFFFFF";
			auto obj = fromSDL(app, source);

			assertEquals(Color(0xFFFFFFFF), obj.as!Color);
		}

		@Test public void testRecursiveList()
		{
			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);
			auto obj = fromSDL(app, "arr = [[1,2,3],[4],[5]]");

			auto buf2 = new void[1024];
			auto alloc2 = RegionAllocator(buf2);
			auto list1 = List!long(alloc2, 3);
			list1.put(1);
			list1.put(2);
			list1.put(3);
			auto list2 = List!long(alloc2, 1);
			list2.put(4);
			auto list3 = List!long(alloc2, 1);
			list3.put(5);
			auto listOfLists = List!(List!long)(alloc2, 3);
			listOfLists.put(list1);
			listOfLists.put(list2);
			listOfLists.put(list3);

			auto sList = obj.arr.as!(List!(List!long))(alloc2);

			assertEquals(sList, listOfLists);
		}


		@Test public void testRecursiveArray()
		{
			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);
			auto obj = fromSDL(app, "arr = [[1,2,3],[4],[5]]");

			long[][] arrOfArrs = [[1,2,3],[4],[5]];

			auto buf2 = new void[1024];
			auto alloc2 = RegionAllocator(buf2);

			auto sList = obj.arr.as!(long[][])(alloc2);

			assertEquals(sList, arrOfArrs);
		}

		@Test public void testNoWhiteSpaceDontEndWithSpace()
		{
			{
				auto buf = new void[1024];
				auto alloc = RegionAllocator(buf);
				auto app = RegionAppender!SDLObject(alloc);
				auto obj = fromSDL(app, "teststring = { s = nowhitespace}"); // No space before } curly brace

				auto buf2 = new void[1024];
				auto alloc2 = RegionAllocator(buf2);

				assertEquals(obj.teststring.s.as!string(alloc2), "nowhitespace");
			}

			{
				auto buf = new void[1024];
				auto alloc = RegionAllocator(buf);
				auto app = RegionAppender!SDLObject(alloc);
				auto obj = fromSDL(app, "teststring = nowhitespace"); // sudden EOF while parsing identifier

				auto buf2 = new void[1024];
				auto alloc2 = RegionAllocator(buf2);

				assertEquals(obj.teststring.as!string(alloc2), "nowhitespace");
			}
		}

		@Test void testConversion()
		{
			import graphics;
			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);
			struct TestStruct
			{
				@Convert!cFun() Color color;
			}
			auto obj = fromSDL(app, "color = 0xFF0000FF");
			assertEquals(obj.as!TestStruct, TestStruct(Color.red));
		}

		@Test void testConversionString()
		{
			import graphics;
			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);
			struct TestStruct
			{
				@Convert!cFun2() int str;
			}
			auto obj = fromSDL(app, "str = |asdf4|");
			auto region = RegionAllocator(new void[1024]);
			assertEquals(obj.as!TestStruct(region), TestStruct(5));
		}

		@Test void testConversionStruct()
		{
			import graphics;
			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);

			struct TestStruct
			{
				@Convert!cFun3() TestStruct2 str;
				@Convert!cFun3() TestStruct2 str2;
			}
			auto obj = fromSDL(app, "str = |asdf4| str2 = |asdf6|");
			auto region = RegionAllocator(new void[1024]);
			assertEquals(obj.as!TestStruct(region), TestStruct(TestStruct2(1,2), TestStruct2(1,2)));
		}

		@Test void testEmptyList()
		{
			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);

			struct TestStruct
			{
				List!int ints;
				List!string strings;
			}
			auto obj = fromSDL(app, "ints = [] strings = []");
			
			auto region = RegionAllocator(new void[1024]);
			assertEquals(TestStruct(), obj.as!TestStruct(region));
		}

		@Test void testEmptyString()
		{
			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);

			struct TestStruct
			{
				string str;
				string str2;
			}
			auto obj = fromSDL(app, "str = || str2 = ||");
			auto region = RegionAllocator(new void[1024]);
			assertEquals(obj.as!TestStruct(region), TestStruct());
		}

		@Test void testUTF8String()
		{
			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);

			struct TestStruct
			{
				string str;
			}
			auto obj = fromSDL(app, "str = |Vad heter solen på engelska?|");
			auto region = RegionAllocator(new void[1024]);
			assertEquals(obj.as!TestStruct(region), TestStruct("Vad heter solen på engelska?"));
		}

		@Test void testUTF8StringFromFile()
		{
			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);

			struct TestStruct
			{
				string str;
			}
			auto obj = fromSDLFile!TestStruct(alloc, "test.sdl");
			assertEquals(obj, TestStruct("Vad heter solen på engelska?"));
		}

		@Test public void testNestedOptional() {
			struct OptionalFields {
				@Optional(7) int totallyOptional;
				@Optional(3) int alsoOptional;
			}
			struct Wrapper {
				OptionalFields opt;
			}

			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);
			auto test = fromSDL!Wrapper(app, "opt =  { alsoOptional = 4 }");
			assertEquals(test.opt.totallyOptional, 7);
			assertEquals(test.opt.alsoOptional, 4);
		}

		@Test public void testNoWhiteSpace() {
			struct OptionalFields {
				@Optional(7) int totallyOptional;
				@Optional(3) int alsoOptional;
			}
			struct Wrapper {
				OptionalFields opt;
			}

			auto buf = new void[1024];
			auto alloc = RegionAllocator(buf);
			auto app = RegionAppender!SDLObject(alloc);
			auto test = fromSDL!Wrapper(app, "opt={alsoOptional=4}");
			assertEquals(test.opt.totallyOptional, 7);
			assertEquals(test.opt.alsoOptional, 4);
		}

		@Test public void testToLuaFromFile() {
			toLuaFileFromFile("test2.sdl", "luaTest.lua");
			import std.file, std.stdio;
			assertEquals(
						   "local sdlObject =\n"~
						   "{\n"~
						   "	map = \n"~
						   "	{\n"~
						   "		x = 800,\n"~
						   "		y = 600,\n"~
						   "	},\n"~
						   "	snakes = \n"~
						   "	{\n"~
						   "		{\n"~
						   "			posx = 400,\n"~
						   "			posy = 10,\n"~
						   "			dirx = 1,\n"~
						   "			diry = 0,\n"~
						   "			color = 42131241,\n"~
						   "			leftKey = 65,\n"~
						   "			rightKey = 68,\n"~
						   "		},\n"~
						   "		{\n"~
						   "			posx = 100,\n"~
						   "			posy = 50,\n"~
						   "			dirx = 1,\n"~
						   "			diry = 0,\n"~
						   "			color = 51231241,\n"~
						   "			leftKey = 263,\n"~
						   "			rightKey = 262,\n"~
						   "		},\n"~
						   "	},\n"~
						   "	turnSpeed = 0.02,\n"~
						   "	freeColor = 0,\n"~
						   "}\n"~
						   "return sdlObject", cast(string)read("luaTest.lua"));
		}
	}

	struct TestStruct2
	{
		int x, y;
	}
	//Global testing functions
	import graphics.color;
	Color cFun(uint c) { return Color(c); }
	int cFun2(string s) { return s.length; }
	TestStruct2 cFun3(string s) { return TestStruct2(1,2); }
}