/++
Модуль описания отдельной персоны в игре.
+/
module rgp.core.characteristic;

import rgp.core.save;

/++
Психические показатели.

Влияют на развитие веток диалога и устойчивости к стрессу во время битв.
+/
struct Nature
{
    /// Тип натуры
    enum Type
    {
        understanding, /// Понимающая
        demurePerson, /// Тихоня
        decisive, /// Решительная
        unbalanced, /// Неуравновешанная
        nasty, /// Злюка
        truth, /// Истинность
        valor, /// Доблесть
        hatred, /// Ненависть
        none /// Несформерованный
    }

public:
    float   attitude = 0.0f, /// Отношение к окружающим.
            resolve = 0.0f, /// Решимость к действиям.
            emotionality = 0.0f, /// Эмоциональность.
            worldview = 0.0f, /// Мировозрение.
            sustainability = 0.0f; /// Устройчивость.

@safe:
    /++
    Выдача типа характера по свойствам
    характера.
    +/
    @property Type natureType()
    {
        if ( // Истинность
            attitude < -0.5f && resolve > 0.5f && worldview < -0.25f && sustainability > 0.5f)
        {
            return Type.truth;
        }
        else if ( // Ненависть
            attitude < -0.2f && resolve > 0.0f && worldview < 0.0f && sustainability > 0.2f)
        {
            return Type.hatred;
        }
        else if ( // Злюка
            attitude < -0.0f && emotionality > 0.5f && worldview < 0.25f && sustainability > 0.2f)
        {
            return Type.nasty;
        }
        else if ( // Псих
            attitude < 0.2f && resolve > 0.5f && emotionality > 0.5f &&
                worldview < -0.1f && sustainability > 0.5f)
        {
            return Type.unbalanced;
        }
        else if ( // Решительная
            resolve > 0.5f && emotionality > 0.2f && sustainability > 0.5f)
        {
            return Type.decisive;
        }
        else if ( // Тихоня
            attitude >= 0.0f && resolve < 0.2f && emotionality < 0.1f && sustainability <= 0.2f)
        {
            return Type.demurePerson;
        }
        else if ( // Понимающая
            attitude > 0.5f && resolve > 0.2f && emotionality > 0.25f &&
                worldview > 0.5f && sustainability > 0.4f)
        {
            return Type.understanding;
        }
        else if ( // Добрость | Доблесть
            attitude > 0.5f && resolve > 0.35f && emotionality > 0.25f &&
                worldview > 0.6f && sustainability > 0.5f)
        {
            return Type.valor;
        }
        else
        {
            return Type.none;
        }
    }

    /++
    Функция выдачи имени характера.
    +/
    @property wstring natureName()
    {
        import rgp.core.locale;

        auto type = natureType();

        switch (type)
        {
        case Type.understanding:
            return locale.get("natureNames.understanding");

        case Type.demurePerson:
            return locale.get("natureNames.demurePerson");

        case Type.decisive:
            return locale.get("natureNames.decisive");

        case Type.unbalanced:
            return locale.get("natureNames.unbalanced");

        case Type.nasty:
            return locale.get("natureNames.nasty");

        case Type.truth:
            return locale.get("natureNames.truth");

        case Type.valor:
            return locale.get("natureNames.valor");

        case Type.hatred:
            return locale.get("natureNames.hatred");

        default:
            return locale.get("natureNames.none");
        }
    }

    Chunk toJSON()
    {
        Chunk object;

        object["attitude"] = Chunk(attitude);
        object["resolve"] = Chunk(resolve);
        object["emotionality"] = Chunk(emotionality);
        object["worldview"] = Chunk(worldview);
        object["sustainability"] = Chunk(sustainability);

        return object;
    }

    void load(Chunk object)
    {
        attitude = object["attitude"].get!float;
        resolve = object["resolve"].get!float;
        emotionality = object["emotionality"].get!float;
        worldview = object["worldview"].get!float;
        sustainability = object["sustainability"].get!float;
    }
}

/++
Физическая статистика персонажа.

Определяет примерные физические показатели.
+/
struct Statistics
{
public:
    float strength = 0.0f, /// Сила.
        dexterity = 0.0f, /// Ловкость.
        mental = 0.0f, /// Интеллект (Ум).
        attack = 0.0f, /// Атака.
        def = 0.0f; /// Защита.

@safe:
    Chunk toJSON()
    {
        Chunk object;

        object["strength"] = Chunk(strength);
        object["dexterity"] = Chunk(dexterity);
        object["mental"] = Chunk(mental);
        object["attack"] = Chunk(attack);
        object["def"] = Chunk(def);

        return object;
    }

    void load(Chunk object)
    {
        strength = object["strength"].get!float;
        dexterity = object["dexterity"].get!float;
        mental = object["mental"].get!float;
        attack = object["attack"].get!float;
        def = object["def"].get!float;
    }
}

/++
Тип предмета (на свойства использования).
+/
enum ItemType
{
    none = 0, /// Обычный объект (Только выкинуть).
    magical, /// Магический объект (Можно использовать и пополнить здоровье).
    edible, /// Съедобный объект (Можно использоватьи и пополнить стамину).
    tagged, /// Важный объект (Нельзя выкинуть).
    custom /// При использовании вызывает функцию. // TODO: Доработать
}

/++
Описание единицы инвентаря - предмет.
+/
struct Item
{
public:
    wstring name; /// Имя объекта.
    ItemType type; /// Тип объекта.
    float value; /// На сколько повысить свойство характеристики при использовании.

@safe:
    Chunk toJSON()
    {
        Chunk object;
        object["name"] = Chunk(name);
        object["type"] = Chunk(cast(ubyte) type);
        object["value"] = Chunk(value);

        return object;
    }

    void load(Chunk object)
    {
        import std.utf : toUTF16;

        name = object["name"].get!string.toUTF16;
        type = cast(ItemType) object["type"].get!ubyte;
        value = object["value"].get!float;
    }
}

/// Функция поиска предмета на наличие
bool hasItem(Item[] items, wstring name) @safe
{
    import std.algorithm : canFind;

    return items.canFind!(e => e.name == name);
}

void removeItem(ref Item[] items, wstring name) @safe
{
    import std.algorithm : remove;

    items = items.remove!(e => e.name == name);
}

/++
Описание персоны.
+/
struct Persona
{
    import tida.color;

public:
    wstring name; /// Имя персонажа.
    string aliasName; /// Имя только в латинице для доступа из кода.

    Statistics statistics; /// Физическая статистика.
    Nature nature; /// Психическая статистика.

    Color!ubyte color; /// Цвет, отражающий характер.

    Item[] inventory; /// Инвентарь (грубо говоря, список предметов).

    float hp = int.init; /// Кол-во жизненной энергии у персонажа.
    int maxHP = int.init; /// Максимальное кол-во жизненной энергии у персонажа.

    float tp = int.init; /// Кол-во магической энергии у персонажа.
    int maxTP = int.init; /// Максимальное кол-во магической энергии у персонажа.

@safe:
    Chunk toJSON()
    {
        import std.algorithm : map;
        import std.range : array;

        Chunk object;
        object["name"] = Chunk(name);
        object["aliasName"] = Chunk(aliasName);
        object["statistics"] = statistics.toJSON();
        object["nature"] = nature.toJSON();
        object["color"] = "#" ~ color.to!string;

        object["hp"] = Chunk(hp);
        object["maxHP"] = Chunk(maxHP);
        object["tp"] = Chunk(tp);
        object["maxTP"] = Chunk(maxTP);

        object["items"] = inventory.map!(a => a.toJSON).array;

        return object;
    }

    void load(Chunk object) @trusted
    {
        import std.utf : toUTF16;

        name = object["name"].get!wstring;
        aliasName = object["aliasName"].get!string;
        statistics.load(object["statistics"]);
        nature.load(object["nature"]);
        color = parseColor(object["color"].get!string);

        hp = object["hp"].get!float;
        maxHP = object["maxHP"].get!int;
        tp = object["tp"].get!float;
        maxTP = object["maxTP"].get!int;

        foreach (item; object["items"].array)
        {
            Item jItem;
            jItem.load(item);

            inventory ~= jItem;
        }
    }
}

static Persona[] persons;

Persona byAlias(string aliasName) @safe
{
    foreach (e; persons)
    {
        if (e.aliasName == aliasName)
            return e;
    }

    throw new Exception("Not find person by alias name!");
}

ref Persona byAliasPtr(string aliasName) @safe
{
    foreach (ref e; persons)
    {
        if (e.aliasName == aliasName)
            return e;
    }

    throw new Exception("Not find person by alias name!");
}
