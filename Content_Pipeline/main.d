import std.stdio;
import std.file;
import content.sdl;
import std.datetime, std.conv;
import allocation;
import util.hash, std.algorithm, std.array, std.string, std.path;
import compilers;
import filewatcher;
import broadcaster;
import content.file;
import log;
import network.service;
import distancefont;

void main(string[] argv)
{
	string inDirectory  = "..\\resources"; //argv[1];
	string outDirectory = "..\\compiled_resources"; //argv[2];
	
	auto watcher = FileWatcher(inDirectory);
	spawnReloadingService();

	initializeRemoteLogging("Content_Pipeline");
	scope (exit) termRemoteLogging();

	while(true)
	{
		try
			build(inDirectory, outDirectory);
		catch(Throwable t) {
			logInfo("Crash!\n", t); 
		}
		
		watcher.waitForFileChanges();
	}
}

ubyte[] buffer; 
Appender!(char[]) sink;
Appender!(FileItem[]) files; 

shared static this()
{
	initCompilers();
	buffer = new ubyte[1024 * 1024 * 10];
	sink   = appender!(char[]);
	files  = appender!(FileItem[]);
}

static ~this()
{
	deinitCompilers();
}
struct ItemChanged
{
	string name;
	ulong lastChanged;
}

struct Dependencies
{
	string name;
	string[] deps;
}

struct FileCache
{
	Dependencies[] dependencies;
	ItemChanged[]  itemChanged;
}

void makeDir(const(char)[] dir)
{
	if(!exists(dir))
		mkdir(dir);
}

void build(string inDir, string outDir)
{
	makeDir(outDir);
	DirEntry[] games;
	foreach(entry; dirEntries(inDir, SpanMode.shallow))
	{
		if(entry.isDir) {
			games ~= entry;
			makeDir(entry.name.replace(inDir, outDir));				
		}
	}
	foreach(game; games)
	{
		foreach(entry; dirEntries(game.name, SpanMode.shallow)) if(entry.isDir)
		{
			auto name = entry.name[entry.name.lastIndexOf(dirSeparator) + 1 .. $];
			if(name == "phone")	{
				auto phoneDir = entry.name.replace(inDir, outDir);
				makeDir(phoneDir);
				compileFolder(entry.name, phoneDir, Platform.phone);
			}
			if(name == "desktop") {
				auto desktopDir = entry.name.replace(inDir, outDir);
				makeDir(desktopDir);
				compileFolder(entry.name, desktopDir, Platform.desktop);
			}
		}
	}
}

struct FileCompiler
{
	string ext;
	int order;
	Compiler compile;
}

alias Compiler = CompiledFile function(void[], DirEntry, ref Context);
FileCompiler[] fileCompilers;

static this()
{
	import textureatlas, font;
	fileCompilers = 
	[ 
		FileCompiler(".psd", 10, &compileImage),
		FileCompiler(".png", 10, &compileImage),
		FileCompiler(".jpg", 10, &compileImage),
		FileCompiler(".lua", 10, &passThrough),
		FileCompiler(".sdl", 10, &passThrough),
		FileCompiler(".wav", 10, &passThrough),
		FileCompiler(".ogg", 10, &passThrough),
		FileCompiler(".luac", 10, &passThrough),
		FileCompiler(".fontatl", 2, &compileDistFont),
		FileCompiler(".fnt", 2, &compileFont),
		FileCompiler(".atl", 1, &compileAtlas)
	];
}

int order(string ext)
{
	auto index = fileCompilers.countUntil!(x => x.ext == ext);
	return index != -1 ? fileCompilers[index].order : index;
}

enum Platform
{
	phone,
	desktop
}

CompiledFile passThrough(void[] data, DirEntry entry, ref Context context)
{
	return CompiledFile([CompiledItem(entry.name.extension, data)]);
}

struct Context
{
	string inFolder;
	string outFolder;
	Platform platform;
	string[] usedNames;
}

struct ResourceDetails
{
	string originalName;
	string ouputName;
}

void compileFolder(string inFolder, string outFolder, Platform platform)
{
	Context context = Context(inFolder, outFolder, platform);
	FileCache fileCache = addUnchanged(context);
	fileCache.itemChanged.length = 0;

	bool hasChanged = false;

	auto entries = dirEntries(inFolder, SpanMode.breadth).
						 filter!(x => x.isFile && x.name.extension.order != -1).
						 array.
						 sort!((a, b) => a.name.extension.order < b.name.extension.order);
	
	foreach(entry; entries)
	{
		auto name     = entry.name[inFolder.length + 1 .. $ - entry.name.extension.length];
		fileCache.itemChanged  ~= ItemChanged(name ~ entry.name.extension,  timeLastModified(entry.name).stdTime);
	
		if(context.usedNames.canFind(name)) continue;
		import std.datetime;
		StopWatch watch;
		watch.start();


		logInfo("Compiling File: ", entry.name);
		hasChanged = true;

		context.usedNames ~= name;

		auto nameHash = bytesHash(name.ptr ,name.length, 0);
		auto f		  = File(entry.name, "rb");
		auto file	  = f.rawRead(buffer);

		auto index		= fileCompilers.countUntil!(x => x.ext == entry.name.extension);
		auto compiled	= fileCompilers[index].compile(file, entry, context);

		foreach(i, item; compiled.items) {
			auto wName	   = to!string(nameHash.value) ~ item.extension;
			auto writeName = buildPath(outFolder, wName);
			auto writeFile = File(writeName, "w");
			writeFile.rawWrite(item.data);
		}

		reloadChanged(compiled.items, nameHash);
		fileCache.dependencies ~= Dependencies(name ~ entry.name.extension, compiled.dependencies);

		watch.stop();
		logInfo("Took ", watch.peek().msecs, " msecs.");
	}

	if(hasChanged)
	{
		writeMapFile(outFolder);
		toSDLFile(outFolder, "FileCache.sdl", fileCache);
		//Create a resource folder used in lua.
		if(platform == Platform.phone)
		{
			writeResourceFile(inFolder, outFolder, "R.lua");
		}
	}
}

private void writeMapFile(string folder)
{
	foreach(file; dirEntries(folder, SpanMode.breadth)) 
		if(file.name.baseName != "FileCache.sdl" &&
		   file.name.baseName != "Map.sdl")
	{
		auto f		  = File(file.name, "rb");
		auto data	  = f.rawRead(buffer);
		auto fileHash = bytesHash(data.ptr, data.length);
		files ~= FileItem(file.name.baseName, fileHash);
	}

	toSDLFile(folder, "Map.sdl", FileMap(files.data));
	files.clear(); 
}

private void writeResourceFile(string inFolder, string outFolder, string destFile)
{
	auto outputFiles = dirEntries(outFolder, SpanMode.breadth).map!(x => x.name[outFolder.length + 1 .. $]).array;

	auto resourceDir = outFolder.dirName.baseName.replace("\\", "/");

	sink.put("global.R = \n{\n\n\t");
	foreach(entry; dirEntries(inFolder, SpanMode.breadth))
	{
		auto name    = entry.name[inFolder.length + 1 .. $];
		auto hash    = bytesHash(name.stripExtension());
		import std.stdio;
		
		foreach(of; outputFiles)
		{
			import std.ascii;
			if(isNumeric(stripExtension(of)))
			{
				auto outHash = HashID(to!uint(stripExtension(of)));
				if(hash == outHash)
				{
					auto goodName = stripExtension(name).replace("\\", "_");
					sink.put(goodName);
					sink.put(" = { path = \"");
					sink.put(resourceDir);
					sink.put("/");
					sink.put(of);
					sink.put("\", hash = ");
					sink.put(to!string(outHash.value));
					sink.put(", type = \"");
					sink.put(of.extension[1 .. $]);
					sink.put("\" },\n\t");
					break;
				}
			}
		}
	}

	sink.put("\n}");

	auto file = File(buildPath(outFolder, destFile), "w");
	file.write(sink.data);
	sink.clear();
}

private void toSDLFile(T)(string folder, string name, T data)
{
	auto toWrite = buildPath(folder, name);
	toSDL(data, sink);
	auto file = File(toWrite, "w");
	file.write(sink.data);
	sink.clear();
}

FileCache addUnchanged(ref Context context)
{
	FileCache cache;
	auto cachePath = buildPath(context.outFolder, "FileCache.sdl");
	if(!exists(cachePath)) 
	{
		logInfo("No file cache found!", cachePath);
		return FileCache.init;	
	}

	cache = fromSDLFile!FileCache(Mallocator.it, cachePath);
	foreach_reverse(i, item; cache.itemChanged)
	{
		auto path = buildPath(context.inFolder, item.name);
		
		if(path.exists && path.timeLastModified.stdTime == item.lastChanged)
		{
			auto wExt = stripExtension(item.name);
			context.usedNames ~= wExt;
		} 
		else
		{
			cache.itemChanged = cache.itemChanged.remove(i);
			logInfo("File Changed! ", path);
		}
	}

	foreach_reverse(i, deps; cache.dependencies)
	{
		if(deps.deps.length == 0) continue;

		if(!deps.deps.all!(x => context.usedNames.canFind(stripExtension(x))))
		{
			cache.dependencies = cache.dependencies.remove(i);
			auto index = context.usedNames.countUntil!(x => x == stripExtension(deps.name));
			if(index != -1)
			{
				context.usedNames = context.usedNames.remove(index);
			}
		}
	}

	return cache;
}