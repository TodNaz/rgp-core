module rgp.core.maploader;

import rgp.core.mread;
import sdlang;

struct MapLoaderInfo
{
public:
    string main;
    string[] maps;
}

MapLoaderInfo loadConfig(string path) @trusted
{
    Tag root = parseFile(path);

    string mapsDir;
    string mainMap;

    foreach (Tag tag; root.all.tags)
    {
        if (tag.name == "mapsDir")
        {
            mapsDir = tag.getValue!string("{error}");
        } else
        if (tag.name == "mainMap")
        {
            mainMap = tag.getValue!string("{error}");
        }
    }

    string[] maps;

    import std.file : DirEntry, dirEntries, SpanMode, isDir;
    import std.path : extension;

    foreach (string name; dirEntries(mapsDir, SpanMode.depth))
    {
        if (isDir(name))
            continue;

        if (extension(name) == ".map")
        {
            maps ~= name;
        }
    }

    return MapLoaderInfo(mainMap, maps);
}

import tida;

final class __MapScene : Scene
{
    Map map;

    this() @trusted
    {
        
    }

    void __init(Map map)
    {
        this.map = map;
        spawnInstances(map, this);

        name = map.name;
    }

    @event(Entry) void onEntry() @safe
    {
        renderer.background(map.background.parseColor);
    }
}

auto createScenesFromMaps(MapLoaderInfo info) @trusted
{
    import std.file : read;

    __MapScene[] scenes;

    foreach (string map; info.maps)
    {
        Map mapf = readMap (read (map));

        __MapScene scene = new __MapScene();
        scene.__init (mapf);

        scenes ~= scene;
    }

    return scenes;
}