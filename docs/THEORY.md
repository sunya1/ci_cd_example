# Шейдеры и графический конвейер Flutter — теория

> Конспект к ассессменту. Каждый тезис привязан к коду в этом репозитории.

---

## 1. Rendering pipeline Flutter: от `setState` до пикселя

### 1.1 Потоки (threads / task runners)

| Поток | Что делает |
|---|---|
| **Platform** | Главный поток ОС: input, platform channels, lifecycle |
| **UI** | Dart isolate: build → layout → paint → **layer tree** |
| **Raster** | Берёт layer tree, через **Impeller** (или Skia) превращает его в команды GPU (Metal / Vulkan / OpenGL ES) |
| **IO** | Декодирование изображений, загрузка ассетов |

Кадр укладывается в бюджет, только если **каждый** из UI и Raster потоков укладывается в
`1000 / refreshRate` мс (16.6 мс на 60 Гц, 8.3 мс на 120 Гц). Потоки работают конвейером:
пока Raster рисует кадр N, UI уже строит кадр N+1.

### 1.2 Фазы кадра на UI-потоке

```
vsync ─► handleBeginFrame   (Ticker'ы, анимации — transient callbacks)
       ► handleDrawFrame
           ├─ build                  Widget → Element (dirty elements)
           ├─ layout                 RenderObject.performLayout (constraints down, sizes up)
           ├─ compositing bits       кому нужен свой Layer
           ├─ paint                  RenderObject.paint → Canvas → DisplayList (запись, не растеризация!)
           ├─ semantics
           └─ finalize → Scene (Layer tree) → engine
Raster:  LayerTree → Impeller → EntityPass → RenderPass → GPU command buffer → present
```

**Три дерева:** Widget (иммутабельная конфигурация) → Element (жизненный цикл, связь) →
RenderObject (layout + paint). Плюс четвёртое — **Layer tree**, его и получает движок.

**Важно:** `Canvas` на UI-потоке ничего не рисует. Он записывает команды в **DisplayList**.
Реальная растеризация (и выполнение шейдеров) происходит на Raster-потоке и GPU.

### 1.3 Repaint boundaries

`isRepaintBoundary = true` (или виджет `RepaintBoundary`) даёт RenderObject собственный
`OffsetLayer`. `markNeedsPaint()` поднимается вверх только до ближайшей границы. Поэтому
анимированный шейдер, перерисовываемый 120 раз в секунду, не трогает окружающий UI.

➡ В коде: `RepaintBoundary` вокруг `CustomPaint` с шейдером (`lib/src/demos/plasma_demo.dart`).

### 1.4 Как анимировать шейдер без лишней работы

```
Ticker (vsync) ─► ShaderClock.notifyListeners ─► CustomPainter(repaint: clock) → markNeedsPaint
                                                  │
                    build ✗   layout ✗   paint ✓ (только этот слой)
```

Ни одного `setState` на кадр. Uniform'ы читаются **в фазе paint**. `Ticker`, в отличие
от `Timer`, синхронизирован с vsync и сам останавливается, когда route скрыт (`TickerMode`).

➡ `lib/src/shaders/shader_clock.dart`, `PlasmaShaderPainter` в `lib/src/demos/plasma.dart`.

---

## 2. Графический конвейер GPU и shader stages

### 2.1 Классический pipeline

```
Vertex data ─► [Vertex shader] ─► Primitive assembly ─► Rasterization ─►
            ─► [Fragment shader] ─► Depth/stencil test ─► Blending ─► Framebuffer
```

- **Shader stage** — программируемый этап конвейера. Основные: **vertex** (на каждую вершину:
  трансформирует позиции) и **fragment** (на каждый фрагмент/пиксель: вычисляет цвет).
  Есть ещё compute, geometry, tessellation, но во Flutter они пользователю недоступны.
- **Rasterization** (фиксированная функция) определяет, какие пиксели покрывает примитив,
  и интерполирует varying'и для fragment-стадии.
- **Uniform** — константа на весь draw call (одинакова для всех пикселей).
- **Sampler** — текстура + правила выборки (фильтрация, wrap).

### 2.2 Что из этого доступно во Flutter

| Возможность | Как |
|---|---|
| Свой **fragment shader** | `FragmentProgram` + `.frag` — **основной путь** |
| Свой vertex shader | ❌ (только `Canvas.drawVertices` с фиксированным vertex-этапом) |
| Полный контроль над pipeline | **Flutter GPU** (`flutter_gpu`, экспериментальный, только Impeller) |

Flutter сам генерирует геометрию (например, прямоугольник в `drawRect`) и вершинный шейдер.
Наш `.frag` подключается как **fragment stage** этого draw call. Значит, стоимость шейдера
≈ **(площадь в физических пикселях) × (стоимость одного пикселя)**.

---

## 3. Тулчейн: от `.frag` до GPU

```
shaders/plasma.frag  (GLSL 4.60, подмножество)
        │  flutter build → impellerc   (во время СБОРКИ, не в рантайме)
        ▼
     SPIR-V (промежуточное представление)
        │  SPIRV-Cross
        ├─► SkSL       (Skia backend: web/legacy)
        ├─► MSL        (Impeller Metal: iOS, macOS)
        ├─► GLSL ES    (Impeller OpenGL ES: старые Android)
        └─► SPIR-V     (Impeller Vulkan: Android)
        ▼
  ассет-бандл (flatbuffer с вариантами под бэкенды + reflection uniform'ов)
        │  FragmentProgram.fromAsset('shaders/plasma.frag')
        ▼
  FragmentProgram ──.fragmentShader()──► FragmentShader ──► Paint.shader / ImageFilter.shader
```

### Про SkSL (в задании упомянут явно)

- **SkSL** — шейдерный язык Skia (диалект GLSL). Исторически `FragmentProgram` работал через
  `SkRuntimeEffect`, и `.frag` транспилировался в SkSL.
- **Shader compilation jank** в Skia: шейдеры компилировались **в рантайме при первом
  использовании** → лаг первого кадра анимации. Обходной путь — `flutter run --cache-sksl` +
  `--bundle-sksl-path` (прогрев). Хрупко: зависит от устройства и драйвера.
- **Impeller** (по умолчанию на iOS с 3.10, на Android с 3.27 — Vulkan, на старых устройствах fallback на OpenGL ES) решает проблему
  архитектурно: **все** шейдеры движка и пользовательские `.frag` компилируются **при сборке**
  (`impellerc`). Pipeline state objects создаются заранее. Прогрев SkSL больше не нужен и
  устарел.
- SkSL по-прежнему генерируется для Skia-бэкенда (web/CanvasKit, платформы без Impeller).

### Объявление в `pubspec.yaml`

```yaml
flutter:
  shaders:
    - shaders/plasma.frag
```

Ошибка в GLSL = **ошибка сборки** (impellerc), а не краш в рантайме. Hot reload
перекомпилирует шейдеры.

---

## 4. Написание `.frag` для Flutter

```glsl
#version 460 core
#include <flutter/runtime_effect.glsl>   // FlutterFragCoord()
precision highp float;

uniform vec2  uSize;      // float-индексы 0,1
uniform float uTime;      // 2
uniform vec4  uColor;     // 3..6
uniform sampler2D uTex;   // sampler-индекс 0 (отдельная нумерация!)

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  fragColor = texture(uTex, uv) * uColor;
}
```

### Правила и ограничения (частые вопросы)

1. **`FlutterFragCoord()`**, а не `gl_FragCoord`. Даёт **локальные** координаты (с учётом
   трансформации канваса), одинаково на всех бэкендах.
2. **Uniform'ы:** `float`, `vec2..4`, `mat2..4`, массивы float'ов, `sampler2D`.
   Нет `int`/`bool` uniform'ов, нет UBO/SSBO.
3. **Индексы `setFloat`** — плоские, по float-компонентам в порядке объявления
   (`vec4` = 4 слота). **Sampler'ы не считаются** и задаются через `setImageSampler(i, image)`
   со своей нумерацией с 0. Самая частая ошибка интеграции.
   ➡ В коде: индексы подписаны комментариями в `.frag` и в `PlasmaShaderPainter.paint`;
   тест `plasma.frag compiles and has the expected uniform layout` проверяет, что слотов ровно 12.
4. **Циклы** — только с константной границей (ограничение SkSL / GLSL ES 1.0). Переменное
   число итераций: `for (i < MAX) { if (i >= uN) break; }` ➡ `plasma.frag`, `uLayers`.
5. **Выход — premultiplied alpha.** `rgb ≤ a`, иначе артефакты при блендинге
   (в plasma alpha = 1, поэтому проблемы нет).
6. **Precision:** `mediump` (fp16) быстрее на мобильных GPU, но `sin(uTime)` при большом
   `uTime` начинает «ступенчато» дёргаться ➡ в `plasma.frag` поэтому `highp`.
7. **OpenGL ES** переворачивает ось Y у offscreen-текстур: в шейдерах для
   `ImageFilter.shader` нужен `#ifdef IMPELLER_TARGET_OPENGLES uv.y = 1.0 - uv.y;`.
8. Нет доступа к пикселям «под» шейдером из `Paint.shader` — для этого `ImageFilter.shader`
   / `BackdropFilter`.

---

## 5. Способы интеграции в UI

| Способ | Вход | Где в репо |
|---|---|---|
| `Paint.shader` в `CustomPainter` / своём `RenderBox` | только uniform'ы и свои текстуры | **`PlasmaShaderPainter` (используется в проекте)** |
| `setImageSampler` + `ui.Image` | картинка / `PictureRecorder` / `toImageSync` | — |
| `ImageFiltered(imageFilter: ImageFilter.shader(s))` | **отрендеренный child** (живые виджеты) | — |
| `BackdropFilter(filter: ImageFilter.shader(s))` | то, что **под** виджетом | — |
| `ShaderMask` | маска поверх child (ждёт `Shader`) | — |

**`ImageFilter.shader` (Flutter 3.29+, только Impeller):**
- первый float-uniform — `vec2` с размером входной текстуры, заполняет **движок**;
- первый `sampler2D` — отрендеренный child, тоже от **движка**;
- проверка поддержки: `ImageFilter.isShaderFilterSupported`;
- нативный фильтр **снимает копию** uniform'ов при создании, поэтому для анимации
  каждый кадр нужен новый `ImageFilter.shader(...)` (дёшево, перестраивается только обёртка,
  child передан через `ListenableBuilder.child`);
- фильтр меняет только пиксели. **Hit testing остаётся по реальному layout**: кнопки
  под эффектом работают, но при сильных искажениях визуал и зоны нажатия расходятся.

> В проекте используется только первый способ (`Paint.shader` в `CustomPainter`).
> Остальные два — теория на случай вопроса «а как применить шейдер к картинке / виджету».

---

## 6. Жизненный цикл и управление ресурсами

| Объект | Стоимость | Правило |
|---|---|---|
| `FragmentProgram` | дорогой (загрузка, pipeline) | загрузить **один раз**, кэшировать (`ShaderLibrary.preload()` до `runApp`) |
| `FragmentShader` | дешёвый, хранит буфер uniform'ов | один на painter, **переиспользовать**, `dispose()` в `State.dispose` |
| `ui.Image` для sampler | GPU-память | `dispose()` при смене размера / уходе с экрана |
| `Paint` | дешёвый | можно создавать в `paint()`; в горячих местах — держать полем |

Два одновременно живых набора uniform'ов (например, два виджета с разными цветами) требуют
**двух** `FragmentShader` от одной программы.

---

## 7. Производительность

### 7.1 Модель стоимости

```
GPU cost ≈ pixels_covered × devicePixelRatio² × (ALU ops + texture fetches) × overdraw
```

- iPhone с DPR 3: полноэкранный прямоугольник ≈ 1170×2532 ≈ **3 млн** вызовов `main()` за кадр.
- **ALU-bound:** plasma (sin/sqrt/exp). Ручка нагрузки — `uLayers`.
- **Texture-bound:** шейдеры, которые много читают из текстуры (`texture(...)`): размытие, искажения.
- **Ветвления** (`if`), зависящие от пикселя, вызывают дивергенцию warp'ов. Ветвления по
  uniform'у (одинаковые для всех пикселей) почти бесплатны.

### 7.2 Чем измерять

| Инструмент | Что показывает |
|---|---|
| **DevTools → Performance** (`--profile`) | UI vs Raster время кадра, timeline, jank |
| `MaterialApp.showPerformanceOverlay` | 2 графика: UI и Raster (кнопка в AppBar демо) |
| `SchedulerBinding.addTimingsCallback` → `FrameTiming` | build/raster/vsync в рантайме ➡ `FrameStatsMonitor` |
| `integration_test` + `watchPerformance` | автоматизированный бенчмарк, JSON-отчёт ➡ `integration_test/shader_perf_test.dart` |
| Xcode **Metal frame capture** / Instruments, **Android GPU Inspector** | реальное время GPU на draw call |

⚠ **`FrameTiming.rasterDuration` — это CPU-время Raster-потока** (кодирование команд GPU),
а не время выполнения шейдера на GPU. Тяжёлый шейдер проявится в нём, только когда GPU
перестанет успевать и начнёт тормозить raster-поток (back-pressure). Чистую стоимость
шейдера смотрим в Metal capture / AGI.

⚠ Измерения **только в `--profile` на реальном устройстве.** Debug = JIT + asserts. Симулятор
рендерит на GPU Mac'а.

### 7.3 Бенчмарк в проекте: тот же эффект на CPU и на GPU

`BenchmarkPage`: один и тот же plasma, реализованный двумя способами:
- **GPU:** 1 `drawRect` + fragment shader, каждый физический пиксель;
- **CPU:** Dart считает ту же формулу для каждой клетки N×N px и делает `drawRect` на клетку.

Результат прогона (`flutter drive`, iOS Simulator, **debug** — абсолютные цифры не
показательны, важна разница):

| сценарий | UI avg | UI p90 | Raster avg | Raster p90 | Raster max | missed raster |
|---|---|---|---|---|---|---|
| GPU, 1 layer | 1.51 | 4.03 | 0.83 | 1.08 | 1.47 | 0 |
| GPU, 8 layers | 1.43 | 3.49 | 0.86 | 1.08 | 1.68 | 0 |
| CPU, клетка 8px (~6k draw calls) | 2.73 | 3.45 | 2.82 | 3.09 | 3.49 | 0 |
| CPU, клетка 4px (~25k draw calls) | 7.33 | 7.96 | 9.59 | 13.74 | **16.80** | **9** |

Выводы:
1. GPU-вариант стоит ~константу на CPU-стороне при **любой** детализации: на UI-потоке
   это 1 команда, а не тысячи.
2. CPU-вариант растёт квадратично от разрешения (клетка 8→4 px = ×4 работы) и бьёт **оба**
   потока: UI (Dart-математика + запись DisplayList) и Raster (тысячи draw calls).
   При этом он даже не попиксельный, а в 4–8 раз грубее.
3. `GPU 1 layer ≈ GPU 8 layers` по `rasterDuration` подтверждает п. 7.2: это время CPU.
   Разницу в 8 раз по ALU видно только в GPU-профайлере или на слабом устройстве, где GPU
   упирается в лимит.

> Перед ассессментом стоит прогнать на реальном телефоне в `--profile` и подставить свои цифры.

### 7.4 Чеклист оптимизаций

- [x] Программы загружаются заранее, а не в `build` (`ShaderLibrary.preload`).
- [x] `FragmentShader` и `Paint` переиспользуются, ноль аллокаций на кадр в paint-пути.
- [x] Анимация через `markNeedsPaint`, без rebuild; `RepaintBoundary` изолирует слой.
- [x] Ticker останавливается вне экрана (`TickerMode`).
- [ ] Рендерить в меньшем разрешении и масштабировать (для размытых/процедурных фонов):
      `FlutterFragCoord` × scale, или offscreen `toImageSync` меньшего размера.
- [ ] Минимизировать площадь: шейдер только там, где нужен.
- [ ] Выносить из шейдера всё, что одинаково для всех пикселей, в uniform'ы (считать на CPU один раз).
- [ ] `mediump`, где хватает точности; меньше texture fetch'ей; избегать дивергентных ветвлений.
- [ ] Не создавать `ImageFilter`/`BackdropFilter` на большие области без нужды: это offscreen pass + доп. память.
- [ ] Учитывать 120 Гц (бюджет 8.3 мс) и thermal throttling при длительной нагрузке.

---

## 8. Вероятные вопросы на ассессменте

**В чём разница между `FragmentProgram` и `FragmentShader`?**
Program — скомпилированная программа, грузится асинхронно один раз и кэшируется движком.
Shader — экземпляр программы со своим буфером uniform'ов. Он дешёвый, его переиспользуют и
мутируют каждый кадр.

**Когда компилируется шейдер?**
`.frag` → impellerc при сборке приложения (в SPIR-V и далее в MSL/GLSL ES/SPIR-V/SkSL).
В рантайме под Impeller не компилируется ничего, под Skia SkSL компилировался драйвером при
первом использовании (отсюда jank).

**Почему jank первого кадра исчез с Impeller?**
Конечный набор шейдеров известен при сборке, pipeline'ы создаются заранее, а не при первом
draw call.

**Где во фреймворке выполняется шейдер?**
Нигде на UI-потоке. `paint()` записывает `drawRect` с `Paint.shader` в DisplayList.
Raster-поток кодирует draw call, GPU выполняет fragment stage для каждого покрытого пикселя.

**Почему `setFloat(3, …)`, если `uColor` объявлен третьим?**
Индексы считаются по float-компонентам: `vec2 uSize` занимает слоты 0 и 1, `float uTime` — 2,
`uColor` начинается с 3. Sampler'ы исключены и нумеруются отдельно.

**Как применить шейдер к произвольному виджету?**
`ImageFiltered` + `ImageFilter.shader` (Impeller). Альтернатива для Skia:
`RepaintBoundary.toImageSync()` → `setImageSampler` → рисовать в `CustomPainter`.

**Как анимировать шейдер эффективно?**
Ticker → `CustomPainter(repaint: clock)` → `markNeedsPaint`, вокруг `RepaintBoundary`. Uniform'ы
выставляются в `paint()`. Ни build, ни layout.

**Как проверить, что шейдер не тормозит?**
`--profile` на слабом реальном устройстве. DevTools: если растёт Raster, а UI нет — проблема
в рендеринге. Для чистой стоимости GPU — Metal capture / AGI. Регрессии ловить
автоматически через `integration_test` + `watchPerformance` в CI на device farm.

**Ограничения шейдеров во Flutter?**
Только fragment stage; нет int/bool uniform'ов; циклы с константными границами;
`FlutterFragCoord`; premultiplied alpha; `ImageFilter.shader` только на Impeller;
GLES y-flip; на web — только CanvasKit/Skwasm.

**Что такое Flutter GPU?**
Экспериментальный низкоуровневый API поверх Impeller (`package:flutter_gpu`): свои
vertex+fragment шейдеры, буферы, render pass'ы, 3D. Для случаев, когда fragment-only
недостаточно.
