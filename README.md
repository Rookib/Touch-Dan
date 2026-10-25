# Touch-Dan

<img src="TDNPrefs/Resources/icon@3x.png" width="87" height="87" alt="Touch-Dan，沿用 Touch-Viz 原图标">

Touch-Dan 是面向 iOS 的中文触摸可视化插件，用触点与轨迹说明点击、拖动和录屏操作。它是 [OwnGoal Studio / Touch-Viz](https://github.com/owngoal-dev/Touch-Viz) 的独立 MIT 分支，保留上游版权与第三方许可，不代表上游官方版本。

**这是注入 SpringBoard 的系统插件，需要匹配的越狱环境。** 提供 RootHide 隐根版和普通 rootless 无根版。隐根版已在 iOS 16.0.2 真机验证安装、加载、设置共享和文件落点；无根版已通过构建及安装包检查，尚未真机验证。iOS 17、长时间使用与完整录屏场景仍待验证。

项目：[Rookib/Touch-Dan](https://github.com/Rookib/Touch-Dan) · 包名：`io.github.suckdrygod.touchdan` · 开发版本：`0.1.0`

## 下载安装包

从 [GitHub Releases](https://github.com/Rookib/Touch-Dan/releases) 下载适合当前越狱环境的一个包。文件名中的架构后缀用于区分安装方案，请按越狱环境选择。

| 安装包 | 适用环境 | 验证状态 |
| --- | --- | --- |
| `Touch-Dan_0.1.0_roothide_iphoneos-arm64e.deb` | RootHide 隐根 | iOS 16.0.2 安装、加载与目录核验通过 |
| `Touch-Dan_0.1.0_rootless_iphoneos-arm64.deb` | 普通 rootless 无根 | 构建及包检查通过，未真机验证 |

无根包使用 `/var/jb` 安装布局和普通偏好域，不提供 RootHide 的隐根隔离保证。控制中心按钮需要兼容的 CCSupport；该按钮的完整交互仍待验证。发布附件中的 `SHA256SUMS.txt` 可用于核验下载文件。

## 本分支的调整

- 使用 Touch-Dan 名称与独立设置域，保留 Touch-Viz 原图标及来源致谢。
- 中文设置与三个演示预设；总开关默认关闭，预设可继续微调。
- RootHide 版将图片、设置与图片暂存定位到当前隐根；解析失败停止写入，不使用真实 `/var/tmp`。
- 修复触点结束/取消后的活动状态、禁用时的轨迹与动画清理，以及录屏/便捷访问恢复后的效果状态；主机逻辑与文件操作检查通过，完整交互场景仍需继续验证。
- 补齐完整第三方许可，移除专有 RevealServer 和不使用的上游宣传素材。
- 保留手动构建入口；GitHub Actions 仅提供未验证的可选模板，不自动发布。

三个预设参数如下。具体测试范围见 [验证说明](docs/TESTING.md)。

| 预设 | 触点与轨迹 | 显示方式 |
| --- | --- | --- |
| 清晰触点 | 26 pt 青色触点，2 pt 边框，透明度 0.85，无轨迹 | 日常点击演示 |
| 演示轨迹 | 28 pt 蓝色触点，2 pt 边框，透明度 0.85，笔刷轨迹，0.5 秒动画 | 连续拖动与滑动演示 |
| 录屏讲解 | 30 pt 青色触点，2.5 pt 边框，透明度 0.9，跟随轨迹，0.4 秒动画 | 仅录屏时显示 |

预设保留总开关与已保存图片，关闭图片及变形效果；默认采用清晰触点样式。测试范围见 [验证说明](docs/TESTING.md)。

## 手动构建

需要 macOS、Xcode、Theos 和私有框架链接声明。脚本通过 `xcrun` 选择与当前 Xcode 编译器匹配的公开 iPhoneOS SDK；Theos 下的 `iPhoneOS16.5.sdk` 仅用于提供私有框架及旧 UIKit Swift 覆盖层的链接声明。当前最低部署目标是 iOS 16.0，设备架构为 arm64 / arm64e。继承的 Swift 二进制依赖版本尚未溯源，具体限制见 [第三方说明](docs/THIRD_PARTY.md)。

默认构建 RootHide 隐根版：

```sh
# RootHide，默认使用 $HOME/theos-roothide
./devkit/build.sh roothide
```

自定义 Theos 路径：

```sh
THEOS="/path/to/theos-roothide" ./devkit/build.sh roothide
```

产物写入 `packages/`。这些命令执行 `make clean package`，不安装到设备。构建普通无根版时使用 `./devkit/build.sh rootless`；源码另保留 rootful 选项。隐根存储要求仅由 RootHide 方案提供，不能仅凭编译通过判断系统兼容。详细环境、版本及 CI 模板说明见 [构建指南](docs/BUILD.md)。

包声明与原 Touch-Viz 的 `com.82flex.touchvis` 冲突，避免两套系统触摸覆盖同时启用。构建命令不执行设备安装或自动发布。

## 来源与许可

基础提交为 [`435876b232bf2584d5d2535ffa22e94b736cf32d`](https://github.com/owngoal-dev/Touch-Viz/commit/435876b232bf2584d5d2535ffa22e94b736cf32d)。根目录 [LICENSE](LICENSE) 保留 OwnGoal Studio 的原始 MIT 许可，完整归属见 [NOTICE](NOTICE)。

感谢 [Leo Natan / LNTouchVisualizer](https://github.com/LeoNatan/LNTouchVisualizer)、Joe Blau、[Ivan Izyumkin / MCEmojiPicker](https://github.com/izyumkin/MCEmojiPicker)、[Timber Software / SwiftUIIntrospect](https://github.com/siteline/swiftui-introspect) 和 [Lars Fröder / libroot](https://github.com/opa334/libroot)。完整许可已收入 [LICENSES](LICENSES)，获取来源与未知版本项见 [第三方说明](docs/THIRD_PARTY.md)。
