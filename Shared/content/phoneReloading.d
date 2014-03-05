module content.phoneReloading;

import std.path, std.stdio, std.file, util.bitmanip, std.algorithm;
//
//void sendAssets(ulong id, string phoneDirectory)
//{
//    auto dirPath = buildPath(resourceDir, phoneDirectory);
//    foreach(item; dirEntries(dirPath, SpanMode.breadth))
//    {
//        if(item.isFile()) {
//            auto path = item.name.findSplit(phoneDirectory)[0];
//            sendAsset(id, item.name, path.replace("\\", "/"));
//        }
//    }
//}