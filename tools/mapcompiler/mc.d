// Компилятор карт из конфигурации и исходных кодов в бинарный вид.

import sdlang;
import chunk;

import grimoire;
import rgp.core.grlib;

enum ResType : ubyte
{
    image,
    script,
    file,
    link
}

struct ResObject
{
    string name;
    string path;
    void[] data;
    bool embed = false;
    bool link = false;
    ResType type;
    
    void parseTag(Tag tag, string rpath)
    {
        name = tag.name;
        if (name == "link")
        {
            name = tag.getAttribute!string("name", "{error}");
            if (name == "{error}")
            {
                import io = std.stdio;
                import stdc = core.stdc.stdlib;

                io.writeln("\033[1m31mERROR\033[0m: Unknown link resource object: ", tag.location);
                stdc.exit (-1);
            }

            path = tag.getAttribute!string("object", "");
            type = ResType.link;
        } else
        {
            path = tag.getAttribute!string("path", "");
            embed = tag.getAttribute!bool("embed", false);

            string ftype = tag.getAttribute!string("type", "file");

            switch (ftype)
            {
                case "image":
                {
                    type = ResType.image;
                }
                break;

                case "script":
                {
                    type = ResType.script;
                }
                break;

                default:
                {
                    type = ResType.file;
                }
                break;
            }
        }

        if (type == ResType.script)
        {
            if (path != "")
            {
                import std.file : read, exists;
                if (exists(path))
                {
                    GrCompiler compiler = new GrCompiler;
                    compiler.addLibrary(grLoadStdLibrary());
                    compiler.addLibrary(grLoadTidaLibrary());
                    GrBytecode bc = compiler.compileFile(path);
                    if (bc)
                    {
                        data = cast(void[]) bc.serialize ();
                    } else
                    {
                        throw new Exception (compiler.getError().prettify);
                    }
                } else
                {
                    import std.path;

                    if (!isAbsolute(path))
                    {
                        path = rpath ~ "/" ~ baseName(path);
                        if (exists(path))
                        {
                            GrCompiler compiler = new GrCompiler;
                            compiler.addLibrary(grLoadStdLibrary());
                            compiler.addLibrary(grLoadTidaLibrary());
                            GrBytecode bc = compiler.compileFile(path);
                            if (bc)
                            {
                                data = cast(void[]) bc.serialize ();
                            } else
                            {
                                throw new Exception (compiler.getError().prettify);
                            }
                        } else
                        {
                            import std.stdio : writeln;
                            import stdc = core.stdc.stdlib;
                            writeln("ERROR: Not find embed file from \"", path, "\"");
                            stdc.exit (-1);
                        }
                    } else
                    {
                        import std.stdio : writeln;
                        import stdc = core.stdc.stdlib;
                        writeln("ERROR: Not find embed file from \"", path, "\"");
                        stdc.exit (-1);
                    }
                }
            }

            path = "";
            embed = true;
        } else
        if (embed)
        {
            if (path != "")
            {
                import std.file : read, exists;
                if (exists(path))
                {
                    data = read(path);
                } else
                {
                    import std.path;

                    if (!isAbsolute(path))
                    {
                        path = rpath ~ "/" ~ baseName(path);
                        if (exists(path))
                        {
                            data = read(path);
                        } else
                        {
                            import std.stdio : writeln;
                            import stdc = core.stdc.stdlib;
                            writeln("ERROR: Not find embed file from \"", path, "\"");
                            stdc.exit (-1);
                        }
                    } else
                    {
                        import std.stdio : writeln;
                        import stdc = core.stdc.stdlib;
                        writeln("ERROR: Not find embed file from \"", path, "\"");
                        stdc.exit (-1);
                    }
                }

                path = "";
            } else
            {
                data = cast(void[]) tag.getAttribute!string("data", "\0");

                path = "";
            }
        }
    }
    
    Chunk toChunk()
    {
        if (link)
        {
            return Chunk(name, [
                Chunk("link", path)
            ]);
        } else
        {
            return Chunk(name, [
                embed ? Chunk("data", data) : Chunk("path", path),
                Chunk("type", Chunk.Type.Integer8, [type])
            ]);
        }
    }
}

struct MapEvent
{
    string name;
    string script;
    string event;

    void parseTag(Tag tag)
    {
        name = tag.name ();
        script = tag.getAttribute!string("script", "");
        event = tag.getAttribute!string("event", "");
    }

    Chunk toChunk()
    {
        return Chunk(name, [
            Chunk("script", script),
            Chunk("event", event)
        ]);
    }
 }

struct MapObject
{
    string name;
    ResObject[] resources;
    MapEvent[] events;
    
    Chunk[] resourcesChunks()
    {
        Chunk[] chunks;
        foreach (e; resources)
            chunks ~= e.toChunk();
            
        return chunks;
    }

    Chunk[] eventsChunks()
    {
        Chunk[] chunks;
        foreach (e; events)
        {
            chunks ~= e.toChunk();
        }

        return chunks;
    }
    
    Chunk toChunk()
    {
        return Chunk(name, [
            Chunk("resources", resourcesChunks()),
            Chunk("events", eventsChunks())
        ]);
    }
}

struct SkeletUnite
{
    string sprite;
    float[2] position;

    Chunk toChunk()
    {
        return Chunk("unite", [
            Chunk("sprite", sprite),
            Chunk("position", Chunk.Type.Raw, cast(void[]) [position[0], position[1]])
        ]);
    }
}

import tida.shape : ShapeType;

struct MapTouchInfo
{
    string dialog;
    string color;
    MapEvent event;

    Chunk toChunk()
    {
        Chunk[] result =  [
            Chunk("dialog", dialog),
            Chunk("color", color),
            event.toChunk()
        ];

        return Chunk("touchInfo",);
    }
}

struct MapShape
{
    ShapeType type;
    float[2] begin;
    float[2] end;
    float[2][] vertexs;
    MapShape[] shapes;
    float radius;

    void read (Tag tag)
    {
        auto e = tag;

        immutable tp = e.getAttribute!string("type", "{error}");
        if (tp == "{error}")
        {
            import io = std.stdio;
            import cstd = core.stdc.stdlib;
            io.writeln ("\033[1;31mERROR\033[0m: Specified unknown form type in ", e.location);
            cstd.exit (-1);
        }

        switch (tp)
        {
            case "line":
            {
                type = ShapeType.line;

                foreach (Tag r; e.all.tags)
                {
                    if (r.name == "begin")
                    {
                        begin = [
                            r.getAttribute!float("x", 0.0f),
                            r.getAttribute!float("y", 0.0f)
                        ];
                    } else
                    if (r.name == "end")
                    {
                        end = [
                            r.getAttribute!float("x", 0.0f),
                            r.getAttribute!float("y", 0.0f)
                        ];
                    } else
                    {
                        import io = std.stdio;
                        io.writeln ("\033[1;33mWARNING\033[0m: Unknown option in ", r.location);
                    }
                }
            }
            break;

            case "rectangle":
            {
                type = ShapeType.rectangle;

                foreach (Tag r; e.all.tags)
                {
                    if (r.name == "begin")
                    {
                        begin = [
                            r.getAttribute!float("x", 0.0f),
                            r.getAttribute!float("y", 0.0f)
                        ];
                    } else
                    if (r.name == "end")
                    {
                        end = [
                            r.getAttribute!float("x", 0.0f),
                            r.getAttribute!float("y", 0.0f)
                        ];
                    } else
                    {
                        import io = std.stdio;
                        io.writeln ("\033[1;33mWARNING\033[0m: Unknown option in ", r.location);
                    }
                }
            }
            break;
            
            case "multi":
            {
                type = ShapeType.multi;

                foreach (Tag r; e.all.tags)
                {
                    if (r.name == "begin" || r.name == "position")
                    {
                        begin = [
                            r.getAttribute!float("x", 0.0f),
                            r.getAttribute!float("y", 0.0f)
                        ];
                    } else
                    if (r.name == "unite")
                    {
                        MapShape ms;
                        ms.read (r);
                        this.shapes ~= ms;
                    } else
                    {
                        import io = std.stdio;
                        io.writeln ("\033[1;33mWARNING\033[0m: Unknown option in ", r.location);
                    }
                }
            }
            break;

            case "polygon":
            {
                type = ShapeType.polygon;

                foreach (Tag r; e.all.tags)
                {
                    if (r.name == "begin" || r.name == "position")
                    {
                        begin = [
                            r.getAttribute!float("x", 0.0f),
                            r.getAttribute!float("y", 0.0f)
                        ];
                    } else
                    if (r.name == "vertex")
                    {
                        vertexs ~= [
                            r.getAttribute!float("x", 0.0f),
                            r.getAttribute!float("y", 0.0f)
                        ];
                    } else
                    {
                        import io = std.stdio;
                        io.writeln ("\033[1;33mWARNING\033[0m: Unknown option in ", r.location);
                    }
                }
            }
            break;

            case "circle":
            {
                type = ShapeType.circle;

                foreach (Tag r; e.all.tags)
                {
                    if (r.name == "begin" || r.name == "position")
                    {
                        begin = [
                            r.getAttribute!float("x", 0.0f),
                            r.getAttribute!float("y", 0.0f)
                        ];
                    } else
                    if (r.name == "radius")
                    {
                        radius = r.getValue!float(float.nan);
                    } else
                    {
                        import io = std.stdio;
                        io.writeln ("\033[1;33mWARNING\033[0m: Unknown option in ", r.location);
                    }
                }
            }
            break;

            default:
            {
                import io = std.stdio;
                io.writeln ("\033[1;33mWARNING\033[0m: Unknown option in ", e.location);
            }
            break;
        }
    }

    Chunk toChunk()
    {
        switch (type)
        {
            case ShapeType.line:
            {
                return Chunk("le", [
                    Chunk("begin", Chunk.Type.Raw, cast(void[]) begin),
                    Chunk("end", Chunk.Type.Raw, cast(void[]) end)
                ]);
            }

            case ShapeType.rectangle:
            {
                return Chunk("re", [
                    Chunk("begin", Chunk.Type.Raw, cast(void[]) begin),
                    Chunk("end", Chunk.Type.Raw, cast(void[]) end)
                ]);
            }

            case ShapeType.circle:
            {
                return Chunk("ce", [
                    Chunk("begin", Chunk.Type.Raw, cast(void[]) begin),
                    Chunk("radius", radius)
                ]);
            }

            case ShapeType.polygon:
            {
                void[] data;
                foreach (e; vertexs)
                {
                    data ~= cast(void[]) e;
                }

                return Chunk("pn", [
                    Chunk("begin", Chunk.Type.Raw, cast(void[]) begin),
                    Chunk("vertexs", Chunk.Type.Raw, data)
                ]);
            }

            case ShapeType.multi:
            {
                Chunk[] data;
                foreach (shape; shapes)
                {
                    data ~= shape.toChunk();
                }

                return Chunk("mi", [
                    Chunk("begin", Chunk.Type.Raw, cast(void[]) begin),
                    Chunk("shapes", data)
                ]);
            }

            default:
            {
                import io = std.stdio;
                io.writeln ("\033[0;33mWARNING\033[0m: Unknown fucked option!");

                return Chunk("none", 0);
            }
        }
    }
}

struct MapInstance
{
    string object;
    float[2] position = [0.0f, 0.0f];
    string sprite;
    int depth = 0;
    SkeletUnite[] unites;

    string instance;
    Chunk[] args;

    bool solid = false;
    string[] tags;

    MapShape shape;
    MapTouchInfo[] touchInfo;
    
    Chunk toChunk()
    {
        Chunk[] result = [
            Chunk("object", object),
            Chunk("position", Chunk.Type.Raw, cast(void[]) [position[0], position[1]]),
            Chunk("depth", depth),
            Chunk("solid", solid)
        ];

        if (sprite != "")
        {
            result ~= Chunk("sprite", sprite);
        }

        if (instance != "")
        {
            result ~= Chunk("instance", instance);
            result ~= Chunk("args", args);
        }

        if (touchInfo.length != 0)
        {
            foreach (e; touchInfo)
            {
                Chunk[] chunks;
                chunks ~= e.toChunk();
            }
        }

        if (tags.length != 0)
        {
            string stags;
            foreach (e; tags)
            {
                stags ~= e ~ "\0";
            }

            result ~= Chunk("tags", stags);
        }

        if (unites.length != 0)
        {
            Chunk[] cunites;
            foreach (e; unites)
            {
                cunites ~= e.toChunk();
            }

            result ~= Chunk("skelet", cunites);
        }

        if (shape.type != ShapeType.unknown)
        {
            result ~= Chunk("mask", [
                shape.toChunk()
            ]);
        }

        return Chunk("", result);
    }
}

struct MapHeader
{
    ubyte compression;
    ubyte version_;

    void[] data()
    {
        return cast(void[]) [compression, version_];
    }
}

void[] compileMap(Tag root, string rpath)
{
    string name = "UNDEFINED";
    int[2] size = [-1, -1];
    string background = "000000";

    MapHeader header;
    header.compression = cast(ubyte) hasCompress;
    header.version_ = 0x02;
    
    MapObject[] objects;
    Chunk[] objectsTo()
    {
        Chunk[] result;
        foreach (e; objects)
        {
            result ~= e.toChunk();
        }
        
        return result;
    }
    
    MapInstance[] instances;
    Chunk[] instanceTo()
    {
        Chunk[] result;
        foreach (e; instances)
        {
            result ~= e.toChunk();
        }
        
        return result;
    }
    
    static MapObject parseObject(Tag tag, string rpath)
    {
        import io = std.stdio;

        MapObject object;
        object.name = tag.name();
        foreach (e; tag.all.tags)
        {
            switch (e.name)
            {
                case "resources":
                {
                    foreach (Tag e2; e.all.tags)
                    {
                        ResObject ro;
                        ro.parseTag(e2, rpath);
                        
                        object.resources ~= ro;
                    }
                }
                break;

                case "events":
                {
                    foreach (e2; e.all.tags)
                    {
                        MapEvent event;
                        event.parseTag(e2);

                        bool isValid = false;
                        foreach (res; object.resources)
                        {
                            if (res.type == ResType.script)
                            {
                                if (event.script == res.name)
                                {
                                    isValid = true;
                                    break;
                                }
                            }
                        }
                        if (!isValid)
                        {
                            import std.stdio : writeln;
                            import cstd = core.stdc.stdlib;
                            writeln("ERROR: Not find script \"", event.script, "\" in ", e2.location);
                            cstd.exit (-1);
                        }

                        object.events ~= event;
                    }
                }
                break;
                
                default:
                {
                    import std.stdio : writeln;
                    writeln("\033[1;33mWARNING\033[0m: Unknown option: ", e.location);
                }
                break;
            }
        }
        
        return object;
    }
    
    static MapInstance parseInstance(Tag tag)
    {
        import io = std.stdio;
    
        MapInstance instance;
        foreach (Tag e; tag.all.tags)
        {
            switch (e.name)
            {
                case "object":
                {
                    instance.object = e.getValue!string("{error}");
                }
                break;

                case "instance":
                {
                    instance.instance = e.getValue!string("{error}");
                }
                break;

                case "solid":
                {
                    instance.solid = e.getValue!bool(false);
                }
                break;

                case "touchInfo":
                {
                    foreach (ef; e.all.tags)
                    {
                        // MapTouchInfo
                        MapTouchInfo ti;
                        ti.dialog = ef.getAttribute!string("dialog", "");
                        ti.event = MapEvent(
                            // name, script, event
                            "touchEvent",
                            ef.getAttribute("script", "{error}"),
                            ef.getAttribute("event", "{error}")
                        );

                        if (ti.event.event == "{error}")
                        {
                            import io = std.stdio;
                            import cstd = core.stdc.stdlib;

                            io.writeln ("\033[1;31mERROR\033[0m: Event type not specified: ", ef.location);
                            cstd.exit (-1);
                        } else
                        if (ti.event.script == "{error}")
                        {
                            import io = std.stdio;
                            import cstd = core.stdc.stdlib;

                            io.writeln ("\033[1;31mERROR\033[0m: Event type not specified: ", ef.location);
                            cstd.exit (-1);
                        }

                        instance.touchInfo ~= ti;
                    }
                }
                break;

                case "tags":
                {
                    foreach (ef; e.values)
                    {
                        instance.tags ~= ef.get!string;
                    }
                }
                break;

                case "mask":
                {
                    instance.shape.read (e);
                }
                break;

                case "args":
                {
                    foreach (Value j; e.values)
                    {
                        if (j.type == typeid(string))
                        {
                            instance.args ~= Chunk("", j.get!(string));
                        } else
                        if (j.type == typeid(int))
                        {
                            instance.args ~= Chunk("", j.get!(int));
                        } else
                        if (j.type == typeid(float))
                        {
                            instance.args ~= Chunk("", j.get!(float));
                        } else
                        if (j.type == typeid(bool))
                        {
                            instance.args ~= Chunk("", j.get!(bool));
                        }
                    }
                }
                break;
                
                case "position":
                {
                    instance.position = [
                        e.getAttribute!float("x", 0.0f),
                        e.getAttribute!float("y", 0.0f)
                    ];
                }
                break;

                case "depth":
                {
                    instance.depth = e.getValue!int(0);
                }
                break;

                case "sprite":
                {
                    instance.sprite = e.getValue!string("{error}");
                }
                break;

                case "skelet":
                {
                    foreach (ue; e.all.tags)
                    {
                        if (ue.name == "unite")
                        {
                            SkeletUnite unite;
                            unite.sprite = ue.getAttribute!string("resource", "{error}");
                            unite.position = [
                                ue.getAttribute!float("x", 0.0f),
                                ue.getAttribute!float("y", 0.0f)
                            ];

                            instance.unites ~= unite;
                        }
                    }
                }
                break;
            
                default:
                {
                    import std.stdio : writeln;
                    writeln("\033[1;33mWARNING\033[0m: Unknown option: ", e.location);
                }
                break;
            }
        }
        
        return instance;
    }
    
    foreach (e; root.all.tags)
    {
        if (e.name == "name")
        {
            name = e.getValue!(string)("UNDEFINED");
        } else
        if (e.name == "size")
        {
            size = [
                e.getAttribute!int("width", -1),
                e.getAttribute!int("height", -1)
            ];
        } else
        if (e.name == "background")
        {
            background = e.getValue!(string)("000000");
        } else
        if (e.name == "spawn")
        {
            instances ~= parseInstance(e);
        } else
        {
            objects ~= parseObject(e, rpath);
        }
    }

    if (isInputResult)
    {
        import std.stdio : writeln;
        writeln ("Size: ", size);
        writeln ("Name: ", name);
        writeln ("Background: ", background);
        writeln ("Instances: ", instances);
        writeln ("Objects: ", objects);
    }
    
    Chunk chunk = Chunk(
        name, [
            Chunk("size", cast(void[]) size),
            Chunk("background", background),
            Chunk("objects", objectsTo()),
            Chunk("instances", instanceTo())
        ]
    );
    
    void[] rtd = (cast(void[]) ".RGPMAP\n") ~ header.data();
    if (hasCompress) 
    {
        import std.zlib;
        rtd ~= compress(saveChunks([chunk]));
    } else
    {
        rtd ~= saveChunks([chunk]);
    }

    return rtd;
}

static bool isInputResult = false;
static bool hasCompress = true;
static immutable ubyte mcVersion = 0x02;

int main(string[] args)
{   
    import std.file : write;
    import io = std.stdio;
    import std.path;

    if (args.length <= 1)
    {
        io.writeln("ERROR: Many arguments!");
        return -1;
    }

    string[] inputFiles;
    string[] outputFiles;

    bool isInput = true;

    foreach (string arg; args[1 .. $])
    {
        if (arg == "-v" || arg == "--version")
        {
            io.writeln("mc - map compiler - version: ", mcVersion);
            return 0;
        } else
        if (arg == "-h" || arg == "--help")
        {
            io.writeln ("mc [-v | --version] [-h | --help] [-inputResult] [-noCompress] [files...] [-o output files...]");
            return 0;
        } else
        if (arg == "-o")
        {
            isInput = false;
        } else
        if (arg == "-inputResult")
        {
            isInputResult = true;
        } else
        if (arg == "-noCompress")
        {
            io.writeln ("Compilation worked without compression for testing.");
            hasCompress = false;
        } else
        {
            if (isInput)
            {
                inputFiles ~= arg;
            } else
            {
                outputFiles ~= arg;
            }
        }
    }

    foreach (i; 0 .. inputFiles.length)
    {
        if (i >= outputFiles.length)
        {
            outputFiles ~= stripExtension(baseName(inputFiles[i])) ~ ".map";
        }
    }

    foreach (i; 0 .. inputFiles.length)
    {
        auto file = inputFiles[i];

        io.writeln ("Compile configuration \"", file, "\"...");
        Tag root = parseFile(file);

        void[] bindData;
        bindData = compileMap(root, dirName(file));

        scope(failure)
        {
            io.writeln("\033[1;31mERROR:\033[0m: \"", file, "\" is not a compiled!");
        }

        write(outputFiles[i], bindData);
    }

    return 0;
}
