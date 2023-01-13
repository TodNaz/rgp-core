/++
Модуль используемого языка для надписей.
+/
module rgp.core.locale;

/++
Структура для загрузки перевода надписей.
+/
struct LocaleManager(TypeString)
{
    import sdlang;
    import std.utf : toUTF8, toUTF16, toUTF32;

    static if (is(TypeString == string))
        alias decode = toUTF8;
    else static if (is(TypeString == wstring))
        alias decode = toUTF16;
    else static if (is(TypeString == dstring))
        alias decode = toUTF32;

private:
        Tag root;

    string _lclCurrent;
    TypeString _lclName, _lclCode, _lclDesc, _lclBy;
    string _lclFile;

    Tag localeTag;

public:
    /++
    Загрузить файл конфигурации из файла.
    +/
    void loadFromFile(string path) @trusted
    {
        root = parseFile(path);
    }

    /++
    Загрузить данные файлы конфигурации из памяти.
    +/
    void loadFromSource(string source) @trusted
    {
        root = parseSource(source);
    }

    /++
    Прочитает данные из конфигурации и загрузит
    нужный языковой набор.
    +/
    void parseLocale() @trusted
    {
        _lclCurrent = root.getTagValue!string("current");
        Tag strict = root.getTag(_lclCurrent);
        if (strict is null)
            throw new Exception("Failed to load language set `" ~ _lclCurrent ~ "`!");

        _lclName = decode(strict.getTagValue!string("name"));
        _lclCode = decode(strict.getTagValue!string("code"));
        _lclDesc = decode(strict.getTagValue!string("description"));
        _lclFile = strict.getTagValue!string("file");
        _lclBy = decode(strict.getTagValue!string("by"));

        localeTag = parseFile("locales/" ~ _lclFile);
    }

    /++
    Отдаст фразу из массива в языковом наборе.

    Params:
        name = Техническое название фразы
        id = Идентификатор фразы в массиве.
    +/
    deprecated("use instead get(\"phrase.second\")!") TypeString get(string name, size_t id) @trusted
    {
        import std.conv : to;

        auto tag = localeTag.getTag(name);
        if (tag is null)
            throw new Exception(
                    "Failed to load phrase `" ~ name ~ "` with index [" ~
                    id.to!string ~ "] from language set!");

        if (id > tag.values.length)
            throw new Exception(
                    "Failed to load phrase `" ~ name ~ "` with index [" ~
                    id.to!string ~ "] from language set!");

        return decode(tag.values[id].get!string);
    }

    TypeString get(string path) @trusted
    {
        import std.array : split;
        import std.conv : to;

        string[] fullPath = split(path, ".");

        int id = -1;

        if (fullPath[$ - 1][$ - 1] == ']')
        {
            auto e = fullPath[$ - 1];

            for (size_t i = e.length - 1; i > 0; i--)
            {
                if (e[i] == '[')
                {
                    id = e[i + 1 .. $ - 1].to!int;
                    fullPath[$ - 1] = fullPath[$ - 1][0 .. i];
                    break;
                }
            }
        }

        Tag own = localeTag;
        string pathErr;

        foreach (index; 0 .. fullPath.length)
        {
            pathErr ~= index == 0 ? "" : "." ~ own.getFullName.toString;
            own = own.getTag(fullPath[index]);
            if (own is null)
            {
                throw new Exception(
                        "Failed to load phrase `" ~ fullPath[index] ~ "` with `" ~ pathErr ~ "`!");
            }
        }

        if (id != -1)
            if (own.values.length == 0)
                return decode(own.tags[id].values[0].get!string);
            else
                return decode(own.values[id].get!string);
        else
                    return decode(own.values[0].get!string);
    }

    /++
    Отдаст фразу из объекта фраз в языковом наборе.

    Params:
        className = Название групп фраз.
        memberName = Название участника группы фраз.
    +/
    deprecated("use instead get(\"phrase.second\")!") TypeString get(string className,
            string memberName) @trusted
    {
        auto tag = localeTag.getTag(className);
        if (tag is null)
            throw new Exception("Failed to load phrase from group pharases `" ~
                    className ~ "` member `" ~ memberName ~ "` fro language set!");

        auto memberTag = tag.getTag(memberName);
        if (memberTag is null)
            throw new Exception("Failed to load phrase from group pharases `" ~
                    className ~ "` member `" ~ memberName ~ "` fro language set!");

        return decode(memberTag.values[0].get!string);
    }
}

/// Глобальный объект языкового набора для доступа к набору
/// из других функций и методов.
static LocaleManager!wstring locale;

/++
Загрузка файла конфигурации по умолчанию.
+/
void defaultInitializeLocale() @safe
{
    locale.loadFromFile("./locale.sdl");
    locale.parseLocale();
}
