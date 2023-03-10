import std.bitmanip;

struct Chunk
{
    enum Type : ubyte
    {
        Boolean = 0,
        Integer8 = 1,
        Integer16 = 2,
        Integer32 = 3,
        Integer64 = 4,
        Float = 5,
        String = 6,
        Array = 7,
        Raw = 8
    }

    string name;
    Type type;
    void[] data;

    this(T)(string name, T value) @trusted
    {
        this.name = name;
        this.set!(T)(value);
        this.parse!(T)();
    }

    this(T)(T value) @trusted
    {
        this.set!(T)(value);
        this.parse!(T)();
    }

    this(string name, Type type, void[] data)
    {
        this.name = name;
        this.type = type;
        this.data = data;
    }

    // cache data
    byte _integer8;
    short _integer16;
    int _integer32;
    long _integer64;
    float _float32;
    Chunk[] _array;

    alias array = get!(Chunk[]);

    ref Chunk opIndex(string key) @trusted
    {
        foreach (ref e; array)
        {
            if (e.name == key)
                return e;
        }

        assert(null, "Unknown key: " ~ key ~ "!");
    }

    void opIndexAssign(Chunk chunk, string name) @trusted
    {
        chunk.name = name;
        _array = _array ~ chunk;
        set(_array);
    }

    void opIndexAssign(T)(T value, string name) @trusted
    {
        Chunk chunk = Chunk(value);
        opIndexAssign(chunk, name);
    }

    void set(T)(T value) @trusted
    {
        static if (is(T == bool))
        {
            type = Type.Boolean;
            data = [cast(ubyte) value];
        } else
        static if (is(T == byte) || is(T == ubyte))
        {
            type = Type.Integer8;
            data = [value];
        } else
        static if (is(T == short) || is(T == ushort))
        {
            type = Type.Integer16;
            data = new ubyte[](2);
            write!(T, Endian.bigEndian, ubyte[])(cast(ubyte[]) data, value, 0);
        } else
        static if (is(T == int) || is(T == uint))
        {
            type = Type.Integer32;
            data = new ubyte[](4);
            write!(T, Endian.bigEndian, ubyte[])(cast(ubyte[]) data, value, 0);
        } else
        static if (is(T == long) || is(T == ulong))
        {
            type = Type.Integer64;
            data = new ubyte[](8);
            write!(T, Endian.bigEndian, ubyte[])(cast(ubyte[]) data, value);
        } else
        static if (is(T == float))
        {
            type = Type.Float;
            data = new ubyte[](float.sizeof);
            write!(T, Endian.bigEndian, ubyte[])(cast(ubyte[]) data, value, 0);
        } else
        static if (is(T == string) || is(T == wstring))
        {
            type = Type.String;
            data = cast(void[]) value;
        } else
        static if (is(T == Chunk))
        {
            type = Type.Array;
            data = saveChunks([value]);
        } else
        static if (is(T == Chunk[]))
        {
            type = Type.Array;
            data = saveChunks(value);
        } else
        static if (is(T == void[]))
        {
            type = Type.Raw;
            data = value;
        } else
            static assert(null, "Unknown type!");
    }

    T get(T)() @trusted
    {
        import std.conv : to;

        static if (is(T == bool))
        {
            if (type != Type.Boolean)
                throw new Exception("Is not a boolean!");

            return cast(bool) _integer8;
        } else
        static if (is(T == byte) || is(T == ubyte))
        {
            if (type != Type.Integer8)
                throw new Exception("Is not a Integer8! Is: " ~ type.to!string);

            return cast(T) _integer8;
        } else
        static if (is(T == short) || is(T == ushort))
        {
            if (type != Type.Integer16)
                throw new Exception("Is not a Integer16!");

            return cast(T) _integer16;
        } else
        static if (is(T == int) || is(T == uint))
        {
            if (type != Type.Integer32)
                throw new Exception("Is not a Integer32!");

            return cast(T) _integer32;
        } else
        static if (is(T == long) || is(T == ulong))
        {
            if (type != Type.Integer64)
                throw new Exception("Is not a Integer64!");

            return cast(T) _integer64;
        } else
        static if (is(T == float))
        {
            if (type != Type.Float)
                throw new Exception("Is not a floation point!");

            return _float32;
        } else
        static if (is(T == string) || is(T == wstring))
        {
            if (type != Type.String)
                throw new Exception("Is not a String!");

            return cast(T) data;
        } else
        static if (is(T == Chunk))
        {
            if (type != Type.Array)
                throw new Exception("Is not a Array!");

            return _array[0];
        } else
        static if (is(T == Chunk[]))
        {
            if (type != Type.Array)
                throw new Exception("Is not a Array!");

            return _array;
        } else
        static if (is(T == void[]))
        {
            return data;
        } else
            static assert(null, "Unknown type!");
    }

    void parse(T)() @trusted
    {
        if (data.length == 0)
            return;

        static if (is(T == bool))
        {
            if (type != Type.Boolean)
                throw new Exception("Is not a boolean!");

            _integer8 = cast(byte) (cast(ubyte[]) data)[0];
        } else
        static if (is(T == byte) || is(T == ubyte))
        {
            import std.conv : to;

            if (type != Type.Integer8)
                throw new Exception("Is not a Integer8! It: " ~ type.to!string ~ ":" ~ name);

            _integer8 = cast(byte) (cast(ubyte[]) data)[0];
        } else
        static if (is(T == short) || is(T == ushort))
        {
            if (type != Type.Integer16)
                throw new Exception("Is not a Integer16!");

            ubyte[] cdata = cast(ubyte[]) data;
            _integer16 = cast(short) read!(short, Endian.bigEndian, ubyte[])(cdata);
        } else
        static if (is(T == int) || is(T == uint))
        {
            if (type != Type.Integer32)
                throw new Exception("Is not a Integer32!");

            ubyte[] cdata = cast(ubyte[]) data;
            _integer32 = cast(int) read!(int, Endian.bigEndian, ubyte[])(cdata);
        } else
        static if (is(T == long) || is(T == ulong))
        {
            if (type != Type.Integer64)
                throw new Exception("Is not a Integer64!");

            ubyte[] cdata = cast(ubyte[]) data;
            _integer64 = cast(long) read!(long, Endian.bigEndian, ubyte[])(cdata);
        } else
        static if (is(T == float))
        {
            if (type != Type.Float)
                throw new Exception("Is not a floation point!");

            ubyte[] cdata = cast(ubyte[]) data;
            _float32 = cast(short) read!(float, Endian.bigEndian, ubyte[])(cdata);
        } else
        static if (is(T == string) || is(T == wstring))
        {
            if (type != Type.String)
                throw new Exception("Is not a String!");

            // ...
        } else
        static if (is(T == Chunk))
        {
            if (type != Type.Array)
                throw new Exception("Is not a Array!");

            _array = parseChunks(data)[0];
        } else
        static if (is(T == Chunk[]))
        {
            if (type != Type.Array)
                throw new Exception("Is not a Array!");

            _array = parseChunks(data);
        } else
        static if (is(T == void[]))
        {
            // avoid
        } else
            static assert(null, "Unknown type!");
    }
}

void[] saveChunks(Chunk[] chunks)
{
    ubyte[] result;

    foreach (chunk; chunks)
    {
        ubyte[] data = new ubyte[](int.sizeof);
        write!(int, Endian.bigEndian, ubyte[])(data, cast(int) (chunk.data.length + chunk.name.length), 0);
        data ~= cast(ubyte) chunk.type;
        data ~= cast(ubyte[]) chunk.name ~ '\0';
        data ~= cast(ubyte[]) chunk.data;

        result ~= data;
    }

    return result;
}

/+
???????????????? ?????????????????????????? ??????????:
"LENGTH" = 4 ??????????, ???????????? ???????????? ?????????? (???????????? ?? ????????????)
"TYPE" = 1 ????????, ?????? ???????????? ??????????
    | 0 = ?????????????? ??????
    | 1 = ?????????? ???????????? ????????????
    | 2 = 32 ???????????? ??????????
    | 3 = 64 ???????????? ??????????
    | 4 = ?????????? ?? ?????????????????? ???????????? 32 ???????????? ????????????????
    | 5 = ????????????
    | 6 = ???????????? ????????????
"NAME" = ??????. ?????????? ???????????? ???????? ???? ???????????????? ?????????? '\0'
"DATA" = ????????????. ?????????? ?????????? ?????????????? ???? ?????????? ??????????.
+/
Chunk[] parseChunks(void[] data)
{
    Chunk[] result;
    size_t offset = 0;

    while (offset < data.length)
    {
        ubyte[] clen = cast(ubyte[]) data[offset .. offset += 4];
        size_t length = read!(int, Endian.bigEndian, ubyte[])(clen);
        ubyte type = (cast(ubyte[]) data)[offset++];

        string name;
        while((cast(ubyte[]) data)[offset] != '\0')
        {
            name ~= (cast(ubyte[]) data)[offset++];
        }
        offset++;

        ubyte[] cdata = cast(ubyte[]) data[offset .. offset += (length - name.length)];

        Chunk chunk = Chunk(name, cast(Chunk.Type) type, cdata);

        if (chunk.type == Chunk.Type.Boolean)
        {
            chunk.parse!bool();
        } else
        if (chunk.type == Chunk.Type.Integer8)
        {
            chunk.parse!byte();
        } else
        if (chunk.type == Chunk.Type.Integer16)
        {
            chunk.parse!short();
        } else
        if (chunk.type == Chunk.Type.Integer32)
        {
            chunk.parse!int();
        } else
        if (chunk.type == Chunk.Type.Integer64)
        {
            chunk.parse!long();
        } else
        if (chunk.type == Chunk.Type.Float)
        {
            chunk.parse!float();
        } else
        if (chunk.type == Chunk.Type.Array)
        {
            chunk.parse!(Chunk[]);
        }

        result ~= chunk;
    }

    return result;
}

immutable(ubyte[]) spec = ['.', 'R', 'G', 'P', 'S', 'A', 'V', '\n'];

Chunk parseChunkIO(void[] data)
{
    Chunk chunk = Chunk("", Chunk.Type.Array, data);
    chunk._array = parseChunks(data);

    return chunk;
}

Chunk load(string path) @trusted
{
    import io = std.file;
    import std.zlib : uncompress;

    ubyte[] rdata = cast(ubyte[]) io.read(path);
    size_t offset = spec.length;

    if (rdata[offset++] == 1)
    {
        ubyte cc = 0;

        while (true)
        {
            offset++;
            if (rdata[offset] == '\0')
            {
                cc++;
                if (cc == 2)
                    break;
            }
        }
    }

    offset += 2;

    Chunk data = parseChunkIO(
        uncompress(rdata[offset .. $])
    );

    return data;
}

int main(string[] args)
{
    import std.stdio : writeln;

    if (args.length == 1)
        return -1;
        
    Chunk data = load(args[1]);
    
    string offset(size_t count)
    {
        string __off;

        foreach (_; 0 .. count)
            __off ~= '-';
            
        return __off;
    }
    
    size_t offCount = 0;
    
    void outputData(Chunk chunk)
    {
        writeln(offset(offCount), chunk.name);
        offCount++;
        foreach (e; chunk.array)
        {
            if (e.type == Chunk.Type.Array)
            {
                outputData(e);
            }
            else
            {
                switch (e.type)
                {
                    case Chunk.Type.Boolean:
                        writeln(offset(offCount), e.name, " = ", e._integer8);
                        break;
                    case Chunk.Type.Integer16:
                        writeln(offset(offCount), e.name, " = ", e._integer16);
                        break;
                    case Chunk.Type.Integer32:
                        writeln(offset(offCount), e.name, " = ", e._integer32);
                        break;
                    case Chunk.Type.Integer64:
                        writeln(offset(offCount), e.name, " = ", e._integer64);
                        break;
                    case Chunk.Type.Float:
                        writeln(offset(offCount), e.name, " = ", e._float32);
                        break;
                    case Chunk.Type.String:
                        writeln(offset(offCount), e.name, " = ", e.get!string);
                        break;
                    default:break;
                }
            }
        }
        offCount--;
    }
    
    outputData(data);
    
    return 0;
}
