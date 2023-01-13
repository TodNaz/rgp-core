/++
Модуль для описания сохранений игры.
+/
module rgp.core.save;

import std.bitmanip;

public import chunk;

// Реализация бинарного представления.

/++
Объект сохранения прогресса в игре.
+/
struct SaveManager
{
public:
    Chunk data;

    /++
    Состояние, сообщающее, нужно ли блокировать запись сохранения в файл
    +/
    bool lock = false;

    /+
    Special data:
    "SAVE_TYPE" - 1 байт - определяет тип специальных данных, 0 - релиз, 1 - дебаг
    L дебажные:
        | Строки
        | "PROC_NAME" - длина вплоть до \0
        | "GPU_NAME" - Данные видеокарты
        |  Числа
        | "OS_ID"   -   Идентификатор ОС. 0 - windows, 1 - unix, 2 - android
    L Релизные:
        | "PROC_ID" -   трёхзначное число. 1 байт. Первое число - разрядность.
        |               0 - x86
        |               1 - x64
        |               Остальные два числа - сколько ядер.
        | "OS_ID"   -   Иентификатор ОС. 0 - windows, 1 - unix, 2 - android
    +/

    immutable(ubyte[]) spec = ['.', 'R', 'G', 'P', 'S', 'A', 'V', '\n'];

    void[] saveSpecData()
    {
        import tida : renderer;
        ubyte[] data = spec.dup;

        import core.cpuid;

        debug
        {
            data ~= 1;
            data ~= cast(ubyte[]) (processor() ~ '\0');
            data ~= cast(ubyte[]) (renderer.api.rendererInfo[1] ~ " " ~ renderer.api.rendererInfo[0] ~ '\0');
        } else
        {
            ubyte cpu_id = cast(ubyte) coresPerCPU();
            version(X86)
                cpu_id += 100;

            data ~= 0;
            data ~= cpu_id;
        }

        version (Windows)
            data ~= cast(ubyte) 0;
        else
        version (Posix)
            data ~= cast(ubyte) 1;
        else
        version (Android)
            data ~= cast(ubyte) 2;

        return cast(void[]) data;
    }

    /++
    Загрузить данные сохранения из файла.
    +/
    void load(string path) @trusted
    {
        import io = std.file;
        import rgp.core.characteristic;
        import std.zlib : uncompress;

        ubyte[] rdata = cast(ubyte[]) io.read(path);
        size_t offset = spec.length;
        ubyte dbg = 0;

        if ((dbg = rdata[offset++]) == 1)
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

        data = parseChunkIO(
            dbg == 0 ? uncompress(rdata[offset .. $]) : rdata[offset .. $]
        );

        foreach (e; data["persons"].array)
        {
            Persona persona;
            persona.load(e);

            persons ~= persona;
        }

        foreach (size_t i, ref Chunk e; data.array)
        {
            if (e.name == "persons")
            {
                data.set!(Chunk[]) = data.array[0 .. i] ~ data.array[i + 1 .. $]; 
                break;
            }
        }
    }

    /++
    Сохранить данные сохранения в файл.
    +/
    void saveIn(string path) @trusted
    {
        import std.file : remove;
        import std.stdio : File;
        import std.range : array;
        import rgp.core.characteristic;
        import std.algorithm : map;
        import std.zlib : compress;

        data["persons"] = persons.map!(a => a.toJSON()).array;

        if (!lock)
        {
            File file = File(path, "w");
            debug
            {
                file.rawWrite(saveSpecData ~ (saveChunks(data.array)));
            } else
            {
                file.rawWrite(saveSpecData ~ compress(saveChunks(data.array)));
            }
            file.close();
        }
    }

    /++
    Установить отдельное значение в менеджер сохранений.

    Params:
        name = Имя параметра.
        value = Его значение.
    +/
    void set(T)(string name, T value) @trusted
    {
        import std.array : split;
        import std.conv : to;

        string[] fullPath = split(name, ".");

        size_t index = 0;

        void iterate(ref Chunk object)
        {
            if (index != (fullPath.length - 1))
            {
                if (isExists(object, fullPath[index]))
                {
                    iterate(object[fullPath[index++]]);
                } else
                {
                    object[fullPath[index]] = Chunk.init;
                    iterate(object[fullPath[index++]]);
                }
            } else
            {
                if (isExists(object, fullPath[index]))
                {
                    object[fullPath[index]].set!T(value);
                    object[fullPath[index]].parse!T();
                } else
                {
                    object[fullPath[index]] = Chunk(value);
                }
            }
        }

        iterate(data);
    }

    /++
    Вернёт значение из параметра.

    Params:
        name = Нужный параметр.
    +/
    T get(T)(string name) @safe
    {
        import std.array : split;
        import std.conv : to;
        import std.traits : isFloatingPoint;

        string[] fullPath = split(name, ".");

        string pathErr;
        Chunk own = data;

        foreach (index; 0 .. fullPath.length)
        {
            pathErr ~= index == 0 ? "" : "." ~ fullPath[index];

            if (!isExists(own, fullPath[index]))
            {
                static if (isFloatingPoint!T)
                {
                    return 0.0;
                }else
                {
                    return T.init;
                }
            }

            own = own[fullPath[index]];
        }

        return own.get!T;
    }

    bool isExists(T)(string name) @safe
    {
        import std.array : split;
        import std.conv : to;

        string[] fullPath = split(name, ".");
        int id = -1;

        string pathErr;
        Chunk own = data;

        foreach (index; 0 .. fullPath.length)
        {
            pathErr ~= index == 0 ? "" : "." ~ fullPath[index];

            if (!isExists(own, fullPath[index]))
            {
                return false;
            }

            own = own[fullPath[index]];
        }

        return true;
    }

    bool isExists(T)(T value, string name) @trusted
    if (is (T == Chunk))
    {
        try
        {
            auto vl = value[name];
            return true;
        }
        catch (Throwable e)
        {
            return false;
        }
    }
}

static SaveManager saveManager;
