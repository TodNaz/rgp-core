module rgp.core.grlib;

import grimoire;
import tida;

__gshared IEventHandler grGlobalEvent;

void evIsKeyDown(GrCall call)
{
    call.setBool (grGlobalEvent.isKeyDown());
}

void evKey(GrCall call)
{
    call.setInt32 (grGlobalEvent.key ());
}

void evMousePosition(GrCall call)
{
    GrArray!(GrReal) arr = new GrArray!(GrReal);
    arr.data = [
        grGlobalEvent.mousePosition[0],
        grGlobalEvent.mousePosition[1]
    ];

    call.setArray(arr);
}

void scCtx(GrCall call)
{
    call.setInt64(
        cast(long) cast(void*) (sceneManager.context())
    );
}

void scGName(GrCall call)
{
    Scene scene = (cast(Scene) cast(void*) call.getInt64(0));
    if (scene is null)
    {
        call.raise("It not a scene!");
        return;
    }

    call.setString(scene.name);
}

void icGName(GrCall call)
{
    Instance instance = (cast(Instance) cast(void*) call.getInt64(0));
    if (instance is null)
    {
        call.raise("It not a instance!");
        return;
    }

    call.setString(instance.name);
}

void scGList(GrCall call)
{
    Scene scene = (cast(Scene) cast(void*) call.getInt64(0));
    if (scene is null)
    {
        call.raise("It not a scene!");
        return;
    }

    GrArray!(GrInt) arr = new GrArray!(GrInt);
    foreach (ref e; scene.list())
    {
        arr.data ~= cast(GrInt) cast(void*) e;
    }

    call.setArray(arr);
}

void icSPos(GrCall call)
{
    Instance instance = (cast(Instance) cast(void*) call.getInt64(0));
    if (instance is null)
    {
        call.raise("It not a instance!");
        return;
    }

    instance.position = vecf(
        call.getReal32(1),
        call.getReal32(2)
    );
}

void icGPos(GrCall call)
{
    Instance instance = (cast(Instance) cast(void*) call.getInt64(0));
    if (instance is null)
    {
        call.raise("It not a instance!");
        return;
    }

    GrArray!(GrReal) arr = new GrArray!(GrReal);
    arr.data = [
        instance.position.x,
        instance.position.y
    ];
    call.setArray(arr);
}

void icGSpr(GrCall call)
{
    Instance instance = (cast(Instance) cast(void*) call.getInt64(0));
    if (instance is null)
    {
        call.raise("It not a instance!");
        return;
    }

    call.setInt64 (cast(long) cast(void*) instance.sprite);
}

void lrGRes(GrCall call)
{
    string np = call.getString(0);

    foreach (Resource e; loader.resources)
    {
        if (e.name != np)
        {
            if (e.path != np)
            {
                continue;
            } else
            {
                call.setInt64(cast(long) cast(void*) e.object);
                return;
            }
        } else
        {
            call.setInt64(cast(long) cast(void*) e.object);
            return;
        }
    }

    call.raise ("Unknown resource!");
}

void lrLResImg(GrCall call)
{
    string np = call.getString(0);

    Image img = loader.load!Image(np);
    call.setInt64(cast(long) cast(void*) img);
}

void imTDEx(GrCall call)
{
    Image image = cast(Image) cast(void*) call.getInt64(0);

    call.setInt64(cast(long) cast(void*) cast(IDrawableEx) image);
}

void icSSprDraw(GrCall call)
{
    Sprite sprite = cast(Sprite) cast(void*) call.getInt64(0);
    if (sprite is null)
    {
        call.raise ("It not a sprite!");
        return;
    }
    IDrawableEx idrawEx = cast(IDrawableEx) cast(void*) call.getInt64(1);
    if (idrawEx is null)
    {
        call.raise ("It not a drawEx object!");
        return;
    }
    sprite.draws = idrawEx;
}

void icGSprDraw(GrCall call)
{
    Sprite sprite = cast(Sprite) cast(void*) call.getInt64(0);
    if (sprite is null)
    {
        call.raise("It not a sprite!");
        return;
    }

    call.setInt64(cast(long) cast(void*) sprite.draws);
}

void ieTT(GrCall call)
{
    Image image = cast(Image) cast(void*) call.getInt64(0);
    image.toTexture();

    call.setInt64(cast(long) cast(void*) image.texture);
}

void umRnd(GrCall call)
{
    import std.random : uniform;

    call.setReal64(
        uniform(
            call.getReal64(0),
            call.getReal64(1)
        )
    );
}

void plCrt(GrCall call)
{
    import rgp.core.player;

    Player player = new Player();

    call.setInt64(cast(long) cast(void*) player);
}

void plGIc(GrCall call)
{
    import rgp.core.player;

    Player player = cast(Player) cast(void*) call.getInt64(0);
    
    call.setInt64(cast(long) cast(void*) cast(Instance) player);
}

void anCrt(GrCall call)
{
    Animation animation = new Animation();
    call.setInt64(cast(long) cast(void*) animation);
}

void anTDex(GrCall call)
{
    Animation animation = cast(Animation) cast(void*) call.getInt64(0);
    call.setInt64(cast(long) cast(void*) cast(IDrawableEx) animation);
}

void anSADex(GrCall call)
{
    Animation animation = cast(Animation) cast(void*) call.getInt64(0);
    GrIntArray arr = call.getIntArray(1);
    
    IDrawableEx[] drawses;
    foreach (GrInt e; arr.data)
    {
        drawses ~= cast(IDrawableEx) cast(void*) e;
    }

    animation.frames = drawses;
}

void anGADex(GrCall call)
{
    Animation animation = cast(Animation) cast(void*) call.getInt64(0);

    GrIntArray arr = new GrIntArray;
    foreach (ref e; animation.frames)
    {
        arr.data ~= cast(long) cast(void*) e;
    }

    call.setIntArray(arr);
}

void imSrp(GrCall call)
{
    Image image = cast(Image) cast(void*) call.getInt64(0);
    int x = call.getInt32(1);
    int y = call.getInt32(2);
    int w = call.getInt32(3);
    int h = call.getInt32(4);

    Image[] result = strip (image, x, y, w, h);

    GrIntArray arr = new GrIntArray;
    foreach (e; result)
    {
        arr.data ~= cast(long) cast(void*) e;
    }

    call.setIntArray(arr);
}

void imFpX(GrCall call)
{
    Image image = cast(Image) cast(void*) call.getInt64(0);

    image = flipX (image);
    call.setInt64(cast(long) cast(void*) image);
}

void imFpY(GrCall call)
{
    Image image = cast(Image) cast(void*) call.getInt64(0);

    image = flipY (image);
    call.setInt64(cast(long) cast(void*) image);
}

void plSTP(GrCall call)
{
    import rgp.core.player;

    Player player = cast(Player) cast(void*) call.getInt64(0);

    GrIntArray arr = call.getIntArray(1);
    TexturePack pack;
    pack.leftStand = cast(IDrawableEx) cast(void*) arr.data[0];
    pack.rightStand = cast(IDrawableEx) cast(void*) arr.data[1];
    pack.upStand = cast(IDrawableEx) cast(void*) arr.data[2];
    pack.downStand = cast(IDrawableEx) cast(void*) arr.data[3];
    pack.leftMove = cast(IDrawableEx) cast(void*) arr.data[4];
    pack.rightMove = cast(IDrawableEx) cast(void*) arr.data[5];
    pack.upMove = cast(IDrawableEx) cast(void*) arr.data[6];
    pack.downMove = cast(IDrawableEx) cast(void*) arr.data[7];

    player.texturePack(pack);
}

void scAic(GrCall call)
{
    Scene scene = cast(Scene) cast(void*) call.getInt64(0);
    Instance instance = cast(Instance) cast(void*) call.getInt64(1);

    scene.add (instance);
}

void scApl(GrCall call)
{
    import rgp.core.player;

    Scene scene = cast(Scene) cast(void*) call.getInt64(0);
    Player instance = cast(Player) cast(void*) call.getInt64(1);

    scene.add (instance);
}

void anSSd(GrCall call)
{
    Animation animation = cast(Animation) cast(void*) call.getInt64(0);
    animation.speed = call.getReal32(1);
}

void anSRt(GrCall call)
{
    Animation animation = cast(Animation) cast(void*) call.getInt64(0);
    animation.isRepeat = call.getBool(1);
}

__gshared
{
    GrType instanceType;
}

GrLibrary grLoadTidaLibrary()
{
    GrLibrary lib = new GrLibrary;

    // -- EVENT HANDLER --
    lib.addFunction(&evIsKeyDown, "evIsKeyDown", [], [grBool]);
    lib.addFunction(&evKey, "evKey", [], [grInt]);

    import std.traits : EnumMembers;

    foreach (e; EnumMembers!Key)
    {
        string name = e.stringof[0 .. 3] ~ "_" ~ e.stringof[4 .. $];
        lib.addVariable(name, grInt, cast(int) e, true);
    }

    // -- SCENE MANAGER --

    lib.addFunction(&scCtx, "scCtx", [], [grInt]);
    lib.addFunction(&scGName, "scGName", [grInt], [grString]);
    lib.addFunction(&icGName, "icGName", [grInt], [grString]);
    lib.addFunction(&scGList, "scGList", [grInt], [grArray(grInt)]);
    lib.addFunction(&icSPos, "icSPos", [grInt, grReal, grReal]);
    lib.addFunction(&icGPos, "icGPos", [grInt], [grArray(grReal)]);
    lib.addFunction(&evMousePosition, "evMousePosition", [], [grArray(grReal)]);
    lib.addFunction(&icGSpr, "icGSpr", [grInt], [grInt]);
    lib.addFunction(&lrGRes, "lrGRes", [grString], [grInt]);
    lib.addFunction(&lrLResImg, "lrLResImg", [grString, grString], [grInt]);
    lib.addFunction(&icSSprDraw, "icSSprDraw", [grInt, grInt]);
    lib.addFunction(&icGSprDraw, "icGSprDraw", [grInt], [grInt]);
    lib.addFunction(&ieTT, "ieTT", [grInt], [grInt]);
    lib.addFunction(&imTDEx, "imTDEx", [grInt], [grInt]);
    lib.addFunction(&umRnd, "umRnd", [grReal, grReal], [grReal]);
    lib.addFunction(&plCrt, "plCrt", [], [grInt]);
    lib.addFunction(&plGIc, "plGIc", [grInt], [grInt]);
    lib.addFunction(&anCrt, "anCrt", [], [grInt]);
    lib.addFunction(&anTDex, "anTDex", [grInt], [grInt]);
    lib.addFunction(&anSADex, "anSADex", [grInt, grArray(grInt)], []);
    lib.addFunction(&anGADex, "anGADex", [grInt], [grArray(grInt)]);
    lib.addFunction(&imSrp, "imSrp", [grInt, grInt, grInt, grInt, grInt], [grArray(grInt)]);
    lib.addFunction(&imFpX, "imFpX", [grInt], [grInt]);
    lib.addFunction(&imFpY, "imFpY", [grInt], [grInt]);
    lib.addFunction(&plSTP, "plSTP", [grInt, grArray(grInt)]);
    lib.addFunction(&scAic, "scAic", [grInt, grInt], []);
    lib.addFunction(&scApl, "scApl", [grInt, grInt], [grInt]);
    lib.addFunction(&anSSd, "anSSd", [grInt, grReal], []);
    lib.addFunction(&anSRt, "anSRt", [grInt, grBool], []);

    return lib;
}