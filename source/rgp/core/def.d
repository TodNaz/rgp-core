/++
Модуль для часто используемых функций.
+/
module rgp.core.def;

import std.traits : isFunction;
import std.traits;
import tida;

static int mwidth = 640;
static int mheight = 480;
static int __dbgAttackID = 0;
static int __dbgBattleSkip = 0;
static int __dbgSkipBattleDialogs = 0;

static float fAnimSpeed = 1.0f;

enum GameSave = Trigger("GameSave");

//static Font smallFont;
static Font defFont; /// Шрифт по умолчанию.
static Font bigFont; /// Особо крупный шрифт.

/// Повторяет действие n-ое колличество раз.
/// Example:
/// ---
/// int[] a;
/// repeat(a = uniform(0, 155), 32)
/// ---
void repeat(lazy void fun, size_t count) @safe
{
    foreach (_; 0 .. count)
        fun();
}

/// Единица показа комикса.
struct ComixUnite(TypeString) if (isSomeString!TypeString)
{
    import rgp.core.dialog;
    import tida.graphics.gapi;

public:
    Image image; /// Картинка для комикса.

    /// Текст в диалоге. Оставить пустым, если не нужно диалога.
    TypeString text;

    /// Варианты выбора в диалоге. Оставить пустым, если не нужны.
    ChoiceUnite!TypeString[] choices;

    /// функция, когда комикс идёт к следущей или закончился на этом.
    void delegate() @safe onNext;

    /// Используемый шейдер
    IShaderProgram shader;

    /// Используемая матрица
    float[4][4] matrix = identity();

    Color!ubyte borderColor = rgb(255, 255, 255);
}

IDrawableEx[] toDrawable(T)(T[] arr) @safe
{
    IDrawableEx[] result;
    foreach (e; arr)
        result ~= cast(IDrawableEx) e;

    return result;
}

/// Обработчик комиксов.
///
final class ComixHandler(TypeString) : Instance if (isSomeString!TypeString)
{
    import rgp.core.dialog;
    import tida.graphics.gapi;

private:
    size_t comixIndex = 0;
    float[2] factorAnimation = [0.0f, 0.0f];
    bool animHandle = false;
    ubyte animStep = 0;
    bool initable = false;

    Image currentImage = null;
    Image previousImage = null;

    IShaderProgram currentShader;
    float[4][4] currentMatrix = identity();

public:
    /// Единицы комикса, которые будут листаться от начала
    /// и до конца.
    ComixUnite!TypeString[] unites;

    /// Встраиваемый текущий диалог.
    Dialog!wstring dialog;

    /// Закончился ли диалог.
    bool isDialogEnd = false;

    /// Делегат, что будет вызван при конце комикса.
    void delegate() @safe onDestroy;

    this() @safe
    {
        if (sceneManager.initable !is null)
        {
            initable = true;
        }

        depth = 4;
    }

    /// Активирует следующий элемент комикса
    void activateNext() @safe
    {
        factorAnimation = [0.0f, 0.0f];
        animHandle = true;
        if (comixIndex == 0)
            animStep = 1;
        else
            animStep = 0;

        previousImage = currentImage;
        currentImage = unites[comixIndex].image;
        currentShader = unites[comixIndex].shader;
        currentMatrix = unites[comixIndex].matrix;

        immutable offset = renderer.camera.port.begin;

        if (unites[comixIndex].text.length != 0)
        {
            dialog = new Dialog!TypeString(unites[comixIndex].text);
            dialog.font = defFont;
            dialog.width = 640 - 16;
            dialog.position = offset + vec!float(8, 320);
            dialog.borderColor = unites[comixIndex].borderColor;

            sceneManager.context.add(dialog);

            if (unites[comixIndex].choices.length != 0)
            {
                auto choice = new ChoiceDialog!TypeString(dialog);
                choice.choices = unites[comixIndex].choices;

                if (comixIndex + 1 == unites.length)
                    choice.onDestroy = &destroy;
                else
                    choice.onDestroy = &activateNext;

                sceneManager.context.add(choice);
            }
            else
            {
                if (comixIndex + 1 == unites.length)
                    dialog.onDestroy = &destroy;
                else
                    dialog.onDestroy = &activateNext;
            }

            if (unites[comixIndex].onNext !is null)
                unites[comixIndex].onNext();
        }

        comixIndex++;
    }

    @event(Destroy) void destroyEventHandle(Instance instance) @safe
    {
        if (onDestroy !is null)
            onDestroy();
    }

    @event(Init) void onInit() @safe
    {
        if (initable)
        {
            activateNext();
        }
    }

    // TODO-cComix: сделать анимацию
    // 24 мая 2022: При одинаковых карточках не делать анимации
    //              (На данный момент реализовано плавный переход)
    @event(Step) void animationHandle() @safe
    {
        import tida.animobj;

        immutable speedAnimation = 0.05f;

        if (this.animHandle)
        {
            if (animStep == 0)
            {
                factorAnimation[0] += speedAnimation;

                if (factorAnimation[0] > 1.0f)
                {
                    this.animStep = 1;
                    factorAnimation[0] = 0.0f;
                }
            }
            else if (animStep == 1)
            {
                factorAnimation[0] += speedAnimation;

                if (factorAnimation[0] > 1.0f)
                {
                    this.animStep = 2;
                    this.animHandle = false;
                }
            }

            easeInOut!3(factorAnimation[1], factorAnimation[0]);
        }
    }

    @event(Draw) void drawComix(IRenderer render) @safe
    {
        immutable offset = render.camera.port.begin;

        render.currentShader = currentShader;
        render.currentModelMatrix = currentMatrix;

        if (currentImage !is null)
        {
            if (animHandle)
            {
                render.drawEx(animStep == 0 ? previousImage : currentImage,
                        offset + vec!float(320, 240) - vec!float(currentImage.width,
                            currentImage.height) / 2, 0.0f, vecNaN!float, vecNaN!float,
                        cast(ubyte)(animStep == 0 ? (1 - factorAnimation[0]) * ubyte.max
                            : factorAnimation[0] * ubyte.max), unites[comixIndex - 1].borderColor);
            }
            else
            {
                render.drawEx(currentImage, offset + vec!float(320,
                        240) - vec!float(currentImage.width, currentImage.height) / 2,
                        0.0f, vecNaN!float, vecNaN!float, ubyte.max,
                        unites[comixIndex - 1].borderColor);
            }
        }
    }
}

import rgp.core.player : ITouching, TouchUnite;

/// Объект для перехода между сценами.
/// Взаимодействие через специальный объект.
final class TransitionObject : Instance, ITouching!wstring
{
public:
    string locationName;

    this(Vector!float position, string locationName) @safe
    {
        name = "TransitionObject";

        Image cursorImage = loader.load!Image("textures/specialCursor.png");
        if (cursorImage.texture is null)
            cursorImage.toTexture();

        mask = Shape!float.Rectangle(vec!float(0, 0), vec!float(32, 32));
        solid = true;
        tags = ["touching"];

        sprite.draws = cursorImage;

        this.position = position;
        this.locationName = locationName;
    }

override:
    TouchUnite!wstring[] touchInfo() @safe
    {
        import rgp.core.effect : effGoto;

        return [
            TouchUnite!wstring({
                effGoto(locationName).onGoto = () @safe {
                    import rgp.core.player : Player;

                    sceneManager.context.getInstanceByClass!Player.isMove = true;
                };
            })
        ];
    }
}

import rgp.core.player : Player;

/// Шаблон обновления глубины в зависимости от позиции игрока.
/// Если игрок выше заданной позиции относительно объекта, то
/// объект перекрывает игрока, иначе, игрок перекрывает объект.
///
/// Params:
///     yend = Граница перехода игрока для перекрытия.
///     up = Значение глубины, когда объект должен быть перекрыт.
///     down = Значение глубины, когда объект должен перекрывать.
///     T = Объект, от которого будет зависеть глубина объекта.
mixin template depthUpdater(float yend, int up = 11, int down = 9, T = Player)
if (isInstance!T)
{
    @event(Step) void __depthUpdate() @safe
    {
        import rgp.core.player : Player;

        auto object = sceneManager.context.getInstanceByClass!T;

        if (object.position.y + object.mask.end.y > position.y + yend)
        {
            if (depth != up)
            {
                depth = up;
                sceneManager.context.sort();
            }
        }
        else
        {
            if (depth != down)
            {
                depth = down;
                sceneManager.context.sort();
            }
        }
    }
}

void animationCallback(Animation animation, void delegate() @safe funcCallback) @safe
{
    sceneManager.context.add(new class Instance
        {
        @event(Step) void handleAnimation() @safe
        {
            if (animation.numFrame >= animation.frames.length - 1)
            {
                funcCallback(); destroy();}
            }
        }
);
    }

final class Sudden : Instance
{
public:
    Color!ubyte color;
    void delegate() @safe callback;

    float factor = 1.0f;
    float speed = 0.01f;

    this(Color!ubyte color = rgb(255, 255, 255), void delegate() @safe callback = null) @safe
    {
        this.color = color;
        this.callback = callback;
    }

    @event(Step) void handleEffect() @safe
    {
        factor -= speed;

        if (factor < speed)
        {
            if (callback !is null)
                callback();

            destroy();
        }
    }

    @event(Draw) void drawEffect(IRenderer render) @safe
    {
        render.rectangle(render.camera.port.begin, window.width,
                window.height, rgba(color.r, color.g, color.b,
                    cast(ubyte)(ubyte.max * factor)), true);
    }
}

class CameraTras : Instance
{
    Shape!float prevPort;
    float longer = 4;

    this(Duration durate, float longer = 4) @safe
    {
        prevPort = renderer.camera.port;

        listener.timer({ renderer.camera.port = prevPort; destroy(); }, durate);

        this.longer = longer;
    }

    @event(Step) void trasHandle() @safe
    {
        renderer.camera.port = Shape!(float)
            .Rectangle(prevPort.begin + uniform(-vec!float(longer,
                    longer), vec!float(longer, longer)), prevPort.end);
    }
}

class GenocideEffect : Instance
{
    import tida.graphics.gapi;

    IBuffer[4] buffer;
    IBuffer elements;

    //Pipeline pipeline;
    IShaderProgram shader;

    IVertexInfo[4] vertInfo;

    this() @safe
    {
        rebind(32f);

        foreach (size_t i, ref IVertexInfo e; vertInfo)
        {
            e = renderer.api.createVertexInfo();
            e.bindBuffer(buffer[i]);
            e.bindBuffer(elements);
            e.vertexAttribPointer([
                AttribPointerInfo(0, 2, TypeBind.Float, 6 * float.sizeof, 0),
                AttribPointerInfo(1, 4, TypeBind.Float, 6 * float.sizeof, 2 * float.sizeof)
            ]);
        }

        persistent = true;

        shader = renderer.getShader("Color");
    }

    void rebind(float factor = 32f) @trusted
    {
        immutable fcolor = rgba(30, 30, 30, 255);
        immutable scolor = rgba(30, 30, 30, 0);

        // ---

        buffer[0] = renderer.api.createBuffer();
        buffer[0].bindData(
            [
                0.0f, 0.0f, fcolor.rf, fcolor.gf, fcolor.bf, fcolor.af,
                640f, 0f, fcolor.rf, fcolor.gf, fcolor.bf, fcolor.af,
                640f, factor, scolor.rf, scolor.gf, scolor.bf, scolor.af,
                0f, factor, scolor.rf, scolor.gf, scolor.bf, scolor.af
            ]
        );

        buffer[1] = renderer.api.createBuffer();
        buffer[1].bindData(
            [
                640 - factor - 16, 0, scolor.rf, scolor.gf, scolor.bf, scolor.af,
                640, 0, fcolor.rf, fcolor.gf, fcolor.bf, fcolor.af,
                640, 480, fcolor.rf, fcolor.gf, fcolor.bf, fcolor.af,
                640 - factor - 16, 480, scolor.rf, scolor.gf, scolor.bf, scolor.af
            ]
        );

        buffer[2] = renderer.api.createBuffer();
        buffer[2].bindData(
            [
                0, 480 - factor, scolor.rf, scolor.gf, scolor.bf, scolor.af,
                640, 480 - factor, scolor.rf, scolor.gf, scolor.bf, scolor.af,
                640, 480, fcolor.rf, fcolor.gf, fcolor.bf, fcolor.af,
                0, 480, fcolor.rf, fcolor.gf, fcolor.bf, fcolor.af
            ]
        );

        buffer[3] = renderer.api.createBuffer();
        buffer[3].bindData(
            [
                0f, 0f, fcolor.rf, fcolor.gf, fcolor.bf, fcolor.af,
                factor, 0, scolor.rf, scolor.gf, scolor.bf, scolor.af,
                factor, 480, scolor.rf, scolor.gf, scolor.bf, scolor.af,
                0, 480, fcolor.rf, fcolor.gf, fcolor.bf, fcolor.af
            ]
        );

        elements = renderer.api.createBuffer(
            BufferType.element
        );
        elements.bindData([0, 1, 2, 0, 3, 2]);
    }

    @event(Draw) void onDraw(IRenderer render) @trusted
    {
        Render renderf = cast(Render) render;

        foreach (e; vertInfo)
        {
            //render.api.bindBuffer(e);
            //render.api.bindBuffer(elements);
            render.api.bindVertexInfo(e);
            render.api.bindProgram(shader);
            render.api.begin();
            
            renderf.setDefaultUniform(rgb(255, 255, 255));

            render.api.drawIndexed(ModeDraw.triangle, 6);
        }
    }
}

/// Объект для перехода между сценами.
/// Взаимодействие через специальный объект.
/// TODO-cDef: Сделать анимацию камеры перехода.
final class LocalTransition : Instance, ITouching!wstring
{
public:
    Vector!float toPos;

    this(Vector!float position, Vector!float toPos) @safe
    {
        name = "LocalTransition";

        Image cursorImage = loader.load!Image("textures/specialCursor.png");
        if (cursorImage.texture is null)
            cursorImage.toTexture();

        mask = Shape!float.Rectangle(vec!float(0, 0), vec!float(32, 32));
        solid = true;
        tags = ["touching"];

        sprite.draws = cursorImage;

        this.position = position;
        this.toPos = toPos;
    }

override:
    TouchUnite!wstring[] touchInfo() @safe
    {
        import rgp.core.effect : effGoto;

        return [
            TouchUnite!wstring({
                auto player = sceneManager.context.getInstanceByClass!Player;
                player.position = toPos;
                player.isMove = true;
            })
        ];
    }
}

auto textured(Image image) @safe
{
    if (image.texture is null)
        image.toTexture();

    return image;
}

auto drawabled(T)(T object) @safe
{
    return cast(IDrawableEx) object;
}

struct PathUnite
{
    Vecf position;
    IDrawableEx draws;

    // p/s
    float speed = 0.01f;

    void delegate() @safe onEnd;
}

final class PathMover : Component
{
    PathUnite[] unites;
    Instance instance;
    size_t uniteIndex = 0;
    float factor = 0.0f;
    float dspeed = 0.0f;
    Vecf dir;
    Vecf begin;
    float ln;

    void delegate() @safe onEnd;

    auto bindEnd(void delegate() @safe onEnd) @safe
    {
        this.onEnd = onEnd;

        return this;
    }

    this() @safe { /+ +/ }
    this(PathUnite[] unites) @safe
    {
        this.unites = unites;
    }

    void rebind() @safe
    {
        this.begin = instance.position;
        dspeed = unites[uniteIndex].speed / (unites[uniteIndex].position - instance.position).length;
        dir = pointDirection(begin, unites[uniteIndex].position).vectorDirection;
        ln = distance(unites[uniteIndex].position, begin);
    }

    bool isPlay = true;

    void stop() @safe
    {
        isPlay = false;
        factor = 0.0f;
        uniteIndex = 0;

        rebind();
        //this.begin = 
    }

    void play() @safe
    {
        isPlay = true;
    }

    void pause() @safe
    {
        isPlay = false;
    }

    void resume() @safe
    {
        isPlay = true;
    }

    void restart() @safe
    {
        stop();
        play();
    } 

    @event(Init) void onInit(Instance instance) @safe
    {
        this.instance = instance;
        this.begin = instance.position;
        dspeed = unites[uniteIndex].speed / (unites[uniteIndex].position - instance.position).length;
        dir = pointDirection(begin, unites[uniteIndex].position).vectorDirection;
        ln = distance(unites[uniteIndex].position, begin);
    }

    @event(Step) void onStep() @trusted
    {
        factor += dspeed;
        if (factor >= 1.0f)
        {
            if (unites[uniteIndex].onEnd !is null)
                unites[uniteIndex].onEnd();

            factor = 0.0f;
            uniteIndex++;

            if (uniteIndex >= unites.length)
            {
                if (onEnd !is null)
                    onEnd();
                instance.dissconnect!(typeof(this));
                return;
            }

            if (unites[uniteIndex].draws !is null)
            {
                instance.sprite.draws = unites[uniteIndex].draws;
                // avoid
            }

            rebind();
        }

        this.instance.position = begin + (dir * ln * factor);
    }
}

/// Оптимизация отрисовки объекта, чтобы не нагружать.
mixin template __optimization001(Vecf size)
{
    @event(Step) void __handle_optimization() @trusted
    {
        immutable pos = position + size;
        immutable bpos = renderer.camera.port.begin;
        immutable epos = renderer.camera.port.end;

        if  (
                (pos.x < bpos.x && pos.y < bpos.y) ||
                (position.x > epos.x && position.y > epos.y)
            )
        {
            visible = false;
        } else
        {
            visible = true;
        }
    }
}

//final class ObjectTras : Component
//{
//    Instance instance;
//    Duration dr;
//    float vl;
//    ubyte dir;
//
//    Vecf pos;
//    bool hasTmr = false;
//
//    this(Duration dr, float vl)
//    {
//        this.dr = dr;
//        this.vl = vl;
//    }
//
//    @event(Init) void onInit(Instance instance) @safe
//    {
//        this.instance = instance;
//        this.pos = instance.position;
//    }
//
//    @event(Step) void onStep() @safe
//    {
//        instance.position = pos + vecf(
//
//        if (!hasTmr)
//        {
//            listener.timer({
//                instance.dissconnect!(typeof(this))();
//            }, dr);
//            hasTmr = true;
//        }
//    }
//}
