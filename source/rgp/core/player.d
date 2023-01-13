/++
Модуль, описывающий игровую модель гг.
+/
module rgp.core.player;

import tida;
import rgp.core.setting;
import std.traits : isSomeString;

struct TexturePack
{
    IDrawableEx leftStand, rightStand, upStand, downStand, leftMove, rightMove, upMove, downMove;
}

/// Функция превращения картинки в отображаемый объект.
alias drawabled = (Image e) => (cast(IDrawableEx) e);

/// Структура, описывающая, что должно происходить при
/// взаимодействии с объектом.
struct TouchUnite(TypeString) if (isSomeString!TypeString)
{
public:
    /// Диалоговый текст, который должен отобразиться
    /// на панели диалога при взаимодействии.
    /// Если не нужно - оставляйте строку пустым.
    TypeString text;

    /// Что должно исполниться при взаимодействии.
    /// Оставьте пустым, если не нужно.
    void delegate() @safe onNext = null;

    this(TypeString text, void delegate() @safe onNext = null) @safe
    {
        this.text = text;
        this.onNext = onNext;
    }

    this(void delegate() @safe onNext) @safe
    {
        this.onNext = onNext;
    }
}

enum touchEmpty(T) = TouchUnite!(T)("", {
        sceneManager.context.getInstanceByClass!Player.isMove = true;
    });

/// Интерфейс описания объекта, с которым взаимодействовали.
interface ITouching(TypeString) if (isSomeString!TypeString)
{
    /// Функция, выдающая последовательность событий,
    /// которые должны быть исполнены при взаимодействии
    /// объекта.
    TouchUnite!TypeString[] touchInfo() @safe;
}

/++
Текстуры Тиды в первом томе (маленький возраст).
+/
TexturePack makeTidaTexturePack() @safe
{
    import std.algorithm : map, each;
    import std.range : array;

    immutable animationSpeed = 0.5f;

    TexturePack tidaPack;

    Image rightStand = new Image().load("textures/firstTom/tidaStandRight.png");
    rightStand.toTexture;

    Image leftStand = rightStand.flipX;
    leftStand.toTexture;

    Image upStand = new Image().load("textures/firstTom/tidaStandUp.png");
    upStand.toTexture;

    Image downStand = new Image().load("textures/firstTom/tidaStandDown.png");
    downStand.toTexture;

    tidaPack.leftStand = leftStand;
    tidaPack.rightStand = rightStand;
    tidaPack.upStand = upStand;
    tidaPack.downStand = downStand;

    Image[] rightMove = new Image().load("textures/firstTom/tidaMoveRight.png").strip(0, 0, 48, 48);
    rightMove.each!((ref e) => e.toTexture);

    Image[] leftMove = rightMove.map!(a => a.flipX).array;
    leftMove.each!((ref e) => e.toTexture);

    Image[] upMove = new Image().load("textures/firstTom/tidaMoveUp.png").strip(0, 0, 48, 48);
    upMove.each!((ref e) => e.toTexture);

    Image[] downMove = new Image().load("textures/firstTom/tidaMoveDown.png").strip(0, 0, 48, 48);
    downMove.each!((ref e) => e.toTexture);

    Animation animLeftMove = new Animation();
    animLeftMove.frames = leftMove.map!drawabled.array;
    animLeftMove.speed = animationSpeed;
    animLeftMove.isRepeat = true;

    Animation animRightMove = new Animation();
    animRightMove.frames = rightMove.map!drawabled.array;
    animRightMove.speed = animationSpeed;
    animRightMove.isRepeat = true;

    Animation animUpMove = new Animation();
    animUpMove.frames = upMove.map!drawabled.array;
    animUpMove.speed = animationSpeed;
    animUpMove.isRepeat = true;

    Animation animDownMove = new Animation();
    animDownMove.frames = downMove.map!drawabled.array;
    animDownMove.speed = animationSpeed;
    animDownMove.isRepeat = true;

    tidaPack.leftMove = animLeftMove;
    tidaPack.rightMove = animRightMove;
    tidaPack.upMove = animUpMove;
    tidaPack.downMove = animDownMove;

    return tidaPack;
}

/++
Объект игрока.

Игрок не зависим от каких-либо фактором. Он должен уметь:
* Передвигаться.
* Не передвигаться сквозь преград [1]
* Факторы могут менять ей спрайт.
* Факторы могут остановить движение объекта.
* Факторы могут выключить объект.
* Показывать характеристику пероснажей и использовать инвентарь.

---
[1]: Преграды, которые имеют маску и пометку "solid".
---
TODO: Реализовать билдинг к главному герою вместо константных значений.
+/
final class Player : Instance
{
    import tida.graphics.gapi;
    import rgp.core.characteristic;
    import std.algorithm.searching : find;

    immutable gridSize = 32;

private:
    TexturePack _texturePack;
    float _speed = 3.0f;
    tida.Image cursor;

    bool isPlayersPanelView = false, isCharAndInvView = false;
    size_t personaIndex = 0;
    size_t itemIndex = 0;

    float[2] _factorPanel = [0.0f, 0.0f];
    float[2] _factorCursor = [0.0f, 0.0f];
    ubyte _factorCursorDir = 0;

    float[2] _factorCharInv = [0.0f, 0.0f];

    ubyte lastDirection = 0; // 0 - влево, 1 - вправо, 2 - вверх, 3 - вниз
    size_t touchIndex = 0;

    Sprite sprite_other;
    // ImageView viewd;
    // Sampler sampler;

    size_t opponents = 0;

public:
    Vector!float velocity = vecZero!float;

    /// Разрешение, можно ли управлять игроком.
    bool isMove = true;

    Vector!float[] lastPositions;

    @property Sprite spritePtr() @safe
    {
        return sprite_other;
    }

    this() @trusted
    {
        import std.file : readText;

        name = "player";

        sprite_other = new Sprite();

        solid = true;
        mask = Shape!float.Rectangle(vec!float(12, 5), vec!float(35, 47));

        sprite_other.shader = renderer.api.createShaderProgram();
        
        auto vert = renderer.api.createShader(StageType.vertex);
        vert.loadFromSource("shaders/tida.vert".readText);
        
        auto frag = renderer.api.createShader(StageType.fragment);
        frag.loadFromSource("shaders/tida.frag".readText);
        
        sprite_other.shader.attach(vert);
        sprite_other.shader.attach(frag);
        sprite_other.shader.link();

        renderer.setShader("TidaShader", sprite_other.shader);

        depth = 10;

        cursor = loader.load!Image("textures/cursor.png");
        if (cursor.texture is null)
            cursor.toTexture();

        persistent = true;
    }

    void bindCharacteristic() @safe
    {
        // Формула скорости:
        // speed = (ловкость / 10);

        auto tidaPerson = byAlias("tida");

        sprite_other.color = tidaPerson.color;
        _speed = tidaPerson.statistics.dexterity / 10;
    }

    /++
    Текстурный атлас персонажа.
    +/
    @property TexturePack texturePack(TexturePack pack) @safe
    {
        _texturePack = pack;
        this.toDefaultStand();

        return _texturePack;
    }

    /// ditto
    @property TexturePack texturePack() @safe
    {
        return _texturePack;
    }

    /++
    Поставит персонажа в позу по умолчанию.
    +/
    void toDefaultStand() @safe
    {
        sprite_other.draws = _texturePack.downStand;
    }

    void attach(PlayerOpponent opponent) @safe
    {
        opponent.tid = 8 - (opponents + 1);
        opponents++;
    }

    /++
    Обработать взаимодействие с объектом.

    Params:
        instance = Объект, у которого обнаружилось свойство взаимодействовать.
    +/
    void handleTouch(Instance instance) @safe
    {
        ITouching!wstring touching = cast(ITouching!wstring) instance;
        if (touching is null)
            throw new Exception("This object in the tags is registered as a touching, although it does not implement such an opportunity." // @suppress(dscanner.style.long_line)
            );

        auto touchInfo = touching.touchInfo;

        void touchNext(TouchUnite!wstring[] info) @safe
        {
            if (touchIndex >= info.length)
            {
                touchIndex = 0;
                return;
            }

            if (info[touchIndex].text.length != 0)
            {
                import rgp.core.dialog;
                import rgp.core.def : defFont;

                auto dialog = new Dialog!wstring(info[touchIndex].text);
                dialog.font = defFont;
                dialog.borderColor = byAlias("tida").color;
                dialog.position = renderer.camera.port.begin + vec!float(8, 256);
                dialog.width = 640 - 16;
                dialog.onDestroy = {
                    if (info[touchIndex].onNext !is null)
                        info[touchIndex].onNext();

                    touchIndex++;
                    touchNext(info);
                };

                sceneManager.context.add(dialog);
            }
            else
            {
                if (info[touchIndex].onNext !is null)
                    info[touchIndex].onNext();

                touchIndex++;
                touchNext(info);
            }
        }

        touchNext(touchInfo);
    }

    @event(Input) void inputMove(EventHandler event) @safe
    {
        if (!isMove)
            return;

        if (keySetting.inventory.isDown(event))
        {
            isPlayersPanelView = !isPlayersPanelView;

            if (!isPlayersPanelView)
                isCharAndInvView = false;
        }

        if (isPlayersPanelView)
            return;

        if (keySetting.right.isDown(event))
        {
            velocity.x = _speed;

            sprite_other.draws = _texturePack.rightMove;
        }

        if (keySetting.right.isUp(event))
        {
            if (velocity.x > 0)
            {
                velocity.x = 0;

                if (velocity == vecZero!float)
                {
                    sprite_other.draws = _texturePack.rightStand;
                }
            }

            lastDirection = 1;
        }

        if (keySetting.left.isDown(event))
        {
            velocity.x = -_speed;

            sprite_other.draws = _texturePack.leftMove;
        }

        if (keySetting.left.isUp(event))
        {
            if (velocity.x < 0)
            {
                velocity.x = 0;

                if (velocity == vecZero!float)
                {
                    sprite_other.draws = _texturePack.leftStand;
                }
            }

            lastDirection = 0;
        }

        if (keySetting.up.isDown(event))
        {
            velocity.y = -_speed;

            sprite_other.draws = _texturePack.upMove;
        }

        if (keySetting.up.isUp(event))
        {
            if (velocity.y < 0)
            {
                velocity.y = 0;

                if (velocity == vecZero!float)
                {
                    sprite_other.draws = _texturePack.upStand;
                }
            }

            lastDirection = 2;
        }

        if (keySetting.down.isDown(event))
        {
            velocity.y = _speed;

            sprite_other.draws = _texturePack.downMove;
        }

        if (keySetting.down.isUp(event))
        {
            if (velocity.y > 0)
            {
                velocity.y = 0;

                if (velocity == vecZero!float)
                {
                    sprite_other.draws = _texturePack.downStand;
                }
            }

            lastDirection = 3;
        }

        if (keySetting.use.isDown(event))
        {
            Shape!float maskTouch = mask;

            switch (lastDirection)
            {
            case 0:
                {
                    maskTouch.move(vec!float(-8, 0));
                }
                break;

            case 1:
                {
                    maskTouch.move(vec!float(8, 0));
                }
                break;

            case 2:
                {
                    maskTouch.move(vec!float(0, -8));
                }
                break;

            case 3:
                {
                    maskTouch.move(vec!float(0, 8));
                }
                break;

            default:
                break;
            }

            foreach (instance; sceneManager.context.list)
            {
                import tida.collision;
                import std.algorithm : canFind;

                if (instance.tags.canFind("touching"))
                {
                    if (isCollide(maskTouch, instance.mask, position, instance.position))
                    {
                        isMove = false;
                        handleTouch(instance);
                    }
                }
            }
        }
    }

    void handleMove() @safe @event(Step)
    {
        import tida.collision;
        import std.algorithm : canFind;

        if (!isMove)
            return;

        previous = position;

        if (velocity != vecZero!float)
        {
            Vector!float tempPos = position + velocity;

            foreach (other; sceneManager.current.list)
                synchronized
            {
                if (other !is null && other.solid && other.tags.canFind("solid"))
                {
                    if (isCollide(mask, other.mask, tempPos, other.position))
                    {
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

        position += velocity;

        // GRID SECTION
        if (lastPositions.length > 8)
        {
            lastPositions = lastPositions[1 .. $];
        }

        if (lastPositions.length != 0)
        {
            if (lastPositions[$ - 1].distance(position) > gridSize)
            {
                lastPositions ~= position;
            }
        }
        else
        {
            lastPositions ~= position;
        }
    }

    @event(Step) void panelAnimation() @safe @threadSafe
    {
        import tida.animobj;

        immutable speedAnimation = 0.05f;
        immutable cursorSpeedAnimation = 0.05f;

        if (isPlayersPanelView && !isCharAndInvView)
        {
            if (_factorCursorDir == 0)
            {
                if (_factorCursor[0] > 1.0f)
                {
                    _factorCursorDir = 1;
                    _factorCursor[0] = 1.0f;
                    return;
                }

                _factorCursor[0] += cursorSpeedAnimation;

                easeInOutSine(_factorCursor[1], _factorCursor[0]);
            }
            else
            {
                if (_factorCursor[0] < 0.0f)
                {
                    _factorCursorDir = 0;
                    _factorCursor[0] = 0.0f;
                    return;
                }

                _factorCursor[0] -= cursorSpeedAnimation;

                easeInOutSine(_factorCursor[1], _factorCursor[0]);
            }

            _factorPanel[0] += speedAnimation;

            if (_factorPanel[0] > 1.0f)
            {
                _factorPanel[0] = 1.0f;
                return;
            }

            easeOut!3(_factorPanel[1], _factorPanel[0]);
        }
        else
        {
            _factorPanel[0] -= speedAnimation;

            if (_factorPanel[0] < 0.0f)
            {
                _factorPanel[0] = 0.0f;
                return;
            }

            easeIn!3(_factorPanel[1], _factorPanel[0]);
        }

        if (isCharAndInvView)
        {
            _factorCharInv[0] += speedAnimation;

            if (_factorCharInv[0] > 1.0f)
            {
                _factorCharInv[0] = 1.0f;
                return;
            }

            easeOut!3(_factorCharInv[1], _factorCharInv[0]);
        }
        else
        {
            _factorCharInv[0] -= speedAnimation;

            if (_factorCharInv[0] < 0.0f)
            {
                _factorCharInv[0] = 0.0f;
                return;
            }

            easeOut!3(_factorCharInv[1], _factorCharInv[0]);
        }
    }

    @event(Input) void personaPanelInput(EventHandler event) @safe
    {
        if (isPlayersPanelView)
        {
            if (keySetting.up.isDown(event) && personaIndex != 0)
            {
                personaIndex--;
            }

            if (keySetting.down.isDown(event) && personaIndex != persons.length - 1)
            {
                personaIndex++;
            }

            if (keySetting.use.isDown(event))
            {
                isCharAndInvView = true;
            }
        }

        if (isCharAndInvView)
        {
            if (keySetting.cancel.isDown(event))
            {
                isCharAndInvView = false;
            }
        }
    }

    void delegate(Player) @safe attachUniform = null;

    @event(Draw) void drawSelf(IRenderer render) @safe
    {
        if (attachUniform !is null)
            attachUniform(this);

        render.draw(sprite_other, position);

        if (attachUniform !is null)
            attachUniform(this);
    }

    @event(Draw) void drawInventory(IRenderer render) @safe
    {
        import rgp.core.def;

        immutable of = render.camera.port.begin;

        auto color = parseColor("#d3b49d") * 0.5f;
        color.a = 128;

        if (_factorPanel[0] > 0)
        {
            immutable panelPosition = of + vec!float(-128 + ((128 + 8) * _factorPanel[1]), 8);

            render.rectangle(panelPosition, 128,
                    cast(uint) persons.length * cast(uint)(defFont.size * 2) + 4, color, true);

            foreach (size_t i, persona; persons)
            {
                render.draw(new Text(defFont).renderSymbols(persona.name,
                        rgb(255, 255, 255)), panelPosition + vec!float(20,
                        4 + cast(uint) i * cast(uint)(defFont.size * 2)));
            }

            render.draw(cursor, panelPosition + vec!float(2 + (_factorCursor[1] * 4),
                    2 + cast(uint) personaIndex * cast(uint)(defFont.size * 2)));
        }

        /*
        Отрисовка информации о персонаже. Именно:
        - Имя, окрашенное в его цвет характера.
        - Физическая статистика:
          L Сила
          L Ловкость
          L Интеллект
          L Атака
          L Защита
        - Примерный показатель психического состояния,
          а именно кто персонаж по своей натуре.

        Также, отрисовка инвентаря:
        - Рядом с панелью персонажа отображается панель инвентаря
          с предметами.
        - Внутри такой панели - предметы.
        */
        if (_factorCharInv[0] > 0.0f)
        {
            import std.conv : to;
            import std.utf : toUTF16;
            import rgp.core.locale;

            immutable charInvPosition = of + vec!float(8, -156 + ((156 + 8) * _factorCharInv[1]));

            immutable inventoryPosition = charInvPosition + vec!float(128 + 8, 0);

            // Отрисовка панели инфомации о персонаже.
            render.rectangle(charInvPosition, 128, 156, color, true);
            render.line([charInvPosition, charInvPosition + vec!float(0, 156)], rgb(255, 255, 255));
            render.line([
                charInvPosition + vec!float(0, 4 + defFont.size * 2),
                charInvPosition + vec!float(128, 4 + defFont.size * 2)
            ], rgb(255, 255, 255));
            render.line([
                charInvPosition + vec!float(0, 28 + defFont.size * 12),
                charInvPosition + vec!float(128, 28 + defFont.size * 12)
            ], rgb(255, 255, 255));

            render.draw(new Text(defFont).renderSymbols(persons[personaIndex].name,
                    persons[personaIndex].color), charInvPosition + vec!float(4, 4));

            render.draw(new Text(defFont).renderSymbols(locale.get(
                    "statisticsNames.strength") ~ ": " ~ persons[personaIndex].statistics.strength.to!string.toUTF16,
                    rgb(255, 255, 255)), charInvPosition + vec!float(4, 8 + defFont.size * 2));

            render.draw(new Text(defFont).renderSymbols(locale.get(
                    "statisticsNames.dexterity") ~ ": " ~ persons[personaIndex].statistics.dexterity.to!string.toUTF16,
                    rgb(255, 255, 255)), charInvPosition + vec!float(4, 12 + defFont.size * 4));

            render.draw(new Text(defFont).renderSymbols(locale.get(
                    "statisticsNames.mental") ~ ": " ~ persons[personaIndex].statistics.mental.to!string.toUTF16,
                    rgb(255, 255, 255)), charInvPosition + vec!float(4, 16 + defFont.size * 6));

            render.draw(new Text(defFont).renderSymbols(locale.get(
                    "statisticsNames.attack") ~ ": " ~ persons[personaIndex].statistics.attack.to!string.toUTF16,
                    rgb(255, 255, 255)), charInvPosition + vec!float(4, 20 + defFont.size * 8));

            render.draw(new Text(defFont)
                    .renderSymbols(locale.get(
                        "statisticsNames.def") ~ ": " ~ persons[personaIndex].statistics.def.to!string.toUTF16,
                        rgb(255, 255, 255)), charInvPosition + vec!float(4, 24 + defFont.size * 10));

            render.draw(new Text(defFont).renderSymbols(persons[personaIndex].nature.natureName,
                    rgb(255, 255, 255)), charInvPosition + vec!float(4, 22 + defFont.size * 14));

            // Отрисовка информации о состовляющее инвентаря.
            render.rectangle(inventoryPosition, 256, 156, color, true);

            immutable maxViewItems = 156 / defFont.size * 2;
            immutable offsetItems = itemIndex > maxViewItems ? itemIndex - maxViewItems : 0;
            immutable realViewItems = maxViewItems > persons[personaIndex].inventory.length ?
                persons[personaIndex].inventory.length : maxViewItems;

            if (persons[personaIndex].inventory.length != 0)
            {
                for (size_t index = offsetItems; index < offsetItems + realViewItems;
                        index++)
                {
                    immutable positionItem = of + vec!float(16,
                            4 + ((index - offsetItems) * (defFont.size * 2)));

                    render.draw(new Text(defFont)
                            .renderSymbols(persons[personaIndex].inventory[index].name,
                                rgb(255, 255, 255)), positionItem);
                }
            }
            else
            {
                // TODO-cPlayer-p1: Инвентарь <иначе?>
            }
        }
    }
}

// TODO-cPlayer-p2: Зависимость скорости от характеристики оппонента.
final class PlayerOpponent : Instance
{
private:
    TexturePack _texturePack;
    Player player;
    float speed = 3.0f;
    ubyte lastDirection = 0;

public:
    bool isMove = true;
    package(rgp.core) size_t tid;

    this(Player player) @safe
    {
        this.player = player;
        player.attach(this);

        persistent = true;
    }

    @property Sprite spritePtr() @safe
    {
        return sprite;
    }

    @property void texturePack(TexturePack pack) @safe
    {
        this._texturePack = pack;
    }

    @property TexturePack texturePack() @safe
    {
        return this._texturePack;
    }

    @event(Entry) void onEntry() @safe
    {
        this.position = sceneManager.context.getInstanceByClass!Player.position;
    }

    @event(Step) void handleMove() @threadSafe @safe
    {
        if (!isMove)
            return;

        previous = position;

        if (player.lastPositions.length <= tid)
            return;

        if (position.distance(player.lastPositions[tid]) > 2)
        {
            position += position.pointDirection(player.lastPositions[tid]).vectorDirection * speed;
        }

        auto factor = previous - position;

        if (factor.x < 0)
        {
            sprite.draws = _texturePack.rightMove;
            lastDirection = 0;
        }
        else if (factor.x > 0)
        {
            sprite.draws = _texturePack.leftMove;
            lastDirection = 1;
        }
        else if (factor.y < 0)
        {
            sprite.draws = _texturePack.downMove;
            lastDirection = 2;
        }
        else if (factor.y > 0)
        {
            sprite.draws = _texturePack.upMove;
            lastDirection = 3;
        }

        if (factor == vecZero!float)
        {
            switch (lastDirection)
            {
            case 0:
                sprite.draws = _texturePack.rightStand;
                break;

            case 1:
                sprite.draws = _texturePack.leftStand;
                break;

            case 2:
                sprite.draws = _texturePack.downStand;
                break;

            case 3:
                sprite.draws = _texturePack.upStand;
                break;

            default:
                return;
            }
        }
    }
}
