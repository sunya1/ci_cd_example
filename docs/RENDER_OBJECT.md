# Кастомный RenderObject — столбчатый график

> Конспект к ассессменту «Создание кастомных RenderObject для тонкого контроля рендеринга».
> Каждый тезис привязан к коду в этом репозитории.

**Что сделано:** `RenderBarChart` — свой `RenderBox`, который одним объектом рисует N столбиков с
«живыми» данными (обновляются каждый кадр) и по тапу определяет, какой столбик нажат. Тот же
график собран из обычных виджетов (`Row` + N × `Expanded`…) и замерен.

| Файл | Что внутри |
|---|---|
| `lib/src/render/bar_chart.dart` | `BarSeries` (данные), `BarChart` (виджет), `RenderBarChart` |
| `lib/src/render/row_bar_chart.dart` | `RowBarChart` — тот же график на обычных виджетах |
| `lib/src/demos/bar_chart_demo.dart` | экран: переключатель RenderObject / Row, 20…1000 столбиков, пауза данных, FPS-панель |
| `test/bar_chart_test.dart` | размер, геометрия столбиков, «данные → только paint», relayout boundary, тапы, совпадение с Row |
| `test/bar_chart_benchmark_test.dart` | быстрый замер без устройства (`flutter test`): кадр обновления и первый кадр |
| `test/bar_chart_phases_test.dart` | разбивка кадра по фазам: сколько уходит на build, layout и paint |
| `integration_test/bar_chart_perf_test.dart` | замер на устройстве в `--profile` |

---

## 1. Идея за 30 секунд

* **Layout:** ширина — сколько дал родитель, высота — тоже (или 200, если не ограничена).
  Ширина одного столбика = `ширина / N`.
* **Paint:** цикл `for` и `drawRect` для каждого столбика. Высота = значение × высота графика.
* **HitTest:** номер столбика = `x / ширина_столбика`. Одна строка арифметики.
* **Главная фишка:** данные меняются 60 раз в секунду, а график делает **только paint**:
  ни build, ни layout.

---

## 2. Теория

### 2.1 Где живёт RenderObject

```
Widget  (иммутабельная конфигурация, дешёвая, пересоздаётся на каждый build)
  │ createElement
Element (жизненный цикл, связь widget ↔ render object)
  │ createRenderObject / updateRenderObject
RenderObject (layout, paint, hitTest — долгоживущий, мутабельный)
  │ paint
Layer tree → движок (Impeller) → GPU
```

Для своего RenderObject нужны два класса:

* **виджет** (`LeafRenderObjectWidget` — без детей / `SingleChildRenderObjectWidget` /
  `MultiChildRenderObjectWidget`) — только `createRenderObject` и `updateRenderObject`;
* **render object** — вся логика.

➡ `BarChart extends LeafRenderObjectWidget` → `RenderBarChart extends RenderBox`.
Детей нет: столбики — это не виджеты, а прямоугольники на canvas.

### 2.2 Жизненный цикл RenderObject

```
createRenderObject()            ← Element монтируется
attach(PipelineOwner)           ← вошёл в дерево: подписаться на Listenable
  │
  │  ┌────────────── каждый кадр, только если «грязный» ──────────────┐
  │  │ markNeedsLayout() ─► PipelineOwner.flushLayout()  → performLayout()│
  │  │ markNeedsPaint()  ─► PipelineOwner.flushPaint()   → paint()        │
  │  └────────────────────────────────────────────────────────────────────┘
  │  hitTest() / handleEvent()  ← по событию указателя, вне кадра
  │  updateRenderObject()       ← widget пересобран: сеттеры → markNeeds*
detach()                        ← вышел из дерева: отписаться
dispose()                       ← окончательно уничтожен: освободить ресурсы
```

**Ключевая идея:** RenderObject ничего не делает «сам». Он помечает себя грязным
(`markNeedsLayout` / `markNeedsPaint`), `PipelineOwner` собирает грязные узлы и в следующем кадре
вызывает `performLayout` / `paint` только для них.

➡ В коде:
* `attach` — подписка на `BarSeries` → `markNeedsPaint`; `detach` — отписка;
* `dispose` — освобождаем `TapGestureRecognizer`;
* сеттеры помечают **ровно ту фазу, от которой зависят**:

| Что изменилось | Вызов | Почему |
|---|---|---|
| значения данных | `markNeedsPaint` | влияют только на высоту прямоугольников |
| количество столбиков | `markNeedsLayout` | меняется ширина столбика |
| выделенный столбик, цвета | `markNeedsPaint` | только пиксели |
| `onBarTap` | ничего | не влияет ни на layout, ни на paint |

### 2.3 Layout: «constraints вниз, sizes вверх, родитель задаёт позицию»

1. Родитель передаёт **constraints** (`BoxConstraints`: min/max ширина и высота).
2. Объект выбирает **size** внутри этих рамок.
3. Позицию объекта задаёт родитель.

| Метод | Когда |
|---|---|
| `performLayout()` | Основной. Обязан задать `size` (если не `sizedByParent`) и разложить детей |
| `sizedByParent` + `computeDryLayout()` | Размер зависит **только** от constraints. Размер считается в `performResize()`, а `performLayout()` делает остальное |
| `computeDryLayout()` | «Какой был бы размер при таких constraints?» — без побочных эффектов |
| `computeMin/MaxIntrinsicWidth/Height()` | «Естественный» размер. Дорого, вызывается редко |

➡ В коде:
* `sizedByParent => true`, `computeDryLayout`: ширина и высота из constraints; если высота не
  ограничена (график в `Column`) — `defaultHeight = 200`;
* `performLayout` считает только то, что зависит от размера и числа столбиков: ширину слота и
  отступ. **Значения в layout не участвуют**, поэтому смена данных layout не запускает.

**Relayout boundary.** `markNeedsLayout` поднимается вверх, пока не встретит границу. Объект —
граница, если выполнено хотя бы одно: `!parentUsesSize` · `sizedByParent` · `constraints.isTight` ·
нет родителя-RenderObject. ➡ У нас `sizedByParent`, поэтому граница (тест `is a relayout boundary`).

### 2.4 Paint

```dart
void paint(PaintingContext context, Offset offset)
```

* `offset` — где родитель разместил нас **в текущем слое**. Рисуем относительно него.
* `context.canvas` ничего не растеризует: команды записываются в DisplayList, рисует Raster-поток.
* `isRepaintBoundary => true` — свой слой: `markNeedsPaint` не выходит за его пределы. График
  перерисовывается 60 раз в секунду и не тянет за собой перерисовку остального экрана.

➡ В коде: цикл `drawRect(barRect(i).shift(offset), paint)`. `barRect(i)` — одна функция и для
paint, и для тестов, поэтому тест проверяет ровно те прямоугольники, которые рисуются.

### 2.5 HitTest и события

```
RenderBox.hitTest(result, position):
  if size.contains(position) && (hitTestChildren(...) || hitTestSelf(position)):
      result.add(this) → true
затем для каждого попавшего объекта: handleEvent(event, entry)
```

* `position` — в **локальных** координатах.
* `hitTestSelf` отвечает «да, это я». `handleEvent` получает сами события указателя.
* Отдаём pointer в `TapGestureRecognizer` (`_tap.addPointer(event)`), а не реагируем на «сырое»
  нажатие. Так график участвует в **gesture arena**: если график лежит в прокручиваемом списке и
  пользователь начал скролл, скролл выигрывает и ложного тапа не будет.

➡ В коде: `hitTestSelf => true` (весь прямоугольник наш: тап над низким столбиком выбирает его
колонку), `indexAt(position) = position.dx ~/ slot`.

### 2.6 RenderBox vs RenderSliver

| | `RenderBox` | `RenderSliver` |
|---|---|---|
| Система координат | декартова (x, y) | вдоль оси прокрутки |
| Вход | `BoxConstraints` (min/max ширина/высота) | `SliverConstraints`: `scrollOffset`, `remainingPaintExtent`, `crossAxisExtent`, `axisDirection`… |
| Выход | `Size` | `SliverGeometry`: `scrollExtent`, `paintExtent`, `layoutExtent`, `maxPaintExtent`, `hitTestExtent`… |
| Где живёт | почти везде | только внутри `Viewport` (`CustomScrollView`, `ListView`…) |
| Ленивость | все дети существуют | можно создавать детей только для видимой части |
| Примеры | `RenderPadding`, `RenderFlex`, наш `RenderBarChart` | `RenderSliverList`, `RenderSliverGrid`, `RenderSliverPersistentHeader` |
| Переход | — | `RenderSliverToBoxAdapter` (box внутри sliver), `RenderViewport` (sliver'ы внутри box) |

Когда что писать: всё, что не прокручивается или прокручивается целиком, — `RenderBox`.
Ленивые списки, «липкие» заголовки, эффекты от позиции прокрутки — `RenderSliver`.

---

## 3. Сравнение с обычными виджетами

`RowBarChart`: `ListenableBuilder` → `Row` → на каждый столбик
`Expanded → GestureDetector → FractionallySizedBox → ColoredBox`.
Внутри `GestureDetector` ещё 3 виджета, итого **7 виджетов и 4 RenderObject на столбик**
(посчитано обходом дерева: 100 столбиков = 703 виджета и 401 RenderObject).

| | **RenderObject** | **Row из виджетов** |
|---|---|---|
| Фазы на обновление данных | paint | build + layout + paint |
| Объектов на 1000 столбиков | 1 виджет, 1 RenderObject | ~7000 виджетов, ~4000 RenderObject |
| Высота по умолчанию без ограничений | да (200) | нет, нужна ограниченная высота |
| Тап | 1 recognizer, арифметика | 1000 `GestureDetector` |
| Объём кода | ~120 строк | ~35 строк |

### 3.1 Результаты — headless (`flutter test test/bar_chart_benchmark_test.dart`)

UI-поток (build + layout + paint) на одно обновление данных, область 400×800, MacBook.
Это debug/JIT с assert'ами, поэтому смотреть надо на **отношения**.

| Столбиков | RenderObject | Row | Первый кадр RenderObject | Первый кадр Row |
|---:|---:|---:|---:|---:|
| 100 | 143 µs (×1) | 1 148 µs (×8.1) | 1.1 ms | 14 ms |
| 500 | 179 µs (×1) | 4 593 µs (×25.7) | 0.4 ms | 26 ms |
| 1000 | 284 µs (×1) | 14 364 µs (×50.5) | 0.4 ms | 41 ms |

**Первый кадр** — монтирование дерева при появлении графика (или при переключении режима).
Это разовая цена, её мы видим как рывок при переключении на Row.

### 3.2 Куда уходит время: разбивка по фазам (`flutter test test/bar_chart_phases_test.dart`)

Тест выполняет фазы кадра вручную, по очереди (`buildScope`, `flushLayout`, `flushPaint`), и
засекает каждую отдельно. µs на одно обновление данных, 1000 столбиков:

| | build | layout | paint | итого |
|---|---:|---:|---:|---:|
| RenderObject | 0 | 0 | 220 | 220 |
| Row | 5 310 (69%) | 1 706 (22%) | 677 (9%) | 7 693 |

(Итог здесь меньше, чем в 3.1: тут только три фазы, а 3.1 меряет целый кадр со служебной работой
тестового движка.)

* **Row, build — главная статья (~70%).** Каждое обновление: `ListenableBuilder` → setState →
  `Row` строит заново 1000 цепочек по 7 виджетов, а Element сравнивает каждый новый виджет со
  старым и обновляет его RenderObject.
* **Row, layout (~22%).** У каждого `FractionallySizedBox` новый `heightFactor` → его
  RenderObject помечается на layout → `Row` перекладывает 1000 детей.
* **Row, paint (~9%).** Пиксели те же, но рисуются через обход 4000 RenderObject. Поэтому даже
  paint у Row в 3 раза дороже нашего.
* **RenderObject:** build и layout — ноль, их нет. Остаётся один цикл `drawRect`. Время почти не
  растёт: 100 → 1000 столбиков дают 143 → 284 µs (3.1).
* На 1000 столбиков Row тратит ~14 мс на кадр: почти весь бюджет 60 Гц (16.6 мс), и это ещё
  без растеризации.
* **Цена:** кода больше, и корректность layout, paint и hitTest на нас. Поэтому свой
  RenderObject оправдан для «тяжёлых» вещей: графики, диаграммы, большие сетки, кастомные
  редакторы. Для обычной формы хватит виджетов.

### 3.3 Реальные цифры — profile-режим (macOS)

Симуляторы и эмуляторы profile-режим не поддерживают, поэтому замер сделан на macOS как на
десктопе (Apple Silicon, экран 120 Гц, бюджет кадра 8.3 мс):

```bash
flutter drive --profile -d macos \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/bar_chart_perf_test.dart
```

5 секунд на сценарий, ~600 кадров, мс:

| Сценарий | UI avg | UI p90 | UI max | Raster avg | Пропущено кадров |
|---|---:|---:|---:|---:|---:|
| RenderObject, 200 | 0.19 | 0.34 | 1.43 | 0.54 | 0 |
| Row, 200 | 0.89 (×4.7) | 1.66 | 4.21 | 0.53 | 0 |
| RenderObject, 1000 | 0.38 | 0.67 | 1.29 | 1.47 | 0 |
| Row, 1000 | 2.80 (×7.4) | 3.35 | 6.31 | 1.28 | 0 |

Что из этого следует:

* **UI-поток (build + layout + paint):** Row в 5–7 раз дороже, и разрыв растёт с числом
  столбиков. Это подтверждает debug-замеры, но разница меньше: в debug build особенно сильно
  замедлен assert'ами, поэтому там было ×50.
* **Raster примерно одинаковый** (1.3–1.5 мс на 1000): на экране одни и те же прямоугольники,
  а GPU-сторону наш RenderObject не ускоряет. Он экономит именно работу UI-потока.
* **На мощном Mac обе версии укладываются в кадр.** Худший кадр Row на 1000 столбиков — 6.3 мс
  при бюджете 8.3 мс, запас уже небольшой. Телефон в разы слабее, поэтому для отчёта лучше
  повторить этот же замер на реальном устройстве (`-d <id телефона>`).

Чтобы потрогать руками: `flutter run --profile -d macos` → «Bar chart», на панели FPS те же цифры.

### 3.4 Как сравнивать самому (на экране демо)

1. Запускать в `--profile` на телефоне или на macOS: `flutter run --profile -d macos`. В debug всё медленнее в
   разы (JIT, assert'ы), и на панели горит предупреждение.
2. Поставить **500–1000 столбиков**. На 100 обе версии укладываются в кадр, разница видна только
   в цифрах.
3. Переключить режим и **подождать 2–3 секунды**. Сразу после переключения будет рывок: Row
   монтирует тысячи виджетов (~41 мс на 1000 столбиков, см. «первый кадр»). Это разовая цена,
   а не цена каждого кадра. Панель сама отбрасывает первые 60 кадров после переключения
   (`FrameStatsMonitor.reset(skipFrames: 60)`), иначе этот рывок искажал бы среднее.
4. Сравнивать строку **UI** (avg) и **jank %**. Raster у обеих версий почти одинаковый: на экране
   одни и те же прямоугольники. Вся разница — в build и layout на UI-потоке.
5. Кнопка «пауза» останавливает данные: обе версии перестают работать совсем. Это показывает,
   что вся нагрузка — от обновления данных.

Для отчёта удобнее автоматический замер (`flutter drive …` выше): там есть прогрев 1 секунду,
5 секунд замера и одинаковые условия для всех сценариев.

---

## 4. Тесты (`test/bar_chart_test.dart`)

| Тест | Что доказывает |
|---|---|
| `fills bounded constraints` | размер = constraints |
| `uses the default height when height is unbounded` | в `Column` высота 200 |
| `bar rectangles follow width, count and values` | точная геометрия столбиков |
| `is a relayout boundary` | `markNeedsLayout` не уходит к родителю |
| `repaint only: no rebuild, no layout` | новые данные → только paint, виджет не пересобирается |
| `a different bar count triggers layout` | смена количества → layout |
| `tap on a bar reports its index` | тап через gesture arena возвращает нужный индекс |
| `tap above a short bar selects its column` | вся колонка кликабельна |
| `indexAt maps positions to columns` | границы колонок, тапы вне графика → null |
| `RenderObject and Row draw the same bars` | обе реализации рисуют одно и то же (40 прямоугольников) |
| `demo page animates` × 2 | экран работает в обоих режимах |

Тест «только paint» проверен на поломку: если подписать данные на `markNeedsLayout`, он падает.

---

## 5. Шпаргалка для защиты

* **Зачем свой RenderObject, если есть виджеты?** Когда элементов много и они часто меняются:
  тысяча виджетов-столбиков — это тысячи объектов на каждый кадр, а один RenderObject — один цикл
  `drawRect`.
* **Почему данные обновляются без `setState`?** RenderObject сам слушает `BarSeries` и вызывает
  `markNeedsPaint`. Build и layout пропускаются.
* **Почему значения не участвуют в layout?** Размер графика и ширина столбиков от значений не
  зависят. Высота столбика — это уже рисование, поэтому она считается в paint.
* **Зачем `sizedByParent`?** Размер зависит только от constraints. Это делает объект relayout
  boundary.
* **Зачем `isRepaintBoundary`?** График перерисовывается 60 раз в секунду. Свой слой не даёт этим
  перерисовкам задевать остальной экран.
* **Почему `TapGestureRecognizer`, а не просто `PointerDownEvent`?** Чтобы участвовать в gesture
  arena и не ловить ложные тапы при скролле.
* **Зачем `dispose`?** Освободить recognizer. Это последний шаг жизненного цикла.
* **Чем RenderSliver отличается от RenderBox?** Другой протокол: на входе `SliverConstraints`
  (сколько прокручено и сколько места осталось), на выходе `SliverGeometry`, а не `Size`.
  Живёт только во `Viewport` и умеет ленивых детей.
