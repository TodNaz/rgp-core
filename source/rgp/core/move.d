module rgp.core.move;

import tida;
import tida.animobj;

void linear(ref float factor, immutable float k) @safe nothrow pure
{
    factor = k;
}

template isEasingFunction(alias fun)
{
    import std.traits;

    alias params = Parameters!fun;
    alias storage = ParameterStorageClassTuple!fun;

    enum isEasingFunction = isFunction!fun && isFloatingPoint!(params[0]) &&
        storage[0] == ParameterStorageClass.ref_ && isMutable!(params[1]);

}

final class MoveComponent(alias fun, bool dsc = true) : Component
{
private:
    float _speed = 0.0f;
    Vector!float _direction = vecZero!float;
    float _lengthPath = 0.0f;
    Instance object;

    float factor = 0.0f;
    Vector!float beginPosition;

public:
    /++
    Действие, которое выполнится, когда движение закончится.
    +/
    void delegate() @safe onEnd = null;

    void delegate(immutable float) @safe onMove = null;

    void reset() @safe
    {
        factor = 0.0f;
        beginPosition = object.position;
    }

    /++
    Скорость движенияя объекта.
    +/
    @property ref float speed() @safe nothrow pure
    {
        return _speed;
    }

    /++
    Направление движения объекта.
    +/
    @property ref Vector!float direction() @safe nothrow pure
    {
        return _direction;
    }

    /++
    Длина движения объекта.
    +/
    @property ref float lengthPath() @safe nothrow pure
    {
        return _lengthPath;
    }

    /++
    Направление движения объекта.
    +/
    @property float direction(float angle) @safe nothrow pure
    {
        _direction = angle.vectorDirection;

        return angle;
    }

    @event(Init) void initializeObject(Instance object) @safe
    {
        this.object = object;
        this.beginPosition = object.position;
    }

    @event(Step) void move() @safe
    {
        import rgp.core.def : fAnimSpeed;

        float sfactor;

        factor += speed * fAnimSpeed;
        if (factor > 1.0f)
        {
            if (onEnd !is null)
                onEnd();

            static if (dsc == true)
                object.dissconnect!(typeof(this));
        }

        fun(sfactor, factor);

        if (onMove !is null)
            onMove(sfactor);

        object.position = beginPosition + _direction * (_lengthPath * sfactor);
    }
}

void movTo(T)(T mov, Vector!float a, Vector!float b) @safe
{
    mov.lengthPath = distance(a, b);
    mov.direction = pointDirection(a, b).vectorDirection;
}

auto mvCmp(alias fun)(Vector!float dir, float length, float speed, void delegate() @safe onEnd = null) @safe
{
    auto mv = new MoveComponent!(fun)();
    mv.direction = dir;
    mv.lengthPath = length;
    mv.speed = speed;
    mv.onEnd = onEnd;

    return mv;
}

void smoothEdit(alias fun)(ref float value, void delegate() @safe step = null,
        void delegate() @safe onEnd = null, float spd = 0.01f) @trusted
{
    auto smoother = new class Instance
    {
        void delegate() @safe callback;
        void delegate() @safe stepback;

        float factor = 0.0f;
        float sfactor = 0.0f;
        float speed = 0.0f;
        float* ptrValue;

        void bind(ref float rValue, void delegate() @safe stepback, void delegate() @safe callback, float speed) @trusted
        {
            ptrValue = &rValue;
            this.stepback = stepback;
            this.callback = callback;
            this.speed = speed;
        }

        @event(Step) void stepSmooth() @safe
        {
            factor += speed;
            fun(sfactor, factor);
            *ptrValue = sfactor;

            if (factor <= 1.0f)
            {
                if (stepback !is null)
                    stepback();
            }
            else
            {
                if (callback !is null)
                    callback();

                *ptrValue = 1.0f;

                destroy();
            }
        }
    };

    smoother.bind(value, step, onEnd, spd);
    sceneManager.context.add(smoother);
}

void smoothEditReverse(alias fun)(ref float value, void delegate() @safe step = null,
        void delegate() @safe onEnd = null, float spd = 0.01f) @trusted
{
    auto smoother = new class Instance
    {
        void delegate() @safe callback;
        void delegate() @safe stepback;

        float factor = 1.0f;
        float sfactor = 1.0f;
        float* ptrValue;
        float speed = 0.0f;

        void bind(ref float rValue, void delegate() @safe stepback, void delegate() @safe callback, float speed) @trusted
        {
            ptrValue = &rValue;
            this.stepback = stepback;
            this.callback = callback;
            this.speed = speed;
        }

        @event(Step) void stepSmooth() @safe
        {
            factor -= speed;
            fun(sfactor, factor);
            *ptrValue = sfactor;

            if (factor > 0.0f)
            {
                if (stepback !is null)
                    stepback();
            }
            else
            {
                if (callback !is null)
                    callback();

                *ptrValue = 0.0f;

                destroy();
            }
        }
    };

    smoother.bind(value, step, onEnd, spd);
    sceneManager.context.add(smoother);
}
