# 来源、第三方依赖与许可

Touch-Dan 是 [Touch-Viz](https://github.com/owngoal-dev/Touch-Viz) 的独立 MIT 分支，基础提交为 `435876b232bf2584d5d2535ffa22e94b736cf32d`。根目录 [LICENSE](../LICENSE) 保留 `Copyright (c) 2024-2026 OwnGoal Studio` 及完整许可文本，没有替换为分支作者署名。

## 已核验的完整许可

下列许可于 2026-10-26 从组件各自的官方 GitHub 仓库取得并完整保存；源码文件中已有的作者与版权头同样保留。许可来源指向当时的官方分支，并不表示继承的代码或二进制就是该分支当前版本。

| 组件 | 本仓库位置 | 完整许可 | 官方来源 |
| --- | --- | --- | --- |
| LNTouchVisualizer | `TDNTouchVisualizer/`，经过重命名和适配 | [MIT](../LICENSES/LNTouchVisualizer-MIT.txt)，Leo Natan、Joe Blau | [LICENSE](https://github.com/LeoNatan/LNTouchVisualizer/blob/master/LICENSE) |
| MCEmojiPicker | `TDNPrefs/Frameworks/` 中的设备与模拟器 xcframework | [MIT](../LICENSES/MCEmojiPicker-MIT.txt)，Ivan Izyumkin | [LICENSE](https://github.com/izyumkin/MCEmojiPicker/blob/main/LICENSE) |
| SwiftUIIntrospect | `TDNPrefs/Frameworks/` 中的设备与模拟器 xcframework | [MIT](../LICENSES/SwiftUIIntrospect-MIT.txt)，Timber Software | [LICENSE](https://github.com/siteline/swiftui-introspect/blob/main/LICENSE) |
| libroot | `libroot/` 中的适配辅助源码 | [MIT](../LICENSES/libroot-MIT.txt)，Lars Fröder | [LICENSE.md](https://github.com/opa334/libroot/blob/main/LICENSE.md) |

许可文件的来源与 SHA-256 见 [license-sources.json](license-sources.json)。[NOTICE](../NOTICE) 将这些归属集中列出，不能替代完整许可文件。

## 继承的二进制依赖

MCEmojiPicker 与 SwiftUIIntrospect 的设备包包含 arm64/arm64e，模拟器包包含 arm64/x86_64。它们随上游提交继承，未重新编译。现有框架 Info.plist 只提供通用 `CFBundleShortVersionString=1.0`、`CFBundleVersion=1`；仓库缺少能将它们对应到真实源码发布版本的锁定文件，因此其精确版本和构建提交标为**未知**。

此限制同样意味着：本次补齐的是从官方项目核验的许可文本，不能仅据此声称已复现二进制的全部构建来源。发布时应保留本次继承文件的哈希，并在重新构建依赖时补充固定源码提交和工具链记录。文件位置、架构元数据及 SHA-256 见 [binary-dependencies.json](binary-dependencies.json)。

LNTouchVisualizer 和 libroot 是随 Touch-Viz 继承的源码；本分支已知 Touch-Viz 的基础提交，但未独立确认这两个内嵌源码目录原始对应的上游提交。

## 原图标与移除项

本分支沿用 Touch-Viz 的原图标，保留上游版权与 MIT 许可归属。`TDNPrefs/Resources/icon@2x.png`、`icon@3x.png` 来自上游 `TVZPrefs/Resources/`；`CCTouchDan/Resources/` 中的 `icon.png`、`icon@2x.png`、`icon@3x.png`、`SettingsIcon@2x.png`、`SettingsIcon@3x.png` 来自上游 `CCTouchViz/Resources/`。这七个实际使用的图标逐字节恢复，未重新绘制或重新编码；项目名称仍为 Touch-Dan。

README 直接引用上述设置图标。

本分支不分发专有 RevealServer，不要求下载它，也没有保留不使用的上游 Artworks 宣传素材。Apple 私有框架接口声明并不意味着本项目分发这些系统框架的实现。
