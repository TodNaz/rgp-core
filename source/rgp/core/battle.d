/++
модуль по управлению процесса боёвки.
+/
module rgp.core.battle;

import tida;
import rgp.core.locale;
import rgp.core.characteristic;
import rgp.core.move : linear;

struct AttackInfo
{
public:
    bool isEnd = false; /// Закончилась ли атака?
    float damageFactor = 0.0f; /// Если да, какой урон? (0.0f - 1.0f)
}

/++
Интерфейс для описани метода атаки
+/
interface IAttackble
{
public:
    /++
    Метод будет вызван при нажатии на
    кнопку использования во время атаки.
    +/
    AttackInfo acceptUse() @safe;

    /++
    Функция для обработки атаки. Вызывается
    при каждом кадре.
    +/
    void handleAttack() @safe;

    /++
    Отрисовка объектов атаки.
    +/
    void drawAttack(IRenderer render) @safe;
}

interface ThreeMask
{
    @property float[2] zRange();

    @property float z();
}

/// Интерфейс для описания кол-во урона у объекта.
interface IDamageable
{
public:
    /// Кол-во урона, которое будет сообщено персонажу.
    @property float damageValue() @safe;
}

interface IZDamageable
{
public:
    @property float damageValue() @safe;

    @property ref float z() @safe;

    @property float[2] zmask() @safe;
}

/++
Функция проигрыша по умолчанию в битве.
+/
void defaultGameOver() @safe
{
    import rgp.core.save;

    // Блокируем сохранение, чтобы не записать данные с проигрышем.
    saveManager.lock = true;

    version (feature_gameOverEqRestart)
    {
        sceneManager.gameRestart();
    }
    else
    {
        sceneManager.close(0);
    }
}

mixin template zzImpl()
{
    @event(Draw) void __zDrawLine(IRenderer render) @safe
    {
        if (mask.type != ShapeType.line)
        {
            immutable size = mask.calculateSize();
            render.rectangle(
                position + mask.begin + vecf(0, mask.end.y / 2) + vecf(0, z),
                cast(uint) size.x, cast(uint) size.y / 2,
                rgba(30, 30, 30, cast(ubyte) ((1.0f - (_z / 32.0f)) * ubyte.max)),
                true
            );
        } else
        {
            render.line(
                [
                    position + mask.begin + vecf(0, z),
                    position + mask.end * vecf(1, 0.5) + vecf(0, z)
                ],
                rgba(30, 30, 30, cast(ubyte) ((1.0f - (_z / 32.0f)) * ubyte.max))
            );
        }
    }
}

final class ThreeController : Controller
{
    Soul soul;

    this(Soul soul) @safe
    {
        this.soul = soul;
    }

    @event(Step) void threeInput() @safe
    {
        foreach (instance; sceneManager.context.list)
        {
            import std.algorithm : canFind;
            import tida.collision;

            if (!soul.active)
                return;

            foreach (e; sceneManager.context.list)
            {
                if (e.tags.canFind("zdamageable"))
                {
                    IZDamageable dg = cast(IZDamageable) e;

                    if (lineLineImpl(
                            [vecf(0, soul.z), vecf(0, soul.z + 4)],
                            [vecf(0, dg.z + dg.zmask[0]), vecf(0, dg.z + dg.zmask[1])]
                        ))
                    {
                        if (isCollide(
                                soul.mask,
                                e.mask,
                                soul.position + vecf(0, soul.z),
                                e   .position + vecf(0, dg.z)
                            ))
                        {
                            immutable factor = 1.0f - (soul.personaPtr.persona.statistics.def / 100);
                            immutable damage = dg.damageValue * factor;

                            soul.personaPtr.persona.hp -= damage * (factor +  soul.personaPtr.isDefence ? factor / 0.75 : 1.0);
                            //soul.personaPtr.persona.hp -= dg.damageValue();
                        }
                    }
                } else
                    continue;
            }
        }
    }
}

/++
Объект, который будет передовать урон
персонажу, который учавствует в бою.
+/
final class Soul : Instance
{
    import tida.graphics.gapi;

private:
    tida.Image soulImage;
    Vector!float velocity = vecZero!float;

public:
    float speed = 3.0f; /++ Скорость движения души.
                            Должен быть равен ловкости персонажа
                            делённом на десять. +/

    float pickTime = 0.0f;

    @asset("sounds/jump.wav")
    Sound jump;

    Battle.PersonaBattle* personaPtr = null; /// Персонаж, который навешан на бой.
    IShaderProgram soulShader; /// Используемый шейдер для души.

    bool threeDim = false;
    float z = 0.0f;
    float maxJump = 32.0f;

    void toThreeMode() @safe
    {
        threeDim = true;
        mask = Shapef.Rectangle(vecf(0, 10), vecf(16, 16));
    }

    void toSeeMode() @safe
    {
        threeDim = false;
        mask = Shapef.Rectangle(vecfZero, vecf(16, 16));
    }

    Sprite spritePtr;

    this() @trusted
    {
        import tida.graphics.gapi;

        spritePtr = new Sprite();

        soulImage = loader.load!(tida.Image)("textures/soul.png");
        if (soulImage.texture is null)
            soulImage.toTexture();

        spritePtr.draws = soulImage;
        spritePtr.color = rgb(255, 255, 255);

        soulShader = renderer.getShader("SoulShader");
        if (soulShader is null)
        {
            import std.file : readText;

            soulShader = renderer.api.createShaderProgram();
            IShaderManip vert, frag;
            vert = renderer.api.createShader(StageType.vertex);
            vert.loadFromSource("shaders/soul.vert".readText);
            frag = renderer.api.createShader(StageType.fragment);
            frag.loadFromSource("shaders/soul.frag".readText);
            soulShader.attach(vert);
            soulShader.attach(frag);
            soulShader.link();
            renderer.setShader("SoulShader", soulShader);
        }
        //spritePtr.shader = soulShader;

        mask = Shape!float.Rectangle(vecZero!float, vec!float(16, 16));
        solid = true;
        tags = ["soul"];

        active = false;

        depth = 10;
    }

    @event(Draw) void threeDraw(IRenderer render) @safe
    {
        if (threeDim)
        {
            render.rectangle(
                position + vecf(0, 8), 
                16, 10, 
                rgba(30, 30, 30, cast(ubyte) (ubyte.max * (1.0f - (z / (maxJump * 4.0f))))),
                true
            );
        }

        render.draw(spritePtr, position + vecf(0, -z));
    }

    /// Ввод персонажа как цель атаки.
    void targetWith(ref Battle.PersonaBattle persona) @trusted
    {
        import std.algorithm : canFind;

        personaPtr = &persona;
        spritePtr.color = persona.color;

        if (persona.condition == Battle.ConditionType.fine)
            speed = 3.0f;
        else if (persona.condition == Battle.ConditionType.fatique)
            speed = 2.0f;
        else if (persona.condition == Battle.ConditionType.excited)
            speed = 3.75f;

        if (persona.baffs.canFind!(a => a == "picking"))
        {
            tida.Image soulPick = loader.load!(tida.Image)("textures/soulPicking.png");
            if (soulPick.texture is null)
                soulPick.toTexture();

            spritePtr.draws = soulPick;
        }

        if (persona.baffs.canFind!(a => a == "fire"))
        {
            tida.Image soulPick = loader.load!(tida.Image)("textures/soulFire.png");
            if (soulPick.texture is null)
                soulPick.toTexture();

            spritePtr.draws = soulPick;
            spritePtr.matrix = translation(0, -16, 0);
        }
    }

    bool isJump = false;
    bool jrelease = true;
    Vecf jvel = vecfZero;
    float jfactor = 0.0f;
    bool lockJump = false; // public

    @event(Step) void jumpHandle() @safe
    {
        import tida.animobj;

        if (isJump)
        {
            jvel.y -= 0.5f;

            z += jvel.y;
            if (z <= 0.0f)
            {
                z = 0.0f;
                isJump = false;
                jvel.y = 0.0f;
            }
        }
    }

    bool jumpClick = false;

    @event(Input) void inputMove(EventHandler event) @safe
    {
        import rgp.core.setting;

        if (keySetting.cancel.isDown(event) && threeDim && !isJump && jrelease && !lockJump)
        {
            isJump = true;
            jfactor = 0.0f;
            jvel.y = maxJump / 3.0f;
            jump.play();
            jumpClick = true;
            jrelease = false;
        }

        if (keySetting.cancel.isUp(event))
        {
            if (isJump && jumpClick)
            {
                jumpClick = false;
                jvel.y = maxJump / 16.0f;
            }

            jrelease = true;
        }

        if (keySetting.right.isDown(event))
        {
            velocity.x = speed;
        }

        if (keySetting.right.isUp(event))
        {
            if (velocity.x > 0)
            {
                velocity.x = 0;
            }
        }

        if (keySetting.left.isDown(event))
        {
            velocity.x = -speed;
        }

        if (keySetting.left.isUp(event))
        {
            if (velocity.x < 0)
            {
                velocity.x = 0;
            }
        }

        if (keySetting.up.isDown(event))
        {
            velocity.y = -speed;
        }

        if (keySetting.up.isUp(event))
        {
            if (velocity.y < 0)
            {
                velocity.y = 0.0f;
            }
        }

        if (keySetting.down.isDown(event))
        {
            velocity.y = speed;
        }

        if (keySetting.down.isUp(event))
        {
            if (velocity.y > 0)
            {
                velocity.y = 0;
            }
        }
    }

    bool findPol = false;

    @event(Step) void handleMove() @safe
    {
        import tida.collision;
        import std.algorithm : canFind;

        previous = position;

        if (velocity != vecZero!float)
        {
            pickTime = 0.0f;

            Vector!float tempPos = position + velocity;

            foreach (other; sceneManager.current.list)
            {
                if (other !is null && other.solid && 
                    other.tags.canFind!(a => a == "solidWithSoul"))
                {
                    if (isCollide(mask, other.mask, tempPos, other.position))
                    {
                        jvel.y = 0;

                        if (velocity.x != 0.0f)
                        {
                            tempPos = position + vec!float(velocity.x, 0);
                            if (isCollide(mask, other.mask, tempPos, other.position))
                            {
                                velocity.x = 0.0f;
                            }
                        }

                        if (velocity.y != 0.0f)
                        {
                            tempPos = position + vec!float(0, velocity.y);
                            if (isCollide(mask, other.mask, tempPos, other.position))
                            {
                                velocity.y = 0.0f;
                            }
                        }
                    }
                }
            }
        }
        else
        {
            import std.algorithm : canFind;

            if (personaPtr.baffs.canFind!(a => a == "picking"))
            {
                if (pickTime > 1)
                    personaPtr.persona.hp -= 0.01f;
                else
                    pickTime += 0.1f;
            }
        }

        position += velocity;
    }

    @Collision("", "damageable") void onDamage(tida.Instance other) @safe
    {
        IDamageable damageObject = cast(IDamageable) other;
        if (damageObject is null)
            throw new Exception(
                    "[Battle:Soul:onDamage] object `" ~ other.name ~ "` is not a damageable object!");

        immutable factor = 1.0f - (personaPtr.persona.statistics.def / 100);
        immutable damage = damageObject.damageValue * factor;

        personaPtr.persona.hp -= damage * (factor + personaPtr.isDefence ? factor / 0.75 : 1.0);
    }

    @Collision("", "fireable") void onFireObject(Instance othe) @safe
    {
        import std.algorithm : canFind;

        if (!personaPtr.baffs.canFind!(a => a == "fire"))
        {
            personaPtr.baffs ~= "fire";

            tida.Image soulPick = loader.load!(tida.Image)("textures/soulFire.png");
            if (soulPick.texture is null)
                soulPick.toTexture();

            sprite.draws = soulPick;
            sprite.matrix = translation(0, -16, 0);

            void fire() @safe
            {
                personaPtr.persona.hp -= 0.5f;

                if (personaPtr.baffs.canFind!(a => a == "fire") &&
                    personaPtr.persona.hp > 2.0f)
                    listener.timer(&fire, seconds(1));
            }

            fire();
        }
    }
}

/// Объект барьера, который будет ограничивать ход
/// души в плоскости.
final class Barier : Instance
{
private:
    uint[2] _size = [156, 156];

    float __smoothFactor = float.nan;
    uint[2] _toSize;
    uint[2] _prevSize;

public:
    Color!ubyte borderColor = parseColor("8b6e57"); /// Цвет боковин поля.
    Color!ubyte backgroundColor = parseColor("d5b59c80"); /// Цвет заднего фона поля.

    bool threeDim = false;

    void toThreeMode() @safe
    {
        threeDim = true;
        mask = Shapef.RectangleLine(vecfZero, vecf(_size[0], _size[1] / 2));
    }

    void toSeeMode() @safe
    {
        threeDim = false;
        mask = Shape!float.RectangleLine(vecZero!float, vec!float(_size));
    }

    this() @safe
    {
        name = "barier";

        solid = true;
        mask = Shape!float.RectangleLine(vecZero!float, vec!float(_size));
        tags = ["solidWithSoul"];

        position = renderer.camera.port.begin + vec!float(320, 240) - (vec!float(_size) / 2);
        active = false;

        depth = 15;
    }

    uint[2] size() @safe
    {
        return _size;
    }

    /// Функция изменения размера поля.
    /// Params:
    ///     width = Ширина поля.
    ///     height = Высота поля.
    void resize(uint width, uint height) @safe
    {
        _size = [width, height];

        if (threeDim)
            mask = Shapef.RectangleLine(vecfZero, vecf(_size[0], _size[1] / 2));
        else
            mask = Shape!float.RectangleLine(vecZero!float, vec!float(_size));

        position = vec!float(320, 240) - (vec!float(_size) / 2);
    }

    void smoothResize(uint width, uint height) @safe
    {
        _toSize = [width, height];
        _prevSize = _size;
        __smoothFactor = 0.0f;

        mask = Shapef.RectangleLine(vecZero!float, vec!float(_toSize));
    }

    @event(Step) void smoothEdit() @safe
    {
        import std.math : isNaN;
        import tida.animobj;

        if (__smoothFactor.isNaN)
            return;

        float dfactor = 0.0f;

        __smoothFactor += 0.01f;

        if (__smoothFactor >= 1.0f)
        {
            __smoothFactor = float.nan;
            return;
        }

        easeOutSine(dfactor, __smoothFactor);

        int[2] verl = [
            cast(int) _toSize[0] - _prevSize[0], cast(int) _toSize[1] - _prevSize[1]
        ];

        _size = [
            cast(uint)(cast(int) _prevSize[0] + cast(int) verl[0] * dfactor),
            cast(uint)(cast(int) _prevSize[1] + cast(int) verl[1] * dfactor)
        ];

        position = vec!float(320, 240) - ((vec!float(_prevSize) + vec!float(verl)) / 2) * dfactor;
    }

    @event(Draw) void drawSelf(IRenderer render) @safe
    {
        //mat4 model = identity();
        //
        //if (threeDim)
        //{
        //    immutable center = position + vecf(size) / 2;
        //    immutable angle = rightAngle!Radians / 64.0f;
        //
        //    model = model
        //        .translate(-center.x, -center.y, 0f)
        //        .rotateMat(-angle, 1f, 0f, 0f)
        //        .translate(center.x, center.y /+ - _size[1] / 4.0f +/, 0f);
        //}
        //
        //render.currentModelMatrix = model;
        //render.rectangle(position, _size[0], _size[1], backgroundColor, true);
        //
        //render.currentModelMatrix = model;
        //render.rectangle(position, _size[0], _size[1], borderColor, false);

        if (threeDim)
        {
            render.rectangle(
                position,
                _size[0], _size[1] / 2,
                rgb(backgroundColor.r, backgroundColor.g, backgroundColor.b),
                true
            );
            render.rectangle(position, _size[0], _size[1] / 2, borderColor, false);
        } else
        {
            render.rectangle(position, _size[0], _size[1], backgroundColor, true);
            render.rectangle(position, _size[0], _size[1], borderColor, false);
        }
    }

    //mixin debugCollisionMask!(rgb(255, 0, 0));
}

/++
Минимальный эффект удара.
+/
final class DefaultHit : Instance
{
private:
    Image hitImage, flipHitImage;
    float[2] factorAlpha = [0.0f, 0.0f];

public:
    this(float y) @safe
    {
        hitImage = loader.load!Image("textures/hit.png");

        if (hitImage.texture is null)
        {
            hitImage.toTexture();
            flipHitImage = hitImage.flipX;
            flipHitImage.toTexture();

            Resource resource;
            resource.init!Image(flipHitImage);
            resource.path = "rgp.core.battle.DefaultHit.hitFlip";
            resource.name = resource.path;

            loader.add(resource);
        }
        else
        {
            flipHitImage = loader.get!Image("rgp.core.battle.DefaultHit.hitFlip");
        }

        position = vec!float(128 + 32, y - 27);
    }

    @event(Step) void handleStep() @safe
    {
        import tida.animobj : easeOut;

        factorAlpha[0] += 0.05f;

        if (factorAlpha[0] > 1.0f)
        {
            destroy();
            return;
        }

        easeOut!2(factorAlpha[1], factorAlpha[0]);
    }

    @event(Draw) void drawHits(IRenderer render) @safe
    {
        immutable fposition = render.camera.port.begin + position - vec!float(
                (1.0f - factorAlpha[1]) * 128, 0);

        render.drawEx(hitImage, fposition, 0.0f, vecNaN!float, vecNaN!float,
                cast(ubyte)(ubyte.max * (1 - factorAlpha[1])));
    }
}

/// Атака по умолчанию будет прописана тем,
/// у кого нет метод атак.
final class DefaultAttack(alias fun = linear) : IAttackble
{
    import std.random : uniform;

private:
    float[2] factors = [0.0f, 0.0f];
    ubyte dir = 0;
    float[2] criticalRange = [0.3f, 0.5];

    Sound hit;
    Sound hitWait;

    Image str;

public:
    this() @safe
    {
        randomize();

        hit = loader.load!Sound("sounds/hit.wav");
        hitWait = loader.load!Sound("sounds/hitWait.wav");
        hitWait.loop = true;

        str = loader.load!Image("textures/hitStr.png");
        if (str.texture is null)
            str.toTexture();
    }

    /// Случайный разброс критического диапазона попаданий
    void randomize() @safe
    {
        immutable first = uniform(0.0f, 0.075);

        criticalRange = [first, uniform(first, first + 0.25)];
    }

override:
    AttackInfo acceptUse() @safe
    {
        immutable size = (480 - 128);
        immutable yPosition = 64 + size * factors[1];

        hit.play();
        hitWait.stop();

        if (factors[1] > criticalRange[0] && factors[1] < criticalRange[1])
        {
            randomize();
            sceneManager.context.add(new DefaultHit(yPosition));
            return AttackInfo(true, 0.5f + uniform(0.25f, 0.5f));
        }
        else
        {
            randomize();
            sceneManager.context.add(new DefaultHit(yPosition));
            return AttackInfo(true, uniform(0.0f, 0.5f));
        }
    }

    void handleAttack() @safe
    {
        if (!hitWait.isPlay)
            hitWait.play();

        if (dir == 0)
        {
            if (factors[0] > 1.0f)
            {
                dir = 1;
                return;
            }

            factors[0] += 0.01f;
        }
        else
        {
            if (factors[0] < 0.0f)
            {
                dir = 0;
                return;
            }

            factors[0] -= 0.01f;
        }

        fun(factors[1], factors[0]);
        hitWait.pitch = 1.0f + (0.5f * factors[1]);
    }

    void drawAttack(IRenderer render) @safe
    {
        immutable goffset = render.camera.port.begin;
        immutable size = (480 - 128);

        render.line([
            goffset + vec!float(16, 64), goffset + vec!float(16, 480 - 64)
        ], rgb(255, 0, 0));

        render.draw(str, goffset + vec!float(0, 64 + size * factors[1] - 8));

        render.line([
            goffset + vec!float(14, 64 + size * factors[1]),
            goffset + vec!float(18, 64 + size * factors[1])
        ], rgb(255, 0, 0));

        render.line([
            goffset + vec!float(20, 64 + size * criticalRange[0]),
            goffset + vec!float(20, 64 + size * criticalRange[1])
        ], rgba(255, 64, 64, 128));
    }
}

/++
Информация о противнике.
+/
struct Target
{
    /++
    Информация о персонаже.
    +/
    Persona info;

    /++
    Функция, что будет вызвана, если
    данному противнику будет передан
    ход.

    Нужна для атаки персонажей.
    +/
    void delegate() @safe onSelect;

    /++
    Функция, что будет вызвана при убийстве
    противника или при его победы (в зависимости
    от того, какие намерения в битве)
    +/
    void delegate() @safe onDie;

    /++
    Функция, что будет вызвана, если
    противник потеряет свой ход.
    +/
    void delegate() @safe endSelect;
}

/++
Комбинация макросов.
+/
struct MacroCombination
{
    // Какие люди должны быть в комбинации, чтобы
    // произвести спец. заклинание.
    string[] aliases;

    /// Метод интерактива
    IAttackble attack;

    /// Получаемый урон
    float uron;
}

/++
Объект для организации битвы.
+/
final class Battle : Instance
{
    import std.typecons : Nullable;
    import rgp.core.dialog;
    import std.functional : toDelegate;

    alias PersonaPtr = Persona*;

    /// Состояние персонажа
    enum ConditionType
    {
        fatique, /// Утомление
        fine, /// Нормальное
        excited, /// Возбуждённое (гиперактивное)
        died // Вырублен
    }

    /// Тип выбора, назначенный для персонажа.
    enum SelectionType
    {
        none, /// Никакой
        attack, /// Атакует
        defence, /// Защищается
        inventory, /// Смотрив в инвентарь
        talk, /// Разговаривает
        magic /// Колдует
    } // SelectionType.max + n = сторонние действия.

    /// Описание персоны во время битвы
    struct PersonaBattle
    {
        alias persona this;

    public:
        /// Указатель на информацию о персонаже
        PersonaPtr persona;

        /// Показатель усталости
        ConditionType condition = ConditionType.fine;

        /// Что он выбрал
        SelectionType select = SelectionType.none;

        /// Какой у него метод атаки
        IAttackble attackMethod;

        /// Какие действия может совершить персонаж.
        ChoiceUnite!wstring[] choices;

        /// Есть-ли доп. защита?
        bool isDefence = false;

        /// Какие эффекты наложены
        string[] baffs;

        /// Названия его показателя усталости
        auto conditionName() @safe
        {
            switch (condition)
            {
            case ConditionType.fatique:
                return locale.get("conditionType.fatique");

            case ConditionType.fine:
                return locale.get("conditionType.fine");

            case ConditionType.excited:
                return locale.get("conditionType.excited");

            default:
                throw new Exception("[Battle] Unknown condition!");
            }
        }
    }

    /// Параметр шаблона
    struct TemplateParametrs
    {
        size_t person; /// Персонаж
        SelectionType selection; /// Что он делает
        size_t value; /// Как он это делает.
    }

private:
    Image[string] icons;
    Image cursor;

    Sound conSound, selSound;

    PersonaBattle[] battlePersons;
    size_t personIndex = 0;

    size_t miniIndex = 0;
    size_t teamTurnIndex = 0;
    bool isTeamTurn = true;

    bool isSelectMode = false;
    size_t selectIndex = 0;

    bool isTemplateMode = false;
    size_t templateIndex = 0;
    bool isTemplateEdit = false;

    size_t templateUseIndex = 0;
    bool isTemplateUse = false;

    // [asiasName][macrosIdentifiactor]
    // TODO-cBattle-p2: implement save macroses
    TemplateParametrs[string][7] macroses;

    float[2] _factorPanelMiniSelect = [0.0f, 0.0f];
    float[2] _factorPanelSelect = [0.0f, 0.0f];
    float[2] _factorPanelTemplate = [0.0f, 0.0f];

    IAttackble currentAttack = null;
    bool isAttackMethod = false;

    float[2] _methodAlphaFactor = [1.0f, 1.0f];

    size_t targetIndex = 0;
    long targetWithId = -1;

    bool isUronView = false;
    float viewUron;
    float viewUronFactor;

    bool isOppDefeat = false;

    float panelFactor = 0.0f;

    bool isMacrosAttack = false;
    size_t combIndex = 0;

public:
    /// Список противников.
    Target[] targets;

    /// Комбинации макросов.
    MacroCombination[] combinations;

    /++
    Функция, что будет вызвана при убийстве или
    победой над всеми соперниками в битве.
    +/
    void delegate() @safe onWinBattle;

    /++
    Функция, что будет вызвана при выборе того, кто
    будет получать урон. Нужен, например, чтобы намеренно
    кого-то выбрать для урона.
    +/
    void delegate(ref long) @safe onTargetChoice;

    /++
    Функция, что будет вызвана при атаке персонажа.

    Первый аргумент = Идентификатор персонажа.
    +/
    void delegate(immutable size_t) @safe onAttack;

    /++
    Функция, что будет вызвана при смерти всех персонажей.
    +/
    void delegate() @safe onDieAll;

    /++
    Функция, что будет вызвана, если все противники завершили свой ход
    +/
    void delegate() @safe onTargetsRelease;

    void delegate() @safe onEscape;

    bool isTargetAttack() @safe @property
    {
        return isTeamTurn == false;
    }

    immutable(size_t) currentTarget() @safe @property
    {
        return targetIndex;
    }

    immutable(size_t) selectedTarget() @safe @property
    {
        return targetWithId;
    }

    Persona* selectetTargetPersona() @safe @property
    {
        return battlePersons[targetWithId].persona;
    }

    ref PersonaBattle[] bs() @safe { return battlePersons; }

    /++
    Функция вписывания персонажей, которые будут участвовать
    в битве.

    Params:
        persona      =  Указатель на персонажа, который будет
                        принимать участие в битве.
        attackMethod =  Метод атаки противника.
    +/
    void append(PersonaPtr persona, IAttackble attackMethod, ConditionType cond = ConditionType.fine) @safe
    {
        auto pers = PersonaBattle(persona);
        pers.condition = cond;

        if (attackMethod is null)
        {
            pers.attackMethod = new DefaultAttack!(linear)();
        }
        else
        {
            pers.attackMethod = attackMethod;
        }

        battlePersons ~= pers;
    }

    /// ditto
    void append(ref Persona persona, IAttackble attackMethod, ConditionType cond = ConditionType.fine) @trusted
    {
        append(&persona, attackMethod, cond);
    }

    /// Присовит акт разговора для персонажа.
    void bindActWith(in string aliasName, ChoiceUnite!wstring choice) @safe
    {
        byAliasName(aliasName).choices ~= choice;
    }

    ref auto getActs(in string aliasName) @safe
    {
        return byAliasName(aliasName).choices;
    }

    //ref auto getPersona(in string aliasName);

    this() @safe
    {
        icons["attack"] = loader.load!Image("textures/iconAttack.png");
        if (icons["attack"].texture is null)
            icons["attack"].toTexture();

        icons["inventory"] = loader.load!Image("textures/iconInventory.png");
        if (icons["inventory"].texture is null)
            icons["inventory"].toTexture();

        icons["shield"] = loader.load!Image("textures/iconShield.png");
        if (icons["shield"].texture is null)
            icons["shield"].toTexture();

        icons["magic"] = loader.load!Image("textures/iconMagic.png");
        if (icons["magic"].texture is null)
            icons["magic"].toTexture();

        icons["talk"] = loader.load!Image("textures/iconTalk.png");
        if (icons["talk"].texture is null)
            icons["talk"].toTexture();

        icons["none"] = loader.load!Image("textures/iconNone.png");
        if (icons["none"].texture is null)
            icons["none"].toTexture();

        cursor = loader.load!Image("textures/cursor.png");
        if (cursor.texture is null)
            cursor.toTexture();

        conSound = loader.load!Sound("sounds/control.wav");
        selSound = loader.load!Sound("sounds/select.wav");

        () @trusted { onDieAll = toDelegate(&defaultGameOver); }();
    }

    /// Получение персонажа по его синонемическому имени
    /// Params:
    ///     aliasName = Синонемитечское имя.
    /// Throws: `AssertError` если не нашлось.
    ref auto byAliasName(in string aliasName) @safe
    {
        foreach (ref e; battlePersons)
        {
            if (e.persona.aliasName == aliasName)
                return e;
        }

        assert(null, "[Battle.byAliasName] Not a find persona!");
    }

    /// Получение индекса персонажа по его синонемическому имени
    /// Params:
    ///     aliasName = Синонемитечское имя.
    /// Throws: `AssertError` если не нашлось.
    auto indexByAliasName(in string aliasName) @safe
    {
        foreach (i; 0 .. battlePersons.length)
        {
            if (battlePersons[i].persona.aliasName == aliasName)
                return i;
        }

        assert(null, "[Battle.byAliasName] Not a find persona!");
    }

    /// Получение иконки по типу выбора
    Image iconFrom(SelectionType select) @safe
    {
        switch (select)
        {
        case SelectionType.attack:
            return icons["attack"];

        case SelectionType.defence:
            return icons["shield"];

        case SelectionType.inventory:
            return icons["inventory"];

        case SelectionType.magic:
            return icons["magic"];

        case SelectionType.talk:
            return icons["talk"];

        case SelectionType.none:
            return icons["none"];

        default:
            throw new Exception("[Battle] Unknown select!"); // TODO-cBattle-p5: Handle custom content.
        }
    }

    /++
    Описание очереди соперника.
    +/
    void targetAttack() @safe
    {
        if (targetIndex != 0)
        {
            auto es = targets[targetIndex - 1].endSelect;
            if (es !is null)
                es();
        }

        if (targetIndex >= targets.length)
        {
            import rgp.core.move : smoothEdit, smoothEditReverse;
            import tida.animobj;

            isTeamTurn = true;
            smoothEditReverse!(easeInOutSine)(panelFactor, null, null);

            foreach (ref e; battlePersons)
                e.isDefence = false;

            isOppDefeat = false;
            targetIndex = 0;
            targetWithId = -1;

            foreach (i; 0 .. battlePersons.length)
            {
                if (battlePersons[i].persona.hp > 0)
                {
                    personIndex = 0;
                    break;
                }
            }

            miniIndex = 0;
            selectIndex = 0;
            teamTurnIndex = 0;

            auto soul = sceneManager.context.getInstanceByClass!Soul;
            auto barier = sceneManager.context.getInstanceByClass!Barier;

            if (soul !is null)
            {
                soul.active = false;
            }

            if (barier !is null)
            {
                barier.active = false;
            }

            if (onTargetsRelease !is null)
                onTargetsRelease();
        }
        else
        {
            if (targets[targetIndex].info.hp < 0 && !isOppDefeat)
            {
                targetIndex++;
                targetAttack();
                return;
            }

            auto select = targets[targetIndex].onSelect;

            auto soul = sceneManager.context.getInstanceByClass!Soul;
            if (soul !is null)
            {
                import std.random : uniform;

                bool isFindTarget = false;

                while (!isFindTarget)
                {
                    targetWithId = uniform(0, battlePersons.length);
                    if (battlePersons[targetWithId].persona.hp > 0)
                        isFindTarget = true;
                }

                if (onTargetChoice !is null)
                    onTargetChoice(targetWithId);

                soul.targetWith(battlePersons[targetWithId]);
            }

            if (select !is null)
            {
                select();
                sceneManager.trigger("onTargetSelect", targets[targetIndex]);

                targetIndex++;
            }
            else
            {
                targetIndex++;
                targetAttack();
            }
        }
    }

    /++
    Закончить акт.
    +/
    void endAct() @safe
    {
        personIndex++;

        if (personIndex >= battlePersons.length)
        {
            import rgp.core.move : smoothEdit, smoothEditReverse;
            import tida.animobj;

            // Отрубаем управление выбором.
            isAttackMethod = false;
            isTemplateMode = false;
            isSelectMode = false;
            isTeamTurn = false;
            isTemplateUse = false;
            templateIndex = 0;
            templateUseIndex = 0;

            smoothEdit!(easeInOutSine)(panelFactor, null, null);

            auto soul = sceneManager.context.getInstanceByClass!Soul;
            auto barier = sceneManager.context.getInstanceByClass!Barier;

            if (soul !is null)
            {
                soul.active = true;
                if (soul.threeDim)
                {
                    soul.position = renderer.camera.port.begin + vec!float(320 - 8, 240 - 32);
                } else
                    soul.position = renderer.camera.port.begin + vec!float(320 - 8, 240 - 8);
            }

            if (barier !is null)
            {
                barier.active = true;
            }

            targetAttack();
        }
        else
        {
            // Пропускаем ход того, кто повержен
            if (battlePersons[personIndex].persona.hp < 0)
            {
                personIndex++;

                if (isTemplateUse)
                {
                    templateUseIndex++;
                    templateUse();
                }
                else
                    endAct();

                return;
            }

            // При использовании макроса
            // используем зарнее подготовленное действие
            // следующего персонажа
            if (isTemplateUse)
            {
                templateUseIndex++;
                templateUse();
            }
        }
    }

    /// Обработка атаки персонажа
    /// Params:
    ///     pi = Идентификатор персонажа.
    void attackHandle(size_t pi) @safe
    {
        isAttackMethod = true;
        currentAttack = battlePersons[pi].attackMethod;
    }

    /// Обработка разговора персонажа
    /// Params:
    ///     pi = Идентификатор персонажа.
    void talkHandle(size_t pi) @safe
    {
        import rgp.core.def;

        auto dialogTalk = new Dialog!(wstring)(locale.get("battle.talk"));
        dialogTalk.font = defFont;
        dialogTalk.width = 640 - 16;
        dialogTalk.position = vec!float(8, 320);
        dialogTalk.borderColor = battlePersons[personIndex].color;

        auto choiceTalk = new ChoiceDialog!(wstring)(dialogTalk);
        choiceTalk.choices ~= battlePersons[personIndex].choices.dup;
        choiceTalk.choices ~= ChoiceUnite!wstring(locale.get("battle.talkNoFind"), null);
        choiceTalk.onDestroy = &endAct;

        sceneManager.context.add(dialogTalk);
        sceneManager.context.add(choiceTalk);
    }

    /// Обработка инвентаря персонажа
    /// Params:
    ///     pi = Идентификатор персонажа.
    void inventoryHandle(size_t pi) @safe
    {
        // TODO-cBattle-p2: Сделать выбор варианта предметов в диалоге
        //       а также остановить ввод из панелей.
        endAct();
    }

    /// Обработка защиты персонажа
    /// Params:
    ///     pi = Идентификатор персонажа.
    void shieldHandle(size_t pi) @safe
    {
        // TODO-cBattle-p1: Пропустить ход и дать защиту персонажу.
        battlePersons[pi].isDefence = true;
        endAct();
    }

    /++
    Функция для использования действия персонажа,
    заданное макросом.
    +/
    void templateUse() @safe
    {
        auto pers = battlePersons[templateUseIndex];
        auto value = macroses[templateIndex][pers.aliasName];

        switch (value.selection)
        {
        case SelectionType.attack:
            {
                attackHandle(templateUseIndex);
            }
            break;

        case SelectionType.talk:
            {
                talkHandle(templateUseIndex);
            }
            break;

        case SelectionType.inventory:
            {
                inventoryHandle(templateUseIndex);
            }
            break;

        case SelectionType.defence:
            {
                shieldHandle(templateUseIndex);
            }
            break;

        default:
            throw new Exception("[Battle:Macros:Use] How u make it?");
        }
    }

    @event(Step) void checkStatus() @safe
    {
        import std.algorithm : all;

        if (!isTeamTurn && targetWithId != -1) // hot
        {
            if (battlePersons[targetWithId].persona.hp < 0)
            {
                targetAttack();
                isOppDefeat = true;
            }
        }

        if (battlePersons.all!(a => a.persona.hp < 0))
        {
            if (onDieAll !is null)
                onDieAll();
        }
    }

    void checkAllTargets() @safe
    {
        import std.algorithm : all;

        if (targets.all!(a => a.info.hp < 0))
        {
            if (onWinBattle !is null)
                onWinBattle();
        }
    }

    @event(Input) void handlePanelInput(EventHandler event) @safe
    {
        import rgp.core.setting;

        if (sceneManager.context.getInstanceByClass!(Dialog!wstring) !is null)
            return;

        if (isTeamTurn && !isSelectMode && !isTemplateMode)
        {
            if (keySetting.up.isDown(event) && miniIndex != 0)
            {
                miniIndex--;
                conSound.play();
            }

            if (keySetting.down.isDown(event) && miniIndex != 2)
            {
                miniIndex++;
                conSound.play();
            }

            if (keySetting.use.isUp(event))
            {
                if (miniIndex == 0)
                {
                    isSelectMode = true;
                }
                else if (miniIndex == 1)
                {
                    isTemplateMode = true;
                }
                else
                {
                    // TODO-cBattle-p3: Сделать побег из битвы.
                    if (onEscape !is null) onEscape();
                }

                selSound.play();
            }
        }
        else if (isSelectMode && !isAttackMethod)
        {
            if (keySetting.cancel.isDown(event))
            {
                isSelectMode = false;
            }

            if (keySetting.left.isDown(event) && selectIndex != 0)
            {
                selectIndex--;
                conSound.play();
            }

            if (keySetting.right.isDown(event) && selectIndex != 3)
            {
                selectIndex++;
                conSound.play();
            }

            if (keySetting.use.isDown(event))
            {
                selSound.play();

                switch (selectIndex)
                {
                case 0:
                    {
                        if (isTemplateEdit)
                        {
                            macroses[templateIndex][battlePersons[personIndex].aliasName] = TemplateParametrs(
                                    personIndex, SelectionType.attack, 0);

                            personIndex++;
                            if (personIndex == battlePersons.length)
                            {
                                isSelectMode = false;
                                isTemplateEdit = false;
                                personIndex = 0;
                            }
                        }
                        else
                        {
                            battlePersons[personIndex].select = SelectionType.attack;
                            attackHandle(personIndex);
                        }
                    }
                    break;

                case 1:
                    {
                        if (isTemplateEdit)
                        {
                            macroses[templateIndex][battlePersons[personIndex].aliasName] = TemplateParametrs(
                                    personIndex, SelectionType.talk, 0);

                            personIndex++;
                            if (personIndex == battlePersons.length)
                            {
                                isSelectMode = false;
                                isTemplateEdit = false;
                                personIndex = 0;
                            }
                        }
                        else
                        {
                            battlePersons[personIndex].select = SelectionType.talk;
                            talkHandle(personIndex);
                        }
                    }
                    break;

                case 2:
                    {
                        if (isTemplateEdit)
                        {
                            macroses[templateIndex][battlePersons[personIndex].aliasName] = TemplateParametrs(
                                    personIndex, SelectionType.inventory, 0);

                            personIndex++;
                            if (personIndex == battlePersons.length)
                            {
                                isSelectMode = false;
                                isTemplateEdit = false;
                                personIndex = 0;
                            }
                        }
                        else
                        {
                            battlePersons[personIndex].select = SelectionType.inventory;
                            inventoryHandle(personIndex);
                        }
                    }
                    break;

                case 3:
                    {
                        if (isTemplateEdit)
                        {
                            macroses[templateIndex][battlePersons[personIndex].aliasName] = TemplateParametrs(
                                    personIndex, SelectionType.defence, 0);

                            personIndex++;
                            if (personIndex == battlePersons.length)
                            {
                                isSelectMode = false;
                                isTemplateEdit = false;
                                personIndex = 0;
                            }
                        }
                        else
                        {
                            battlePersons[personIndex].select = SelectionType.defence;
                            shieldHandle(personIndex);
                        }
                    }
                    break;

                default:
                    throw new Exception("[Battle:Select] How u make it?");
                }
            }
        }
        // Выбор макроса
        else if (isTemplateMode && !isSelectMode && !isTemplateEdit && !isAttackMethod)
        {
            if (keySetting.up.isDown(event) && templateIndex != 0)
            {
                templateIndex--;
                conSound.play();
            }

            if (keySetting.down.isDown(event) && templateIndex != 6)
            {
                templateIndex++;
                conSound.play();
            }

            if (keySetting.inventory.isDown(event))
            {
                isTemplateEdit = true;
                isSelectMode = true;
                selSound.play();
            }

            if (keySetting.use.isDown(event))
            {
                selSound.play();

                if (macroses[templateIndex].length == 0)
                {
                    isTemplateEdit = true;
                    isSelectMode = true;
                }
                else
                {
                    isTemplateMode = false;
                    isSelectMode = false;
                    personIndex = 0;
                    templateUseIndex = 0;
                    isTemplateUse = true;

                    auto vs = macroses[templateUseIndex].keys;
                    if (vs.length != 1)
                    {
                        import std.algorithm : map, equal;
                        foreach (size_t i, MacroCombination e; combinations)
                        {
                            if (e.aliases.length <= vs.length)
                            {
                                auto sz = vs[0 .. e.aliases.length];
                                static bool equalAny(string[] a, string[] b)
                                {
                                    size_t equalCount = 0;
                                    foreach (e1; a)
                                    {
                                        foreach (e2; b)
                                        {
                                            if (e1 == e2)
                                            {
                                                equalCount++;
                                            }
                                        }
                                    }

                                    return equalCount >= a.length;
                                }

                                if (equalAny(sz, e.aliases))
                                {
                                    // TODO-cBattle-p0: сделать обработку макрос комбинаций
                                    if (onAttack !is null)
                                        onAttack(0);

                                    isAttackMethod = true;
                                    isMacrosAttack = true;
                                    combIndex = i;
                                    currentAttack = e.attack;
                                    templateUseIndex = e.aliases.length;
                                    personIndex = e.aliases.length;
                                    break;
                                }
                            }
                        }
                    }

                    if (!isMacrosAttack)
                    {
                        if (templateUseIndex == battlePersons.length)
                        {
                            endAct();
                        } else
                        {
                            templateUse();
                        }
                    }
                }
            }
        }
        else if (isAttackMethod)
        {
            if (keySetting.use.isDown(event))
            {
                auto info = currentAttack.acceptUse();
                if (info.isEnd)
                {
                    import std.random : uniform;

                    // TODO-cBattle-p1: Сделать выбор, кого нужно ударить.
                    //                  Пока будет рандом.

                    immutable targetID = uniform(0, targets.length);

                    if (onAttack !is null)
                        onAttack(targetID);

                    isUronView = true;

                    if (isMacrosAttack)
                    {
                        // viewUron = combinations[combIndex].uron * info.damageFactor;
                        // viewUronFactor = info.damageFactor;

                        listener.timer({
                            isUronView = false;
                        }, msecs(3000));

                        float ur;
                        if (((ur = info.damageFactor - targets[targetID].info.statistics.def / 100)) < 0)
                        {
                            ur = 0.0f;
                        }

                        viewUron = combinations[combIndex].uron * ur;
                        viewUronFactor = ur;

                        targets[targetID].info.hp -= combinations[combIndex].uron * ur;

                        isMacrosAttack = false;
                    } else
                    {
                        float ur;
                        if (((ur = info.damageFactor - targets[targetID].info.statistics.def / 100)) < 0)
                        {
                            ur = 0.0f;
                        }

                        viewUron = battlePersons[personIndex].persona.statistics.attack * ur;
                        viewUronFactor = ur;

                        listener.timer({
                            isUronView = false;
                        }, msecs(3000));

                        targets[targetID].info.hp -=
                            battlePersons[personIndex].persona.statistics.attack * ur;
                    }

                    if (targets[targetID].info.hp < 0)
                    {
                        if (targets[targetID].onDie !is null)
                            targets[targetID].onDie();
                    }

                    checkAllTargets();

                    isAttackMethod = false;
                    currentAttack = null; // Not a safe.
                    endAct();
                }
            }
        }
    }

    @event(Step) void handleAnimationPanel() @safe @threadSafe
    {
        import tida.animobj;

        if (isTeamTurn)
        {
            if (_factorPanelMiniSelect[0] >= 1.0f)
            {
                _factorPanelMiniSelect[0] = 1.0f;
            }
            else
            {
                _factorPanelMiniSelect[0] += 0.01f;
                easeOut!3(_factorPanelMiniSelect[1], _factorPanelMiniSelect[0]);
            }
        }
        else
        {
            if (_factorPanelMiniSelect[0] <= 0.0f)
            {
                _factorPanelMiniSelect[0] = 0.0f;
            }
            else
            {
                _factorPanelMiniSelect[0] -= 0.01f;
                easeOut!3(_factorPanelMiniSelect[1], _factorPanelMiniSelect[0]);
            }
        }

        if (isSelectMode)
        {
            if (_factorPanelSelect[0] >= 1.0f)
            {
                _factorPanelSelect[0] = 1.0f;
            }
            else
            {
                _factorPanelSelect[0] += 0.01f;
                easeOut!3(_factorPanelSelect[1], _factorPanelSelect[0]);
            }
        }
        else
        {
            if (_factorPanelSelect[0] <= 0.0f)
            {
                _factorPanelSelect[0] = 0.0f;
            }
            else
            {
                _factorPanelSelect[0] -= 0.01f;
                easeOut!3(_factorPanelSelect[1], _factorPanelSelect[0]);
            }
        }

        if (isTemplateMode)
        {
            if (_factorPanelTemplate[0] >= 1.0f)
            {
                _factorPanelTemplate[0] = 1.0f;
            }
            else
            {
                _factorPanelTemplate[0] += 0.01f;
                easeOut!3(_factorPanelTemplate[1], _factorPanelTemplate[0]);
            }
        }
        else
        {
            if (_factorPanelTemplate[0] <= 0.0f)
            {
                _factorPanelTemplate[0] = 0.0f;
            }
            else
            {
                _factorPanelTemplate[0] -= 0.01f;
                easeOut!3(_factorPanelTemplate[1], _factorPanelTemplate[0]);
            }
        }

        immutable _methodSpeed = 0.05f;

        if (isAttackMethod)
        {
            currentAttack.handleAttack();

            if (_methodAlphaFactor[0] <= 0.0f)
            {
                _methodAlphaFactor[0] = 0.0f;
                _methodAlphaFactor[1] = 0.0f;
            }
            else
            {
                _methodAlphaFactor[0] -= _methodSpeed;
                easeOut!3(_methodAlphaFactor[1], _methodAlphaFactor[0]);
            }
        }
        else
        {
            if (_methodAlphaFactor[0] >= 1.0f)
            {
                _methodAlphaFactor[0] = 1.0f;
                _methodAlphaFactor[1] = 1.0f;
            }
            else
            {
                _methodAlphaFactor[0] += _methodSpeed;
                easeOut!3(_methodAlphaFactor[1], _methodAlphaFactor[0]);
            }
        }
    }

    /+
    TODO: для отображения сделать:
    - Сделать интерфейс показа статистики персонажей.
    - Интерфейс выбора действий.
    - Обработку действий и вызов функции реакции противника.
    +/
    @event(Draw) void drawInterface(IRenderer render) @safe
    {
        import rgp.core.def;
        import std.conv : to;
        import std.utf : toUTF16;

        immutable goffset = render.camera.port.begin;
        immutable offsetPersons = 320 - (64 * battlePersons.length);

        auto color = parseColor("#d3b49d") * 0.5f;
        color.a = color.Max;

        // Отрисовка мини-панели выбора
        // Состоит из трёх пунктов:
        // - Выбор
        // - Шаблон
        // - Убежать

        // Цвет, если какая-то панель работает поверх.
        auto color2 = color;

        {
            immutable factor = (ubyte.max * _methodAlphaFactor[1]);
            if (factor > 64)
                color2.a = cast(ubyte) factor;
            else
                color2.a = 64;
        }

        immutable(float) miniPosition = -128 + (_factorPanelMiniSelect[1] * (128 + 8));
        render.rectangle(goffset + vec!float(miniPosition, 128), 128,
                cast(uint) defFont.size * 6 + 8, color2, true);
        render.rectangle(goffset + vec!float(miniPosition, 128), 128,
                cast(uint) defFont.size * 6 + 8, rgba(255, 255, 255, color2.a), false);
        render.drawEx(cursor, goffset + vec!float(miniPosition + 4,
                128 + 4 + (miniIndex * defFont.size * 2)), 0.0f, vecNaN!float,
                vecNaN!float, color2.a);
        render.draw(new Text(defFont).renderSymbols(locale.get("battleMiniPanel.select"),
                rgba(255, 255, 255, color2.a)), goffset + vec!float(miniPosition + 24, 128 + 4));
        render.draw(new Text(defFont).renderSymbols(locale.get("battleMiniPanel.template"),
                rgba(255, 255, 255, color2.a)),
                goffset + vec!float(miniPosition + 24, 128 + 4 + defFont.size * 2));
        render.draw(new Text(defFont).renderSymbols(locale.get("battleMiniPanel.run"),
                rgba(255, 255, 255, color2.a)),
                goffset + vec!float(miniPosition + 24, 128 + 4 + defFont.size * 4));

        // Отрисовка интерфейса выбора.
        if (_factorPanelSelect[0] > 0.0f)
        {
            immutable selectPosition = -156 + (156 + 320 - (156 / 2)) * _factorPanelSelect[1];

            render.rectangle(goffset + vec!float(selectPosition, 480 - 128 - 64),
                    156, 40, color2, true);
            render.rectangle(goffset + vec!float(selectPosition, 480 - 128 - 64),
                    156, 40, rgba(255, 255, 255, color2.a), false);

            render.drawEx(icons["attack"], goffset + vec!float(selectPosition + 14,
                    480 - 128 - 60), 0.0f, vecNaN!float, vecNaN!float, color2.a);

            render.drawEx(icons["talk"], goffset + vec!float(selectPosition + 46,
                    480 - 128 - 60), 0.0f, vecNaN!float, vecNaN!float, color2.a);

            render.drawEx(icons["inventory"], goffset + vec!float(selectPosition + 78,
                    480 - 128 - 60), 0.0f, vecNaN!float, vecNaN!float, color2.a);

            render.drawEx(icons["shield"], goffset + vec!float(selectPosition + 110,
                    480 - 128 - 60), 0.0f, vecNaN!float, vecNaN!float, color2.a);

            render.line([
                goffset + vec!float(selectPosition + 14 + (selectIndex * 32),
                        480 - 128 - 24),
                goffset + vec!float(selectPosition + 14 + (selectIndex * 32) + 32, 480 - 128 - 24)
            ], rgba(255, 0, 0, color2.a));
        }

        // Отрисовка панели выбора шаблона
        if (_factorPanelMiniSelect[1] > 0.0f)
        {
            immutable templatePosition = goffset + vec!float(
                    -156 + (156 + 156) * _factorPanelTemplate[1], 128);
            render.rectangle(templatePosition, 156, 128, color2, true);
            render.rectangle(templatePosition, 156, 128, rgba(255, 255, 255, color2.a), false);

            render.draw(cursor, templatePosition + vec!float(4,
                    8 + templateIndex * (defFont.size * 2)));

            int index = 0;
            for (wchar i = 'A'; i < 'A' + 7; i += 1, index++)
            {
                render.draw(new Text(defFont).renderSymbols([i],
                        macroses[i - 'A'].length != 0 ? rgba(255, 255, 255,
                        color.a) : rgba(128, 128, 128, color.a)),
                        templatePosition + vec!float(24, 8 + index * (defFont.size * 2)));
            }

            if (this.macroses[templateIndex].length != 0)
            {
                import std.algorithm : canFind;

                size_t existPersonIndex = 0;

                auto persMacros = this.macroses[templateIndex];

                foreach (e; persMacros.byKey)
                {
                    if (battlePersons.canFind!(a => a.aliasName == e))
                    {
                        auto pers = byAliasName(e);
                        auto syms = new Text(defFont).toSymbols(pers.name, rgb(255, 255, 255));

                        render.draw(new SymbolRender(syms), templatePosition + vec!float(40,
                                8 + existPersonIndex * (defFont.size * 2)));

                        render.drawEx(iconFrom(persMacros[e].selection),
                                templatePosition + vec!float(44 + syms.widthSymbols,
                                    8 + existPersonIndex * (defFont.size * 2)), 0.0f,
                                vecNaN!float, vec!float(16, 16), ubyte.max);

                        existPersonIndex++;
                    }
                }
            }
        }

        // Отрисовка ячеек информации о персонажах.
        foreach (size_t i, e; battlePersons)
        {
            render.rectangle(goffset + vec!float(offsetPersons + i * 128,
                    480 - 128 - 8 + (64 * panelFactor)), 128, 128 - cast(uint) (64 * panelFactor), color2, true);
            render.rectangle(goffset + vec!float(offsetPersons + i * 128,
                    480 - 128 - 8  + (64 * panelFactor)), 128, 128  - cast(uint) (64 * panelFactor), rgba(255, 255, 255, color2.a), false);

            if (targetWithId == i)
            {
                render.rectangle(goffset + vec!float(offsetPersons + i * 128 + 2,
                        480 - 128 - 8 + 2 + (64 * panelFactor)), 128 - 4, 128 - 4 - cast(uint) (64 * panelFactor), rgba(255, 0, 0, color2.a), false);
            }

            // TODO-cBattle-p4: Обезцветить, если персонаж сделал или не сделал выбора.
            // Цвет дб только в случии выбора за данного персонажа.
            auto nameSyms = new Text(defFont).toSymbols(e.name, rgba(e.color.r,
                    e.color.g, e.color.b, color2.a));

            // Отрисовка основных показателей
            // Имя персонажа
            render.draw(new SymbolRender(nameSyms),
                    goffset + vec!float(offsetPersons + i * 128 + 64 - nameSyms.widthSymbols / 2,
                        480 - 128 + (64 * panelFactor)));

            if (personIndex == i)
            {
                render.line([
                    goffset + vec!float(offsetPersons + i * 128 + 64 - nameSyms.widthSymbols / 2,
                            480 - 128 + defFont.size * 2 - 2 + (64 * panelFactor)),
                    goffset + vec!float(offsetPersons + i * 128 + 64 + nameSyms.widthSymbols / 2,
                            480 - 128 + defFont.size * 2 - 2 + (64 * panelFactor))
                ], rgba(255, 255, 255, color2.a));
            }

            // Кол-во ЖЭ.
            auto hpSyms = new Text(defFont).toSymbols(locale.get(
                    "personaNameless.hpShorted") ~ ": " ~ e.hp.to!string.toUTF16,
                    rgba(255, 255, 255, color2.a));

            render.draw(new SymbolRender(hpSyms),
                    goffset + vec!float(offsetPersons + i * 128 + 4, 480 - 128 + defFont.size * 2 + (64 * panelFactor)));
            immutable hpFactor = cast(float) e.hp / cast(float) e.maxHP;

            render.line([
                goffset + vec!float(offsetPersons + +i * 128 + 4,
                        480 - 128 + defFont.size * 4 - 2 + (64 * panelFactor)),
                goffset + vec!float(offsetPersons + +i * 128 + 4 + ((128 - 4) * hpFactor),
                        480 - 128 + defFont.size * 4 - 2 + (64 * panelFactor))
            ], parseColor("#b81a1a"));

            // Кол-во МЭ.
            auto tpSyms = new Text(defFont).toSymbols(locale.get(
                    "personaNameless.tpShorted") ~ ": " ~ e.tp.to!string.toUTF16,
                    rgba(255, 255, 255, color2.a));

            render.draw(new SymbolRender(tpSyms),
                    goffset + vec!float(offsetPersons + i * 128 + 4, 480 - 128 + defFont.size * 4 + (64 * panelFactor)));
            immutable tpFactor = cast(float) e.tp / cast(float) e.maxTP;

            render.line([
                goffset + vec!float(offsetPersons + i * 128 + 4,
                        480 - 128 + defFont.size * 6 - 2 + (64 * panelFactor)),
                goffset + vec!float(offsetPersons + i * 128 + 4 + (128 - 4) * tpFactor,
                        480 - 128 + defFont.size * 6 - 2 + (64 * panelFactor))
            ], rgba(64, 64, 255, color2.a));

            // Показатель состояния
            auto condSyms = new Text(defFont).toSymbols(e.conditionName,
                    panelFactor <= 0.01 ?
                        rgba(255, 255, 255, color2.a) :
                        rgba(255, 255, 255, cast(ubyte) (ubyte.max - (ubyte.max * panelFactor))));

            render.draw(new SymbolRender(condSyms),
                    goffset + vec!float(offsetPersons + i * 128 + 64 - condSyms.widthSymbols / 2,
                        480 - 128 + defFont.size * 8));

            render.drawEx(iconFrom(e.select),
                    goffset + vec!float(offsetPersons + i * 128 + 64 - 16,
                        480 - 128 + defFont.size * 10), 0.0f, vecNaN!float,
                    vecNaN!float,
                        panelFactor <= 0.01 ?
                        color2.a :
                        cast(ubyte) (ubyte.max - (ubyte.max * panelFactor))
            );
        }

        // Отрисовка списка противников.
        {
            import std.algorithm : map, maxElement, reduce;
            import std.range : array;

            Symbol[][] targetSyms = targets.map!(a => new Text(defFont)
                    .toSymbols(a.info.name, a.info.color)).array;

            float width = 0.0f;
            foreach (e; targetSyms)
            {
                float temp;

                if ((temp = widthSymbols(e)) > width)
                    width = temp;
            }

            float height = targetSyms.length * (defFont.size * 2);

            render.rectangle(goffset + vec!float(8, 8), cast(uint) width + 8,
                    cast(uint) height + 8, color2, true);

            for (size_t i = 0; i < targetSyms.length; i++)
            {
                render.draw(new SymbolRender(targetSyms[i]),
                        goffset + vec!float(12, 12 + i * (defFont.size * 2)));

                immutable factor = targets[i].info.hp / targets[i].info.maxHP;
                render.line([
                    goffset + vec!float(12, 12 + i * (defFont.size * 3)),
                    goffset + vec!float(12 + ((width - 8) * factor), 12 + i * (defFont.size * 3))
                ], rgb(255, 0, 0));
            }
        }

        if (isUronView)
        {
            import std.conv : to;

            Symbol[] urSymbols = new Text(defFont).toSymbols(viewUron.to!string, rgb(255, 255, 255));
            immutable urWidth = widthSymbols(urSymbols);

            render.rectangle(goffset + vecf(320 - urWidth / 2 - 8, 8),
                    urWidth + 8, 22, color2, true);
            render.rectangle(goffset + vecf(320 - urWidth / 2 - 8, 8),
                    urWidth + 8, 22, color2, false);
            render.draw(
                new SymbolRender(urSymbols),
                goffset + vecf(320 - urWidth / 2, 10)
            );

            render.line([
                goffset + vecf(320 - urWidth / 2, 28),
                goffset + vecf(320 + urWidth / 2 - 8, 28)
            ], rgb(255, 0, 0));
        }

        // Отрисовка интерфейса атаки.
        if (isAttackMethod)
        {
            currentAttack.drawAttack(render);
        }
    }
}
