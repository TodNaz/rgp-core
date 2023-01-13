/++
Модуль с эффектами для игры.
+/
module rgp.core.effect;

import tida;
import rgp.core.move : linear;

/++
Эффект плавного перехода из одной сцены к другой.

Params:
    fun = Функция плавности перехода. (напр. `linear`)
+/
final class EffectGoto(alias fun = linear) : Instance
{
private:
    string whereGoto;
    Color!ubyte colorEffect;
    float ffactor = 0.0f, sfactor = 0.0f;
    ubyte dir = 0;

public:
    void delegate() @safe onGoto;

    this(string whereGoto, Color!ubyte colorEffect) @safe
    {
        this.whereGoto = whereGoto;
        this.colorEffect = colorEffect;

        persistent = true;

        depth = 0;
    }

    @event(Step) void animationGoto() @safe
    {
        if (dir == 0)
        {
            ffactor += 0.01f;

            if (ffactor > 1.0f)
            {
                if (onGoto !is null)
                    onGoto();

                sceneManager.gotoin(whereGoto);
                dir = 1;

                return;
            }

            fun(sfactor, ffactor);
        }
        else
        {
            ffactor -= 0.01f;

            if (ffactor < 0.0f)
            {
                destroy();
                return;
            }

            fun(sfactor, ffactor);
        }
    }

    @event(Draw) void onDraw(IRenderer render) @safe
    {
        render.rectangle(render.camera.port.begin, window.width, window.height,
                rgba(colorEffect.r, colorEffect.g, colorEffect.b, cast(ubyte)(ubyte.max * sfactor)),
                true);
    }
}

/++
Функция плавного перехода.

Params:
    whereGoto = Название сцен.
    colorEffect = Цвет эффекта.
+/
auto effGoto(alias fun = linear)(
    string whereGoto, 
    Color!ubyte colorEffect = parseColor("#1e1e1e"),
    void delegate() @safe onEnd = null) @safe
{
    EffectGoto!(fun) effect = new EffectGoto!(fun)(whereGoto, colorEffect);
    effect.onGoto = onEnd;
    sceneManager.context.add(effect);

    return effect;
}

interface IMatrixTake
{
    ref float[4][4] matrix() @safe @property;
}

final class EffectDestroy : Component
{
    import tida.matrix;

private:
    IMatrixTake matrixes;
    Instance instance;

    float factor = 0.0f;

public:
    float speed = 0.01f;

    @event(Init) void onInit(Instance instance) @safe
    {
        this.instance = instance;
        matrixes = cast(IMatrixTake) instance;
    }

    @event(Step) void onStep() @safe
    {
        factor += speed;

        if (factor >= 1.0f)
        {
            instance.destroy();
        }

        matrixes.matrix = scaleMat(1.0f - factor, 1.0f);
    }
}

final class Otblesk : Instance
{
    float factor = 0.0f;

    @event(Step) void onStep() @safe
    {
        factor += 0.01f;

        if (factor >= 1.0f)
        {
            destroy();
        }
    }

    @event(Draw) void onDraw(IRenderer render) @safe
    {
        render.rectangle(vecfZero, 640, 480, rgba(255, 255, 255, cast(ubyte) (ubyte.max * (1.0f - factor))), true);
    }
}

// final class Blesk : Instance
// {
//     float factor = 0.0f;
//     float dfactor = 0.0f;


//     immutable(float) generic(float delta)
//     {
//         factor += delta;
//         dfactor = 2 / (delta * 0.9145 + factor);
//         if (factor > cos(PI / 4))
//             return factor / 8;
//         else
//             return factor / 2;
//     }

//     this() @safe
//     {

//     }
// }
