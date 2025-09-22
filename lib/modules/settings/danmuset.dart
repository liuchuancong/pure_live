import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/widgets/settings/settings_card_v2.dart';
import 'package:pure_live/common/widgets/settings/settings_list_item.dart';
import 'package:pure_live/common/widgets/settings/settings_switch.dart';
import 'package:pure_live/modules/settings/tmp_tab_controller.dart';

class VideoFitSetting extends StatefulWidget {
  const VideoFitSetting({super.key, required this.controller});

  final SettingsService controller;

  @override
  State<VideoFitSetting> createState() => _VideoFitSettingState(controller);
}

class _VideoFitSettingState extends State<VideoFitSetting> {
  final SettingsService controller;
  late final TabController tabController;
  late final fitmodes = {
    S.current.videofit_contain: BoxFit.contain,
    S.current.videofit_fill: BoxFit.fill,
    S.current.videofit_cover: BoxFit.cover,
    S.current.videofit_fitwidth: BoxFit.fitWidth,
    S.current.videofit_fitheight: BoxFit.fitHeight,
  };

  _VideoFitSettingState(this.controller) {
    tabController = TabController(initialIndex: controller.videoFitIndex.value, length: fitmodes.length, vsync: TmpTabController());
    tabController.addListener(tabControllerListener);
  }

  void tabControllerListener() {
    controller.videoFitIndex.value = tabController.index;
  }

  @override
  void dispose() {
    tabController.removeListener(tabControllerListener);
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsCardV2(children: [
          /// 是否在播放页面显示 弹幕
          Obx(() => SettingsSwitch(
                title: Text(S.current.settings_danmaku_open),
                value: !controller.hideDanmaku.value,
                onChanged: (bool value) => controller.hideDanmaku.value = !value,
              )),

          /// 是否 过滤 彩色 弹幕
          Obx(() => SettingsSwitch(
                title: Text(S.current.settings_danmaku_colour),
                value: controller.showColourDanmaku.value,
                onChanged: (bool value) => controller.showColourDanmaku.value = value,
              )),
        ]),
        const SizedBox(
          height: 10,
        ),
        SettingsCardV2(children: [
          /// 是否显示 用户等级
          Obx(() => SettingsSwitch(
                title: Text(S.current.show + S.current.user_level),
                value: controller.showDanmuUserLevel.value,
                onChanged: (bool value) => controller.showDanmuUserLevel.value = value,
              )),
          Obx(() => SettingsListItem(
                leading: Text(S.current.user_level),
                subtitle: Text(S.current.fans_level_danmu_format(controller.filterDanmuUserLevel.value.toInt())),
                title: Slider(
                  divisions: 10,
                  //分多少份
                  min: 0.0,
                  max: 50.0,
                  value: controller.filterDanmuUserLevel.value,
                  onChanged: (val) => controller.filterDanmuUserLevel.value = val,
                ),
                trailing: Text('${(controller.filterDanmuUserLevel.value).toInt()}'),
              )),
        ]),
        const SizedBox(
          height: 10,
        ),
        SettingsCardV2(children: [
          /// 是否显示 粉丝牌
          Obx(() => SettingsSwitch(
                title: Text(S.current.show + S.current.fans),
                value: controller.showDanmuFans.value,
                onChanged: (bool value) => controller.showDanmuFans.value = value,
              )),
          Obx(() => SettingsListItem(
                leading: Text(S.current.fans),
                subtitle: Text(S.current.fans_level_danmu_format(controller.filterDanmuFansLevel.value.toInt())),
                title: Slider(
                  divisions: 40,
                  //分多少份
                  min: 0.0,
                  max: 40.0,
                  value: controller.filterDanmuFansLevel.value,
                  onChanged: (val) => controller.filterDanmuFansLevel.value = val,
                ),
                trailing: Text('${(controller.filterDanmuFansLevel.value).toInt()}'),
              )),
        ]),
        const SizedBox(
          height: 10,
        ),
        SettingsCardV2(children: [
          /// 弹幕合并
          Obx(() => SettingsListItem(
                leading: Text(S.current.danmu_merge),
                subtitle: Text(S.current.danmu_merge_format((controller.mergeDanmuRating.value * 100).toInt())),
                title: Slider(
                  divisions: 10,
                  min: 0.0,
                  max: 1.0,
                  value: controller.mergeDanmuRating.value,
                  onChanged: (val) => controller.mergeDanmuRating.value = val,
                ),
                trailing: Text('${(controller.mergeDanmuRating.value * 100).toInt()}%'),
              )),
        ]),
        const SizedBox(
          height: 10,
        ),

        /// 比例设置
        SettingsCardV2(children: [
          SettingsListItem(
            leading: Text(S.current.settings_videofit_title),
            // subtitle: Text(S.current.fans_level_danmu_format(controller.filterDanmuFansLevel.value.toInt())),
            title: TabBar(
              controller: tabController,
              padding: const EdgeInsets.only(
                left: 10,
                right: 10,
              ),
              tabAlignment: TabAlignment.center,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: fitmodes.keys.map<Widget>((e) => Tab(text: e)).toList(),
              isScrollable: true,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.4),
                border: Border.all(color: Colors.black26),
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.transparent, Colors.black45],
                ),
              ),
            ),
            trailing: SizedBox(),
          ),
        ]),
        /*Obx(() => Visibility(
              visible: isSelected.isNotEmpty,
              child: SizedBox(
                  height: 50,
                  width: MediaQuery.of(context).size.width,
                  child: ListView(
                    controller: ScrollController(),
                    shrinkWrap: true,
                    // physics: NeverScrollableScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    children: fitmodes.keys.mapIndex((key, index) {
                      var item = fitmodes[key];
                      return Obx(() {
                        CoreLog.d(
                            "rebuild TextButton ${index} ${key} ${isSelected}");
                        return TextButton(
                          autofocus: isSelected[index],
                          child: Text(key),
                          // selectedColor: Get.theme.colorScheme.primary,
                          // shape: RoundedRectangleBorder(
                          //   borderRadius: BorderRadius.circular(8),
                          // ),
                          style: TextButton.styleFrom(
                              foregroundColor: Get.theme.colorScheme.primary,
                              overlayColor: Get.theme.colorScheme.primary,
                              shadowColor: Get.theme.colorScheme.primary,
                              // backgroundColor: Get.theme.colorScheme.secondary,
                              disabledBackgroundColor: Get.theme.disabledColor,
                              disabledForegroundColor: Get.theme.disabledColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.all(5)),
                          onPressed: () {
                            updateSelected(index);
                          },
                        );
                      });
                    }).toList(),
                  )),
            ))*/
      ],
    );
  }
}

class DanmakuSetting extends StatelessWidget {
  const DanmakuSetting({super.key, required this.controller});

  final SettingsService controller;

  @override
  Widget build(BuildContext context) {
    return SettingsCardV2(
        padding: const EdgeInsets.only(
          left: 10,
          right: 10,
        ),
        children: [
          Obx(() => SettingsListItem(
                leading: Text(S.current.settings_danmaku_area),
                title: Slider(
                  divisions: 10,
                  min: 0.0,
                  max: 1.0,
                  value: controller.danmakuArea.value,
                  onChanged: (val) => controller.danmakuArea.value = val,
                ),
                trailing: Text(
                  '${(controller.danmakuArea.value * 100).toInt()}%',
                ),
              )),
          Obx(() => SettingsListItem(
                leading: Text(S.current.settings_danmaku_opacity),
                title: Slider(
                  divisions: 10,
                  min: 0.0,
                  max: 1.0,
                  value: controller.danmakuOpacity.value,
                  onChanged: (val) => controller.danmakuOpacity.value = val,
                ),
                trailing: Text('${(controller.danmakuOpacity.value * 100).toInt()}%'),
              )),
          Obx(() => SettingsListItem(
                leading: Text(S.current.settings_danmaku_speed),
                title: Slider(
                  divisions: 15,
                  min: 5.0,
                  max: 20.0,
                  value: controller.danmakuSpeed.value,
                  onChanged: (val) => controller.danmakuSpeed.value = val,
                ),
                trailing: Text(controller.danmakuSpeed.value.toInt().toString()),
              )),
          Obx(() => SettingsListItem(
                leading: Text(S.current.settings_danmaku_fontsize),
                title: Slider(
                  divisions: 20,
                  min: 10.0,
                  max: 30.0,
                  value: controller.danmakuFontSize.value,
                  onChanged: (val) => controller.danmakuFontSize.value = val,
                ),
                trailing: Text(
                  controller.danmakuFontSize.value.toInt().toString(),
                ),
              )),
          Obx(() => SettingsListItem(
                leading: Text(S.current.settings_danmaku_fontBorder),
                title: Slider(
                  divisions: 25,
                  min: 0.0,
                  max: 2.5,
                  value: controller.danmakuFontBorder.value,
                  onChanged: (val) => controller.danmakuFontBorder.value = val,
                ),
                trailing: Text(
                  controller.danmakuFontBorder.value.toStringAsFixed(2),
                ),
              )),
        ]);
  }
}
