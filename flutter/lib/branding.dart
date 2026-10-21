// --- BRANDING: единая точка настройки оформления -----------------------------
//
// Всё, что относится к фирменному виду, собрано здесь, чтобы менять в одном месте.
//
// Ключевой принцип: если пользовательских картинок нет, клиент должен выглядеть
// РОВНО как стоковый RustDesk. Это важнее красоты: иначе при забытом файле
// получим другой цвет интерфейса, и понять причину будет трудно.
//
// Поэтому прозрачность панелей включается ТОЛЬКО когда фоновое изображение
// действительно найдено (см. brandingBackgroundReady ниже).

import 'package:flutter/foundation.dart' show FlutterError, ValueNotifier;
import 'package:flutter/services.dart' show rootBundle;

/// Фоновое изображение главного окна (светлая тема).
const kBrandingBackgroundAsset = 'assets/background.png';

/// Фоновое изображение главного окна (тёмная тема).
const kBrandingBackgroundDarkAsset = 'assets/background_dark.png';

/// Логотип. Имена совпадают с теми, что ищет стоковый RustDesk в common.dart.
const kBrandingLogoAsset = 'assets/logo.png';
const kBrandingLogoLightAsset = 'assets/logo_light.png';
const kBrandingLogoDarkAsset = 'assets/logo_dark.png';

/// Насколько плотно панели перекрывают фон (когда он есть).
/// 1.0 — фон не виден вовсе, 0.0 — текст нечитаем. Разумно: 0.60–0.85.
/// 0.72 оставляет текст читаемым и рисунок заметным.
const double kBrandingPanelOpacity = 0.72;

/// Доступно ли фоновое изображение.
/// null — ещё не проверяли; false — нет (работаем как стоковый RustDesk);
/// true — есть (включаем прозрачность панелей).
final ValueNotifier<bool> brandingBackgroundReady = ValueNotifier<bool>(false);

bool _brandingChecked = false;

/// Проверяет наличие фонового изображения один раз за запуск.
/// Вызывать до отрисовки главного экрана.
Future<void> checkBrandingBackground() async {
  if (_brandingChecked) return;
  _brandingChecked = true;
  for (final asset in [
    kBrandingBackgroundAsset,
    kBrandingBackgroundDarkAsset,
  ]) {
    try {
      await rootBundle.load(asset);
      brandingBackgroundReady.value = true;
      return;
    } on FlutterError {
      continue;
    }
  }
  brandingBackgroundReady.value = false;
}
