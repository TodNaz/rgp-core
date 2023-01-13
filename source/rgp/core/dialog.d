/++
Реализация диалога в игре.
+/
module rgp.core.dialog;

import tida;
import std.traits;

static immutable punctuationMarks = ";,.:!?";

/++
Объект, реализующий панель диалога.
+/
class Dialog(TypeString) : Instance if (isSomeString!TypeString)
{
    import tida.graphics.gapi;

private:
    float _cursorPosition = size_t.init;
    size_t _columnPosition = size_t.init;
    size_t previousCursorPosition = size_t.init; // Предыдущая позиция курсора,
    // при которой было завершено
    // обработка прошлой строки.

    bool isEnd = false; // Закончилось-ли продвижение текста в диалоге.

    Symbol[][] _previousRenderColums; // Результат отрендериного текста
    TypeString _currentColumn; // Значение текущей строки.
    Symbol[] _currentRenderColumn; // Значение рендера текущей строки.

    // Значения, нужные для анимации создания новой строки.
    float _prevY = float.nan;
    float _currY = 0.0f;
    float _nextY = 0.0f;
    float _factorY = float.nan;
    float _sfactorY = 0.0f;

    // Значения, нужные для анимации создания диалога и анимации его закрытия.
    bool isBeginAlphaAnim = true;
    bool isEndedAlphaAnim = false;
    bool isEndedLineAnim = false;
    float _lineFactor = 0.0f;
    float _lfactor = 0.0f;
    float alphaFactor = 0.0f;
    float endedFactor = 0.0f;
    float _distanceY = float.nan;
    ubyte alpha = 0;

    // Нужна для ускорения диалога.
    float _defaultPromotion = float.nan;
    bool isPunktuation = false;
    float defPunkt = 0.0f;

public:
    Vector!(float) defactoScale = vec!(float)(1.0f, 1.0f);

    IShaderProgram program = null;

    /++
    Текст, который будет выведен в окошке диалога.
    +/
    TypeString text;

    /++
    Скорость продвижения курсора в диалоге.
    +/
    float speedPromotion = 0.5f;

    /++
    На сколько нужно задержаться при встрече знака пунктуации или спец. символов.

    See_Also: `punctuationMarks`
    +/
    float punctValue = 3f;

    /++
    Функция, которая будет исполнена при завершении пролистывании текста диалога.
    +/
    void delegate() @safe onEnd = null;

    /++
    Функция, которая будет исполнена при закрытии диалога.
    +/
    void delegate() @safe onDestroy = null;

    Font font = null; /// Шрифт, используемый для отрисовки текста.

    Color!ubyte textColor = rgb(0, 0, 0); /// Цвет текста в диалоге.

    Color!ubyte backgroundColor = rgb(255, 255, 255); /// Цвет заднего фона

    Color!ubyte borderColor = rgb(255, 255, 255); /// Цвет боковины диалога.

    uint width = 0; /// Ширина диалогового окна.

    this(TypeString text) @safe
    {
        this.text = text;
    }

@safe:
    /++
    Позиция курсора в диалоге.

    Позиция относительна текста, но не относительна позиции с начала подстроки.
    +/
    @property size_t cursorPosition() nothrow pure inout
    {
        return cast(size_t) _cursorPosition;
    }

    /++
    Позиция курсора по строкам.
    +/
    @property size_t cursorColumnPosition() nothrow pure inout
    {
        return _columnPosition;
    }

    /++
    Ширина диалога с учётом анимации.
    +/
    @property uint height() nothrow pure
    {
        return cast(uint)(font.size * 2) + cast(uint)(_currY) + 4;
    }

    /++
    Процесс промотки текста за кадр.
    +/
    @event(Step) void promotionText() @safe
    {
        import std.algorithm : canFind;

        // Проверяем сразу на завершение, чтобы что-то не так не пошло.
        if (cursorPosition >= text.length)
        {
            if (!isEnd)
            {
                if (onEnd !is null)
                    onEnd();

                isEnd = true;
            }

            return;
        }

        // Проверяем, сейчас идёт пунктуация?
        // Если да, то замедляем пролистывание на нексколько мгновений.
        if (isPunktuation)
        {
            punctValue -= speedPromotion;

            if (punctValue <= 0)
            {
                isPunktuation = false;
                punctValue = defPunkt;
            }

            return;
        }

        _cursorPosition += speedPromotion;

        if (_cursorPosition > text.length)
            _cursorPosition = text.length;

        // Пропускаем, дабы не делать лишних движений, если курсор ещё равен
        // прошлой строке. Так-же, чтобы не было исключения при пустом массиве.
        if (cursorPosition == previousCursorPosition)
            return;

        if (cursorPosition < text.length)
            if (punctuationMarks.canFind(text[cursorPosition]))
            {
                isPunktuation = true;
                defPunkt = punctValue;
            }

        _currentColumn = text[previousCursorPosition .. cursorPosition];
        _currentRenderColumn = new Text(font).toSymbols(_currentColumn, textColor);

        if (_currentRenderColumn.widthSymbols(defactoScale) > width)
        {
            if (_currentColumn[$ - 1] != ' ')
            {
                bool isFindBreak = false;

                foreach_reverse (size_t i; previousCursorPosition .. cursorPosition)
                {
                    if (_currentColumn[i - previousCursorPosition] == ' ')
                    {
                        _previousRenderColums ~= _currentRenderColumn[0 .. i -
                            previousCursorPosition];
                        previousCursorPosition = i + 1;
                        _cursorPosition = previousCursorPosition;
                        isFindBreak = true;
                        break;
                    }
                }

                if (!isFindBreak)
                {
                    _previousRenderColums ~= _currentRenderColumn[previousCursorPosition ..
                        cursorPosition];
                    previousCursorPosition = cursorPosition;
                }
            }
            else
            {
                _previousRenderColums ~= _currentRenderColumn[previousCursorPosition ..
                    cursorPosition];
                previousCursorPosition = cursorPosition;
            }

            _nextY += font.size * 2;
            _currentRenderColumn = [];
        }
    }

    void breakAnim() @safe
    {
        isEndedAlphaAnim = true;
        _distanceY = _currY;
    }

    /++
    Процесс отслеживания ввода с устройств.
    +/
    @event(Input) void onInput(EventHandler event) @safe
    {
        import rgp.core.setting;

        // Если диалог закончился, то можно удалить диалоговое окно.
        if (keySetting.use.isDown(event))
        {
            if (isEnd)
            {
                isEndedAlphaAnim = true;
                _distanceY = _currY;
            }
        }

        // Ускорение прохода диалога.
        if (keySetting.cancel.isDown(event))
        {
            _defaultPromotion = speedPromotion;
            speedPromotion = 1.0f;
        }

        if (keySetting.cancel.isUp(event))
        {
            speedPromotion = _defaultPromotion;
            _defaultPromotion = float.nan;
        }
    }

    /++
    Обработка анимации за кадр.
    +/
    @event(Step) void handleAnimation() @safe
    {
        import tida.animobj;
        import std.math : isNaN;

        if (_currY != _nextY)
        {
            float factor = 0.0f;

            if (_prevY.isNaN)
            {
                _prevY = _currY;
            }

            if (_factorY.isNaN)
            {
                _factorY = _nextY - _currY;
            }

            _sfactorY += 0.05;
            if (_sfactorY >= 1.0f)
            {
                _currY = _nextY;
                _prevY = float.nan;
                _factorY = float.nan;
                _sfactorY = 0.0f;
                return;
            }

            easeOut!3(factor, _sfactorY);

            _currY = _prevY + (factor * _factorY);
        }

        if (isBeginAlphaAnim)
        {
            float factor;

            alphaFactor += 0.01f;
            if (alphaFactor >= 1.0f)
            {
                alpha = ubyte.max;
                isBeginAlphaAnim = false;
                return;
            }

            easeOut!3(factor, alphaFactor);

            alpha = cast(ubyte)(factor * ubyte.max);
        }

        if (isEndedAlphaAnim)
        {
            float factor;

            endedFactor += 0.05f;
            if (endedFactor >= 1.0f)
            {
                isEndedLineAnim = true;
                isEndedAlphaAnim = false;
                _currY = (_distanceY) * (1.0f - 1.0f) - ((font.size * 2 + 4) * 1.0f);
                return;
            }

            easeOut!2(factor, endedFactor);

            _currY = (_distanceY) * (1.0f - factor) - ((font.size * 2 + 4) * factor);
            alpha = cast(ubyte)(ubyte.max * (1.0f - factor));
        }

        if (isEndedLineAnim)
        {
            _lfactor += 0.05f;
            if (_lfactor >= 1.0f)
            {
                if (onDestroy !is null)
                    onDestroy();

                destroy();
                return;
            }

            easeOut!2(_lineFactor, _lfactor);
        }
    }

    /++
    Отрисовка диалогового окна.
    +/
    @event(Draw) void renderBox(IRenderer render) @safe
    {
        immutable dheight = (cast(uint)(font.size * 2) + cast(uint)(_currY) + 4) * defactoScale.y;
        render.rectangle(position,
            width,
                cast(uint) dheight, rgba(backgroundColor.r,
                    backgroundColor.g, backgroundColor.b, alpha), true);

        render.rectangle(position, 2,
                cast(uint) dheight,
                rgba(borderColor.r, borderColor.g, borderColor.b, alpha), true);

        render.line([
            position + vec!float(width / 2 * _lineFactor, 0),
            position + vec!float(width / 2 * (2.0f - _lineFactor), 0)
        ], backgroundColor);
    }

    /++
    Отрисовка текста в окне диалога.
    +/
    @event(Draw) void renderText(IRenderer render) @safe
    {
        if (isEndedLineAnim)
            return;

        immutable doff = vecf(0, font.size * 2 * defactoScale.y);
        immutable soff = 4 * defactoScale.y;

        foreach (size_t i, e; _previousRenderColums)
        {
            if (_currY >= i * (font.size * 2))
            {
                render.currentShader = program;
                render.currentModelMatrix = scaleMat(defactoScale.x, defactoScale.y);
                render.draw(
                    new SymbolRender(e),
                    position + vec!float(4, soff + i * (font.size * 2 * defactoScale.y))
                );
            }
        }

        if (_currentRenderColumn.length != 0)
        {
            if (_currY >= (_previousRenderColums.length * (font.size * 2)))
            {
                //render.currentShader = program;
                render.currentModelMatrix = scaleMat(defactoScale.x, defactoScale.y);
                render.draw(new SymbolRender(_currentRenderColumn), position + vec!float(4,
                        soff + _previousRenderColums.length * (font.size * 2 * defactoScale.y))
                );
            }
        }
    }
}

/// Создаёт диалог по умолчанию.
///
/// Params:
///     text = Текст, который нужно отобразить на панели диалога.
///     borderColor = Цвет левого края.
Dialog!(TypeString) defaultDialog(TypeString)(TypeString text, Color!ubyte borderColor) @safe
{
    import rgp.core.def : defFont;

    auto dialog = new Dialog!TypeString(text);
    dialog.font = defFont;
    dialog.width = cast(uint) (renderer.camera.port.end.x * 0.95f);
    dialog.position = renderer.camera.port.begin + vec!float(
        8,
        //256
        renderer.camera.port.end.y * 0.5
    );
    dialog.borderColor = borderColor;
    dialog.defactoScale = vecf(1.0f, 1.0f) / (vecf(640, 480) / renderer.camera.port.end);

    sceneManager.context.add(dialog);

    return dialog;
}

/++
Единица выбора в выборе.
+/
struct ChoiceUnite(TypeString) if (isSomeString!TypeString)
{
public:
    TypeString text; /// Описание выбора.
    void delegate() @safe onSelect; /// Функция, которая будет вызвана, если
    /// выберут именно данную единицу.
}

/++
Встраиваемый вариант выбора в диалоге.

Встраиваемый - значит данный объект ждём завершения
диалога, а позже - предлагает ниже его варианты
ответа, по которому он завершит панель диалога.

ПРИМЕЧАНИЕ: Нельзя в диалог встраивать делегаты,
            которые реагируют на окончании/уничтожении
            диалога! Используйте вместо этого делегат
            текущего класса `onOwnerEnd`/`onDestroy`.
+/
final class ChoiceDialog(TypeString) : Instance if (isSomeString!TypeString)
{
    alias ChoiceAnimUnit = float[2];

private:
    Dialog!TypeString dialog;
    bool isActive = false;
    ChoiceAnimUnit[] choiceAnimations;
    size_t choiceIndexAnimation = 0;

    size_t choiceCurrent = 0;

public:
    /// Делегат, что будет вызван при
    /// окончании диалога и начала
    /// выбора
    void delegate() @safe onOwnerEnd;

    /// Делегат, что будет вызван при
    /// уничтожении панели диалога
    void delegate() @safe onDestroy;

    /// Варианты ответа на выбор.
    ChoiceUnite!TypeString[] choices;

    this(Dialog!TypeString dialog) @safe
    {
        this.dialog = dialog;

        // Навешиваем на обработчики
        // свои функции для быстрой подачи
        // инфомации о конце диалога, чтобы
        // не перенагружать `шаг`.

        dialog.onEnd = () @safe {
            if (onOwnerEnd !is null)
                onOwnerEnd();

            isActive = true;
        };

        dialog.onDestroy = () @safe {
            if (onDestroy !is null)
                onDestroy();

            isActive = false;
            destroy();
        };
    }

    @event(Step) void handleAnimation() @safe
    {
        import tida.animobj;

        if (isActive)
        {
            if (choiceAnimations.length == 0)
            {
                foreach (_; 0 .. choices.length)
                    choiceAnimations ~= [0.0f, 0.0f];
            }
            else
            {
                if (choiceIndexAnimation == choiceAnimations.length)
                    return;

                choiceAnimations[choiceIndexAnimation][0] += 0.05f;

                if (choiceAnimations[choiceIndexAnimation][0] >= 1.0f)
                {
                    choiceIndexAnimation++;
                    return;
                }

                easeOut!3(choiceAnimations[choiceIndexAnimation][1],
                        choiceAnimations[choiceIndexAnimation][0]);
            }
        }
    }

    @event(Input) void handleInput(EventHandler event) @safe
    {
        import rgp.core.setting;

        if (keySetting.up.isDown(event) && choiceCurrent != 0)
        {
            choiceCurrent--;
        }

        if (keySetting.down.isDown(event) && choiceCurrent != choices.length - 1)
        {
            choiceCurrent++;
        }

        if (keySetting.use.isDown(event) && isActive)
        {
            auto choice = choices[choiceCurrent];

            if (choice.onSelect !is null)
                choice.onSelect();

            isActive = false;
        }
    }

    @event(Draw) void drawSelectUnites(IRenderer render) @safe
    {
        Vecf defactoScale = dialog.defactoScale;

        if (isActive)
        {
            immutable offset = dialog.position + vec!float(0, (dialog.height + 8) * defactoScale.y);

            foreach (i; 0 .. choices.length)
            {
                immutable factor = choiceAnimations.length <= i ? 0.0f : choiceAnimations[i][1];
                immutable choicePosition = offset + vec!float(0,
                        (8 * defactoScale.y + (dialog.font.size * 2 * defactoScale.y) * i) * factor);

                render.rectangle(choicePosition, dialog.width,
                        cast(uint)(dialog.font.size * 2 * defactoScale.y), rgb(255, 255, 255), true);

                render.currentModelMatrix = scaleMat(defactoScale.x, defactoScale.y);
                render.draw(new Text(dialog.font).renderSymbols(choices[i].text,
                        rgb(0, 0, 0)), choicePosition + vec!float(4, 0));

                if (choiceCurrent == i)
                {
                    render.line([
                        choicePosition,
                        choicePosition + vec!float(0.0f, dialog.font.size * 2 * defactoScale.y)
                    ], rgb(255, 0, 0));
                }
            }
        }
    }
}

struct DialogUnite(TypeString) if (isSomeString!TypeString)
{
    TypeString text;
    void delegate() @safe onEnd;
    Color!ubyte color = rgb(255, 255, 255);
}
