# 素材来源与授权

> 每加一个外部素材，就在这里记一行。
> 需要署名的素材，游戏内也要有「制作人员」界面。

## BGM

| 文件 | 原曲 | 作者 | 来源 | 授权 | 需署名 |
|---|---|---|---|---|---|
| `audio/bgm/bgm_spring.mp3` | post-adventure tea party | Zane Little | [OpenGameArt](https://opengameart.org/content/10-free-chiptune-tracks-a-bag-of-chips) | CC0 1.0 | 否 |
| `audio/bgm/bgm_summer.mp3` | the world is ours | Zane Little | 同上 | CC0 1.0 | 否 |
| `audio/bgm/bgm_autumn.mp3` | stumble around | Zane Little | 同上 | CC0 1.0 | 否 |
| `audio/bgm/bgm_winter.mp3` | face the facts | Zane Little | 同上 | CC0 1.0 | 否 |
| `audio/bgm/bgm_town.mp3` | space cadet training montage | Zane Little | 同上 | CC0 1.0 | 否 |
| `audio/bgm/bgm_farm.mp3` | it takes a hero | Zane Little | 同上 | CC0 1.0 | 否 |
| `audio/bgm/bgm_mine.mp3` | sinister abode | Zane Little | 同上 | CC0 1.0 | 否 |
| `audio/bgm/bgm_festival.mp3` | 100 victories | Zane Little | 同上 | CC0 1.0 | 否 |

复用映射（不额外复制文件）：`night → bgm_winter`，`indoor → bgm_spring`。
运行时由 `AudioManager` 打开 MP3 循环；季节 / 夜晚 / 矿洞 / 节日切换带 0.8 秒淡入淡出。

## SFX

| 音效包 | 作者 | 来源 | 授权 | 需署名 |
|---|---|---|---|---|
| RPG Audio / Interface Sounds / Impact Sounds | Kenney | https://kenney.nl/assets/rpg-audio · https://kenney.nl/assets/interface-sounds · https://kenney.nl/assets/impact-sounds | CC0 1.0 | 否 |

授权原文：`audio/LICENSES/kenney_*.txt`

映射：`till`（木板）、`water`（水滴）、`plant`（轻放）、`harvest`（拨弦）、`coin`（钱币）、`error`（错误）、`ui_click`（点击）、`feed`（柔软撞击）、`sleep`（收起）、`fish_bite`/`fish_catch`（拨弦/确认）、`footstep`（草地脚步）、`storm_thunder`（低沉撞击）。

## 字体

| 字体 | 作者 | 来源 | 授权 |
|---|---|---|---|
| Fusion Pixel 12px Proportional zh_hans | TakWolf | https://github.com/TakWolf/fusion-pixel-font | SIL OFL 1.1 |

- 文件：`assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf`
- 授权原文：`assets/fonts/OFL.txt`；上游衍生字体授权：`assets/fonts/LICENSES/`
- 运行时关闭抗锯齿与亚像素定位；UI 最小字号 10px（低于此会裁切中文字形）。
- 字体缺失时回退系统字体（雅黑 / SimHei / Noto Sans CJK）。

## 美术

| 素材名 | 作者 | 来源 | 授权 |
|---|---|---|---|
| 全部世界美术 / 图标 / UI | 本项目程序化生成 | `scripts/art/PixelArt.gd`、`scripts/ui/PixelTheme.gd` | 原创 |

> 风格参考星露谷物语，但未使用、描图或复制其任何素材。
