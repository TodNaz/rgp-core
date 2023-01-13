/++
Модуль, отвечающий за настройку игры.
+/
module rgp.core.setting;

import tida.event;
import tida.vector;

/++
Описание единицы клавиши, отвечающий за какое-либо действия
+/
struct KSUnite
{
    struct AxisUnite
    {
        uint id;
        int value;
    }

private:
    bool isJoystick = false;
    bool isAxis = false;
    uint joystickButtonID = uint.init;

    bool isKeyboard = false;
    Key keyID = Key.init;

    AxisUnite axisUnite;

public:
    /++
    Тип устройства, который будет представлять ответ.
    +/
    enum Type
    {
        keyboard,
        joystick
    }

    /++
    Params:
        typeInput = Тип устройства, котоырый будет представлять ответ.
        buttonID = Кнопка, которая отвечает за действие.
    +/
    this(Type typeInput, uint buttonID) @safe nothrow pure
    {
        if (typeInput == Type.keyboard)
        {
            this.isKeyboard = true;
            this.keyID = cast(Key) buttonID;
        }
        else
        {
            this.isJoystick = true;
            this.joystickButtonID = buttonID;
        }
    }

    this(uint axisID, int axisvalue) @safe nothrow pure
    {
        this.isJoystick = true;
        this.isAxis = true;
        axisUnite = AxisUnite(axisID, axisvalue);
    }

    /++
    Проверка на то, нажата ли нужная клавиша.
    +/
    @property bool isDown(EventHandler event) @safe
    {
        if (isKeyboard)
        {
            return (event.keyDown == keyID);
        }
        else if (isJoystick)
        {
            if (isAxis)
            {
                auto js = event.joysticks[0].axless[axisUnite.id];
                if (axisUnite.value > 0)
                    return js > axisUnite.value;
                else
                    return js < axisUnite.value;
            }
            else
                return (event.joysticks[0].buttonDown == joystickButtonID);
        }
        else
            return false;
    }

    /++
    Проверка на то, отжата ли нужная клавиша.
    +/
    @property bool isUp(EventHandler event) @safe
    {
        if (isKeyboard)
        {
            return (event.keyUp == keyID);
        }
        else if (isJoystick)
        {
            if (isAxis)
            {
                auto js = event.joysticks[0].axless[axisUnite.id];
                return js == 0;
            }
            else
                return (event.joysticks[0].buttonUp == joystickButtonID);
        }
        else
            return false;
    }
}

/++
Структура действий, которые нужны для игры при вводе с устройств.
+/
struct KeySetting
{
public:
    KSUnite up; /// Действие "вверх"
    KSUnite down; /// Действие "вниз"
    KSUnite left; /// Действие "влево"
    KSUnite right; /// Действие "вправо"
    KSUnite use; /// Действие "использовать"
    KSUnite cancel; /// Действие "отменить"
    KSUnite inventory; /// Действие "открыть инвентарь"
}

/++
Клавиши по умолчанию, которые будут задействованы на действия.
+/
enum KeySetting keySettingDefault = {
    up: KSUnite(KSUnite.Type.keyboard, Key.Up),
    down: KSUnite(KSUnite.Type.keyboard,
            Key.Down),
    left: KSUnite(KSUnite.Type.keyboard, Key.Left),
    right: KSUnite(KSUnite.Type.keyboard, Key.Right),
    use: KSUnite(KSUnite.Type.keyboard,
            Key.Z),
    cancel: KSUnite(KSUnite.Type.keyboard, Key.X),
    inventory: KSUnite(KSUnite.Type.keyboard, Key.C)
};

enum KeySetting joySettingDefault = {
    up: KSUnite(1, -1),
    down: KSUnite(1, 1),
    left: KSUnite(0, -1),
    right: KSUnite(0, 1),
    use: KSUnite(KSUnite.Type.joystick, 1),
    cancel: KSUnite(KSUnite.Type.joystick, 2),
    inventory: KSUnite(KSUnite.Type.joystick, 3)
};

/// Настройка клавиш, отвечающие за действия в игре.
static KeySetting keySetting = keySettingDefault;

enum HardValues : float
{
    easy = 1.0f,
    normal = 1.25f,
    hard = 1.5f,
    impossible = 2.0f
}

/// Настройка сложности
static float hardValue = 1.0f;

static bool hasSample = true;

static uint samples = 4;