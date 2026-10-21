import 'dart:async' show scheduleMicrotask;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_hbb/branding.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/desktop_home_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/desktop/widgets/tabbar_widget.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';
// import 'package:flutter/services.dart';

import '../../common/shared_state.dart';

class DesktopTabPage extends StatefulWidget {
  const DesktopTabPage({Key? key}) : super(key: key);

  @override
  State<DesktopTabPage> createState() => _DesktopTabPageState();

  static void onAddSetting(
      {SettingsTabKey initialPage = SettingsTabKey.general}) {
    try {
      DesktopTabController tabController = Get.find<DesktopTabController>();
      tabController.add(TabInfo(
          key: kTabLabelSettingPage,
          label: kTabLabelSettingPage,
          selectedIcon: Icons.build_sharp,
          unselectedIcon: Icons.build_outlined,
          page: DesktopSettingPage(
            key: const ValueKey(kTabLabelSettingPage),
            initialTabkey: initialPage,
          )));
    } catch (e) {
      debugPrintStack(label: '$e');
    }
  }
}

class _DesktopTabPageState extends State<DesktopTabPage> {
  final tabController = DesktopTabController(tabType: DesktopTabType.main);

  _DesktopTabPageState() {
    RemoteCountState.init();
    Get.put<DesktopTabController>(tabController);
    tabController.add(TabInfo(
        key: kTabLabelHomePage,
        label: kTabLabelHomePage,
        selectedIcon: Icons.home_sharp,
        unselectedIcon: Icons.home_outlined,
        closable: false,
        page: DesktopHomePage(
          key: const ValueKey(kTabLabelHomePage),
        )));
    if (bind.isIncomingOnly()) {
      tabController.onSelected = (key) {
        if (key == kTabLabelHomePage) {
          windowManager.setSize(getIncomingOnlyHomeSize());
          setResizable(false);
        } else {
          windowManager.setSize(getIncomingOnlySettingsSize());
          setResizable(true);
        }
      };
    }
  }

  @override
  void initState() {
    super.initState();
    // HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  /*
  bool _handleKeyEvent(KeyEvent event) {
    if (!mouseIn && event is KeyDownEvent) {
      print('key down: ${event.logicalKey}');
      shouldBeBlocked(_block, canBeBlocked);
    }
    return false; // allow it to propagate
  }
  */

  @override
  void dispose() {
    // HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    Get.delete<DesktopTabController>();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // --- BRANDING: фон главного окна ----------------------------------------
    // Фон рисуется как decoration контейнера, а DesktopTab остаётся ЕДИНСТВЕННЫМ
    // ребёнком. Так дерево виджетов и layout не меняются вовсе — в отличие от
    // Stack, который мог бы повлиять на ограничения и на раскладку.
    // Scaffold делаем прозрачным, иначе он перекроет рисунок.
    // Если картинки нет, decoration пустой, а backgroundColor возвращается к
    // обычному цвету темы — вид совпадает со стоковым RustDesk.
    final tabWidget = _BrandingBackground(
      child: Scaffold(
          // Прозрачный, иначе перекроет фоновый рисунок.
          backgroundColor: Colors.transparent,
          body: DesktopTab(
            controller: tabController,
            tail: Offstage(
              offstage: bind.isIncomingOnly() || bind.isDisableSettings(),
              child: ActionIcon(
                message: 'Settings',
                icon: IconFont.menu,
                onTap: DesktopTabPage.onAddSetting,
                isClose: false,
              ),
            ),
          )),
    );
    return isMacOS || kUseCompatibleUiMode
        ? tabWidget
        : Obx(
            () => DragToResizeArea(
              resizeEdgeSize: stateGlobal.resizeEdgeSize.value,
              enableResizeEdges: windowManagerEnableResizeEdges,
              child: tabWidget,
            ),
          );
  }
}

// --- BRANDING: фон главного окна ---------------------------------------------
// Рисует фоновое изображение как decoration контейнера и кладёт сверху child.
// Это НЕ меняет структуру дерева виджетов: снаружи тот же единственный ребёнок,
// поэтому раскладка не может поехать (в отличие от Stack).
// Если картинки нет — используется цвет темы, и вид совпадает со стоковым.
class _BrandingBackground extends StatefulWidget {
  const _BrandingBackground({required this.child});

  final Widget child;

  @override
  State<_BrandingBackground> createState() => _BrandingBackgroundState();
}

class _BrandingBackgroundState extends State<_BrandingBackground> {
  final Map<Brightness, Future<String?>> _futures = {};

  Future<String?> _resolve(Brightness brightness) async {
    final candidates = brightness == Brightness.dark
        ? [kBrandingBackgroundDarkAsset, kBrandingBackgroundAsset]
        : [kBrandingBackgroundAsset];
    for (final asset in candidates) {
      try {
        await rootBundle.load(asset);
        return asset;
      } on FlutterError {
        continue;
      }
    }
    return null;
  }

  Future<String?> _futureFor(Brightness brightness) =>
      _futures.putIfAbsent(brightness, () => _resolve(brightness));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Базовый цвет — тот же, что был у Scaffold до правки. Это гарантирует,
    // что при отсутствии картинки интерфейс выглядит как стоковый.
    final fallbackColor = theme.colorScheme.background;

    return FutureBuilder<String?>(
      future: _futureFor(theme.brightness),
      builder: (context, snapshot) {
        final asset = snapshot.data;
        // Сообщаем панелям, есть ли рисунок: они включают прозрачность только
        // когда он реально есть. Иначе вид остаётся стоковым.
        // Планировщик — потому что менять ValueNotifier нельзя во время build.
        final hasBg = asset != null;
        if (brandingBackgroundReady.value != hasBg) {
          scheduleMicrotask(() {
            brandingBackgroundReady.value = hasBg;
          });
        }
        return Container(
          decoration: BoxDecoration(
            color: fallbackColor,
            image: asset == null
                ? null
                : DecorationImage(
                    image: AssetImage(asset),
                    fit: BoxFit.cover,
                    // Если файл вдруг повреждён — просто не рисуем его.
                    onError: (exception, stackTrace) {},
                  ),
          ),
          child: widget.child,
        );
      },
    );
  }
}
