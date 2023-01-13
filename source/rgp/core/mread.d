module rgp.core.mread;

import chunk;

enum ResType : ubyte
{
    image,
    script,
    file
}

struct MapRes
{
    string name;
    string path;
    void[] data;
    ResType type;

    void read(Chunk chunk)
    {
        name = chunk.name;
        foreach (e; chunk.array)
        {
            if (e.name == "path")
            {
                path = e.get!string;
            } else
            if (e.name == "data")
            {
                data = e.data;
            } else
            if (e.name == "type")
            {
                type = cast(ResType) e.get!ubyte;
            }
        }
    }
}

struct MapEvent
{
    string name;
    string script;
    string event;

    void read(Chunk chunk)
    {
        name = chunk.name;
        foreach (e; chunk.array)
        {
            if (e.name == "script")
            {
                script = e.get!string;
            } else
            if (e.name == "event")
            {
                event = e.get!string;
            }
        }
    }
}

struct MapObject
{
    string name;
    MapRes[] resources;
    MapEvent[] events;

    void read(Chunk chunk)
    {
        name = chunk.name;

        foreach (e; chunk.array)
        {
            if (e.name == "resources")
            {
                foreach (ef; e.array)
                {
                    MapRes res;
                    res.read(ef);
                    resources ~= res;
                }
            } else
            if (e.name == "events")
            {
                foreach (ef; e.array)
                {
                    MapEvent ev;
                    ev.read(ef);
                    events ~= ev;
                }
            }
        }

    }
}

struct SkeletUnite
{
    string sprite;
    float[2] position;

    void read (Chunk chunk)
    {
        foreach (e; chunk.array)
        {
            if (e.name == "sprite")
            {
                sprite = e.get!string;
            } else
            if (e.name == "position")
            {
                position = [
                    (cast(float[]) e.data[0 .. float.sizeof])[0],
                    (cast(float[]) e.data[float.sizeof .. float.sizeof * 2])[0]
                ];
            }
        }
    }
}

struct MapTouchInfo
{
    string dialog;
    string color;
    MapEvent event;

    void read(Chunk chunk)
    {
        foreach (e; chunk.array)
        {
            if (e.name == "dialog")
            {
                dialog = e.get!string;
            } else
            if (e.name == "color")
            {
                color = e.get!string;
            } else
            if (e.name == "event")
            {
                event.read (e);
            }
        }
    }
}

struct MapInstance
{
    import std.variant;

    string object;
    float[2] position;
    string sprite;
    int depth = 0;
    SkeletUnite[] skelet;

    string instance;
    Variant[] variant;
    Shapef mask;

    bool solid = false;
    string[] tags;

    MapTouchInfo[] touchInfo;

    void read(Chunk chunk)
    {
        foreach (Chunk e; chunk.array)
        {
            if (e.name == "object")
            {
                object = e.get!string;
            } else
            if (e.name == "position")
            {
                position = [
                    (cast(float[]) e.data[0 .. float.sizeof])[0],
                    (cast(float[]) e.data[float.sizeof .. float.sizeof * 2])[0]
                ];
            } else
            if (e.name == "sprite")
            {
                sprite = e.get!string;
            } else
            if (e.name == "solid")
            {
                solid = e.get!bool;
            } else
            if (e.name == "touchInfo")
            {
                MapTouchInfo ti;
                ti.read (e);

                touchInfo ~= ti;
            } else
            if (e.name == "tags")
            {
                import std.array : split;

                string stags = e.get!string;
                tags = split(stags, '\0');
            } else
            if (e.name == "instance")
            {
                instance = e.get!string;
            } else
            if (e.name == "mask")
            {  
                static Shapef readShape(Chunk chunk)
                {
                    Shapef shape;

                    switch (chunk.name)
                    {
                        case "le":
                        {
                            shape.type = ShapeType.line;
                            foreach (Chunk e; chunk.array)
                            {
                                if (e.name == "begin")
                                {
                                    float[2] bg = [
                                        (cast(float[]) e.data[0 .. float.sizeof])[0],
                                        (cast(float[]) e.data[float.sizeof .. float.sizeof * 2])[0]
                                    ];
                                    shape.begin = vecf(bg);
                                } else
                                if (e.name == "end")
                                {
                                    float[2] ed = [
                                        (cast(float[]) e.data[0 .. float.sizeof])[0],
                                        (cast(float[]) e.data[float.sizeof .. float.sizeof * 2])[0]
                                    ];
                                    shape.end = vecf(ed);
                                }
                            }
                        }
                        break;

                        case "re":
                        {
                            shape.type = ShapeType.rectangle;
                            foreach (Chunk e; chunk.array)
                            {
                                if (e.name == "begin")
                                {
                                    float[2] bg = [
                                        (cast(float[]) e.data[0 .. float.sizeof])[0],
                                        (cast(float[]) e.data[float.sizeof .. float.sizeof * 2])[0]
                                    ];
                                    shape.begin = vecf(bg);
                                } else
                                if (e.name == "end")
                                {
                                    float[2] ed = [
                                        (cast(float[]) e.data[0 .. float.sizeof])[0],
                                        (cast(float[]) e.data[float.sizeof .. float.sizeof * 2])[0]
                                    ];
                                    shape.end = vecf(ed);
                                }
                            }
                        }
                        break;

                        case "ce":
                        {
                            shape.type = ShapeType.circle;
                            foreach (Chunk e; chunk.array)
                            {
                                if (e.name == "begin")
                                {
                                    float[2] bg = [
                                        (cast(float[]) e.data[0 .. float.sizeof])[0],
                                        (cast(float[]) e.data[float.sizeof .. float.sizeof * 2])[0]
                                    ];
                                    shape.begin = vecf(bg);
                                } else
                                if (e.name == "radius")
                                {
                                    shape.radius = e.get!float;
                                }
                            }
                        }
                        break;

                        case "pn":
                        {
                            shape.type = ShapeType.rectangle;
                            foreach (Chunk e; chunk.array)
                            {
                                if (e.name == "begin")
                                {
                                    float[2] bg = [
                                        (cast(float[]) e.data[0 .. float.sizeof])[0],
                                        (cast(float[]) e.data[float.sizeof .. float.sizeof * 2])[0]
                                    ];
                                    shape.begin = vecf(bg);
                                } else
                                if (e.name == "vertexs")
                                {
                                    for (size_t i = 0; i < e.data.length; i += float.sizeof * 2)
                                    {
                                        shape.data ~= vecf(
                                            cast(float[2]) [
                                                (cast(float[]) e.data[0 .. float.sizeof])[0],
                                                (cast(float[]) e.data[float.sizeof .. float.sizeof * 2])[0]
                                            ]
                                        );
                                    }
                                }
                            }
                        }
                        break;

                        case "mi":
                        {
                            shape.type = ShapeType.multi;

                            foreach (Chunk e; chunk.array)
                            {
                                if (e.name == "begin")
                                {
                                    float[2] bg = [
                                        (cast(float[]) e.data[0 .. float.sizeof])[0],
                                        (cast(float[]) e.data[float.sizeof .. float.sizeof * 2])[0]
                                    ];
                                    shape.begin = vecf(bg);
                                } else
                                if (e.name == "shapes")
                                {
                                    foreach (ef; e.array)
                                    {
                                        shape.shapes ~= readShape(ef);
                                    }
                                }
                            }

                            if (isVectorNaN!float(shape.begin))
                            {
                                shape.begin = vecfZero;
                            }
                        }
                        break;

                        default:
                        {
                            import io = std.stdio;
                            io.writeln ("WARNING: UNKNOWN OPTION {", chunk.name, "}");
                        }
                        break;
                    }

                    return shape;
                }

                mask = readShape(e.array[0]);
            } else
            if (e.name == "args")
            {
                foreach (Chunk j; e.array)
                {
                    if (j.type == Chunk.Type.Boolean)
                    {
                        variant ~= Variant(j.get!bool);
                    } else
                    if (j.type == Chunk.Type.Integer32)
                    {
                        variant ~= Variant(j.get!int);
                    } else
                    if (j.type == Chunk.Type.Float)
                    {
                        variant ~= Variant(j.get!float);
                    } else
                    if (j.type == Chunk.Type.String)
                    {
                        variant ~= Variant(j.get!string);
                    }
                }
            } else
            if (e.name == "skelet")
            {
                foreach (ef; e.array)
                {
                    SkeletUnite unit;
                    unit.read(ef);

                    skelet ~= unit;
                }
            } else
            if (e.name == "depth")
            {
                depth = e.get!int;
            }
        }
    }
}

struct Map
{
    string name;
    string background;
    int[2] size;
    MapObject[] objects;
    MapInstance[] instances;
}

Map readMap(void[] data)
{
    import std.zlib;

    immutable char[] signature = ".RGPMAP\n";
    if (cast(char[]) data[0 .. signature.length] != signature)
    {
        throw new Exception("Wrong map signature!"); 
    }
    
    Map map;
    ubyte[2] header = cast(ubyte[2]) data[signature.length .. signature.length + 2];

    Chunk[] chunks;

    if (header[0])
    {
        chunks = parseChunks(
            uncompress(
                data[signature.length + 2 .. $]
            )
        );
    } else
    {
        chunks = parseChunks(
            data[signature.length + 2 .. $]
        );
    }

    map.name = chunks[0].name;
    
    static MapObject[] parseObjects(Chunk[] chunks)
    {
        MapObject[] result;
        foreach (Chunk e; chunks)
        {
            MapObject object;
            object.read (e);

            result ~= object;
        }

        return result;
    }
    
    static MapInstance[] parseInstances(Chunk[] chunks)
    {
        MapInstance[] result;
        foreach (Chunk e; chunks)
        {
            MapInstance instance;
            instance.read (e);

            result ~= instance;
        }

        return result;
    }
    
    foreach (chunk; chunks[0].array)
    {
        switch (chunk.name)
        {
            case "size":
            {
                map.size = [
                    (cast(int[]) chunk.data[0 .. int.sizeof])[0],
                    (cast(int[]) chunk.data[int.sizeof .. int.sizeof * 2])[0]
                ];
            }
            break;
            
            case "background":
            {
                map.background = chunk.get!string;
            }
            break;
            
            case "objects":
            {
                map.objects = parseObjects(chunk.array);
            }
            break;
            
            case "instances":
            {
                map.instances = parseInstances(chunk.array);
            }
            break;
            
            default:
            break;
        }
    }

    return map;
}

import tida;
import grimoire;
import rgp.core.grlib;
import rgp.core.player;
import rgp.core.locale;

final class __WorldObject : Instance, ITouching!wstring
{
    GrEngine engine = new GrEngine;
    GrBytecode bc;

    MapObject object;
    MapInstance instance;

    MapEvent[] onEntry;
    MapEvent[] onStep;
    MapEvent[] onInput;
    MapEvent[] onClose;

    override TouchUnite!wstring[] touchInfo() @trusted
    {
        return [];
    }

    this(string owner, MapObject object, MapInstance instance) @trusted
    {
        this.object = object;
        this.instance = instance;

        this.depth = instance.depth;
        this.mask = instance.mask;

        this.solid = instance.solid;
        this.tags = instance.tags;

        if (instance.object != object.name)
            throw new Exception ("Wrong map object: " ~ instance.object ~ " and " ~ object.name);

        foreach (MapRes e; object.resources)
        {
            if (e.path == "")
            {
                string name = owner ~ "." ~ object.name ~ "." ~ e.name;

                Image image;

                if ((image = loader.get!(Image)(name)) is null)
                {
                    import imagefmt;

                    IFImage a = read_image(cast(ubyte[]) e.data, 4);
                    scope(exit) a.free();

                    image = new Image(a.w, a.h);
                    image.bytes!(PixelFormat.RGBA)(a.buf8);

                    Resource res;
                    res.init!(Image)(image);
                    res.path = name;
                    res.name = name;

                    loader.add(res);

                    image.toTexture();
                }
            } else
            {
                string name = owner ~ "." ~ object.name ~ "." ~ e.name;

                Image image = loader.load!(Image)(e.path, name);
                if (image.texture is null)
                    image.toTexture();
            }
        }

        if (instance.sprite != "")
        {
            sprite.draws = loader.get!Image(owner ~ "." ~ object.name ~ "." ~ instance.sprite);    
        }

        if (instance.skelet.length != 0)
        {
            Sprite[] skelet;
            foreach (SkeletUnite e; instance.skelet)
            {
                Sprite skunit = new Sprite();
                skunit.draws = loader.get!Image(owner ~ "." ~ object.name ~ "." ~ e.sprite);
                skunit.position = vecf(e.position);

                skelet ~= skunit;
            }

            sprite.skelet = skelet;
        }

        position = vecf(instance.position);

        foreach (MapRes e; object.resources)
        {
            if (e.type == ResType.script)
            {
                bc = new GrBytecode;
                bc.deserialize(cast(ubyte[]) e.data);
                engine.addLibrary(grLoadStdLibrary());
                engine.addLibrary(grLoadTidaLibrary());
                engine.load (bc);
                break;
            }
        }

        foreach (MapEvent e; object.events)
        {
            switch (e.name)
            {
                case "init":
                {
                    string mname = grMangleComposite(e.event, [grInt]);
                    if (engine.hasEvent(mname))
                    {
                        GrTask task = engine.callEvent(mname);
                        task.setInt64(cast(long) cast(void*) cast(Instance) this);
                        while (engine.hasTasks)
                            engine.process();
                        if (engine.isPanicking ())
                        {
                            throw new Exception (engine.panicMessage);
                        }
                    } else
                    {
                        throw new Exception ("Undefined script function: " ~ e.event);
                    }
                }
                break;

                case "entry":
                {
                    string mname = grMangleComposite(e.event, []);
                    if (engine.hasEvent(mname))
                    {
                        onEntry ~= e;
                    } else
                    {
                        throw new Exception ("Undefined script function: " ~ e.event);
                    }
                }
                break;

                case "event":
                {
                    string mname = grMangleComposite(e.event, []);
                    if (engine.hasEvent(mname))
                    {
                        onInput ~= e;
                    } else
                    {
                        throw new Exception ("Undefined script function: " ~ e.event);
                    }
                }
                break;

                case "step":
                {
                    string mname = grMangleComposite(e.event, []);
                    if (engine.hasEvent(mname))
                    {
                        onStep ~= e;
                    } else
                    {
                        throw new Exception ("Undefined script function: " ~ e.event);
                    }
                }
                break;

                case "close":
                {
                    string mname = grMangleComposite(e.event, []);
                    if (engine.hasEvent(mname))
                    {
                        onClose ~= e;
                    } else
                    {
                        throw new Exception ("Undefined script function: " ~ e.event);
                    }
                }
                break;

                default:
                break;
            }
        }
    }

    @event(Input) void input(EventHandler event) @trusted
    {
        foreach (MapEvent key; onInput)
        {
            string mname = grMangleComposite(key.event, []);
            GrTask task = engine.callEvent(mname);
            while (engine.hasTasks)
                engine.process();
            if (engine.isPanicking ())
            {
                throw new Exception (engine.panicMessage);
            }
        }
    }

    @event(Entry) void entry() @trusted
    {
        foreach (MapEvent key; onEntry)
        {
            string mname = grMangleComposite(key.event, []);
            GrTask task = engine.callEvent(mname);
            while (engine.hasTasks)
                engine.process();
            if (engine.isPanicking ())
            {
                throw new Exception (engine.panicMessage);
            }
        }
    }

    @event(Step) void step() @trusted
    {
        foreach (MapEvent key; onStep)
        {
            string mname = grMangleComposite(key.event, []);
            GrTask task = engine.callEvent(mname);
            while (engine.hasTasks)
                engine.process();
            if (engine.isPanicking ())
            {
                throw new Exception (engine.panicMessage);
            }
        }
    }

    @event(GameExit) void close() @trusted
    {
        foreach (MapEvent key; onClose)
        {
            string mname = grMangleComposite(key.event, []);
            GrTask task = engine.callEvent(mname);
            while (engine.hasTasks)
                engine.process();
            if (engine.isPanicking ())
            {
                throw new Exception (engine.panicMessage);
            }
        }
    }
}

import std.typecons;
import std.variant;

void rgpSpawn (MapInstance instance, Scene scene) @trusted
{
    switch (instance.instance)
    {
        case "TransitionObject":
        {
            import rgp.core.def;
            auto trans = new TransitionObject(
                vecf(instance.position),
                instance.variant[0].get!string
            );
            scene.add (trans);
        }
        break;

        default:
        break;
    }
}

void spawnInstances(Map map, Scene scene) @trusted
{  
    foreach (e; map.instances)
    {
        MapObject object;
        object.name = "{error}";

        if (e.instance != "")
        {
            rgpSpawn (e, scene);
        } else
        {
            foreach (oe; map.objects)
            {
                if (oe.name == e.object)
                {
                    object = oe;
                    break;
                }
            }
            if (object.name == "{error}")
            {
                throw new Exception ("In map not find object for instance: " ~ e.object);
            }

            __WorldObject iobject = new __WorldObject(map.name, object, e);
            scene.add (iobject);
        }
    }
}
