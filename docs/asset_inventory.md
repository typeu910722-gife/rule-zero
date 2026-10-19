# 素材盤點（2026-10-19）

範圍：`game/art`、`game/audio`、`game/fonts`、`docs/art`（不含 `.import`）。只讀檢查，未改任何檔案。
方法：PIL 讀尺寸；md5 比對重複；依 `game/scripts` 的路徑規則（含動態組檔名）模擬引用；對照 `docs/chapter2_asset_requests.txt`、`docs/vendor/*`。

---

## 0. 總覽

| 項目 | 數字 |
|---|---|
| 遊戲內素材檔（不含 .import） | **609**（圖 407、音 200、字型 2）；全部有對應 `.import`，沒有漏匯入 |
| 概念圖 `docs/art` | 9 張 jpg（1536×1024）＋ README，3.4 MB |
| `game/` 原始素材大小 | art 68 MB、audio 8.6 MB、fonts 0.7 MB（`.godot/` 匯入快取 36 MB，已 gitignore） |
| 網頁版輸出 `public/` | 67 MB（`index.pck` 33.7 MB、`index.wasm` 35.4 MB，皆切成 2 段） |
| git pack | 205.6 MB（含歷史） |
| 第一章正式美術／音樂 | **0**（全部程式繪製／合成） |
| 第二章外包交付 vs 需求清單 | 需求項目**全部有檔案**；第二批驗收已通過，剩「不急」的品質項 |
| 程式從未用到的檔案 | **約 82 張圖 + 4 個 BGM 檔 + 105 個 SE 檔（35 種音效）** |
| 程式引用但檔案不存在 | **0**（`@bg train`／`dream` 本來就是純色底） |

---

## 1. 素材清單（依分類）

| 分類 | 路徑 | 檔數 | 大小 | 尺寸 | 格式 / Godot 匯入 |
|---|---|---|---|---|---|
| 地圖＋時段 | `art/ch2/backgrounds/ch2_bg_town_*` | 8 | 1.9 MB | 1600×1150 | 4 jpg（day/evening/night/negative）＋4 透明疊圖 png |
| 室內背景 BG | `art/ch2/backgrounds/` | 15 | 3.1 MB | 1280×720 | jpg；有損 WebP |
| CG | `art/ch2/cg/` | 35 | 6.2 MB | 1280×720 | 29 jpg＋6 png（文字疊圖）；有損 |
| CG-20 分層 | `art/ch2/cg/ending_layers/` | 11 | 0.6 MB | 1280×720 | png RGBA；有損 |
| 立繪 | `art/ch2/characters/portraits/` | 91 | **36.2 MB** | 全部 512×768 | png RGBA；有損 WebP（匯入後約 6.5 MB） |
| 地圖小人 | `art/ch2/characters/sprites/` | 32 | 6.4 MB | 160×160～1536×832 | png；無損 |
| 小遊戲 | `art/ch2/minigames/<9 組>/` | 169 | 6.9 MB | 40×40～1280×720 | png；35 有損／134 無損 |
| UI | `art/ch2/ui/` | 46 | 3.4 MB | 128×128～1280×720 | png；11 有損／35 無損 |
| BGM | `audio/ch2/bgm/` | 17 | 4.7 MB | — | ogg（循環由程式設定 `loop`） |
| SE | `audio/ch2/se/` | 183 | 2.6 MB | — | ogg 單聲道；61 種 × 3 變化版 |
| 字型 | `fonts/` | 2 | 0.65 MB | — | `NotoSansTC-Game.otf`（子集）＋`OFL.txt` |
| 概念圖 | `docs/art/` | 9 | 3.4 MB | 1536×1024 | jpg（00 地圖、01 小布、02 鎮長、03 露露、04 Fen、05 波波、06 鏡中的孩子、07 麻糬、08 小玉） |

### 1-1 立繪（每角色張數；檔名 `ch2_<id>_portrait_<狀態>_<表情>.png`）

| id | 角色 | 張數 | 狀態／表情 |
|---|---|---|---|
| baimian | 白面 | 8 | a × default/blank/scorn/realsmile/still/faraway、notail_default、default（=a_default 重複） |
| xiaoji | 小棘 | 14 | a×5、bald×4、onequill×2、white_hollow、tied_default、default（重複） |
| tiaoma | 條碼 | 14 | s3/s2/s1 × default/blurt/washed、s0/s0mark × default/last、default（重複） |
| gaga | 嘎嘎 | 7 | a × default/write/closed、unsewn × silent/closed、project_default、default（重複） |
| zhongzhong | 重重 | 6 | a × shiver/shocked/candy/whisper/hold、default |
| youyou | 鼬鼬 | 10 | a×5、nothread×3、broken_wink、default（重複） |
| dove | 和平鴿 | 10 | a × default/tilt/lean/up/turn、cracked_default、back、crouch、hug、default（重複） |
| conductor | 車掌 | 3 | stand、back、photo |
| lulu / mochi / popo | 露露／麻糬／波波 | 3 / 4 / 3 | 依需求 E-9 |
| pip | 小布 | 4 | default、ring、marks、scared |
| staff / mechbird | 職員／機械鳥 | 2 / 3 | stand、carry／front、side、stopped |

### 1-2 地圖小人（`sprites/`，32 張）
白面 sheet(320²)/stand/notail；小棘 sheet/stand/bald/onequill/white；條碼 sheet/s3/s2/s1/s0；嘎嘎 sheet/unsewn；重重 sheet(416²)/stand/shiver；鼬鼬 sheet(640²)/nothread/crawl；和平鴿 sheet(1536×832)/cracked/clap/unmasked；小布 walk/walk_marks(640²)；車掌 stand；露露/麻糬/波波 wave；職員 walk(1152×1248, 1.0 MB)。

### 1-3 背景與 CG
- BG：train_grey、platform、platform_negative、classroom、dining、laundry、treatment、treatment_window、dorm_night、office、fence、incinerator、graduation、ending_grey、ending_color。
- 地圖疊圖：graduation_overlay、train_overlay、incinerator_closed、clinic_overlay。
- CG-01～20 全有；另有 cg01 stitch_01～04、cg02 ticket_ending、cg18 faceless，以及 `_blank`（無字底圖）／`_text_overlay`（字層）共 11 張變體。

### 1-4 小遊戲（9 組）

| 資料夾 | 檔數 | 大小 | 內容 |
|---|---|---|---|
| apology | 25 | 384 KB | 音符×3、判定圈、軌道、愛心計 0–4、進度條 00–04、按鈕×3、貼紙×3（+無字）、重重被電 |
| scrub | 26 | 1.4 MB | 條碼 base/full、斑紋×3、泡泡×4、破洞×3、棉花×2、星星、按鈕×3、洗衣板、刷子、夾子、貼紙 |
| find_odd | 6 | 172 KB | normal/camera/redthread/stare、選擇框、計時 |
| hold_endure | 13 | 696 KB | 椅子、和平鴿、金屬環、按鈕×3、進度條×5、白霧、小布坐姿 |
| sneak | 8 | 804 KB | 和平鴿 back/turn_hint/front、大衣、小布躡腳×4 |
| confession | 13 | 1.4 MB | 小棘褪色×5、卡片 front/back/flip、喊聲×3、貼紙 |
| trim | 23 | 748 KB | 小棘 base、刺×12、剪刀×2、笑容計＋指針、棉花×2、閃光、信（+無字/字層） |
| chairs | 40 | 716 KB | 椅子、音樂盒、和平鴿打拍×2、6 人走路各 4 格（小棘另有 bald/onequill）、貼紙 |
| restuff | 15 | 1.0 MB | 桌布、步驟面板＋①～④、小棘肚子、黑/白棉花各 3、針線、回憶照片 |

### 1-5 UI（46 張）
UI-01 對話框＋名字牌；UI-02 操行成績單；UI-03 守則板＋滴墨；UI-04 點名簿＋塗黑；UI-05 HUD＋星星亮/暗；UI-06 日記；UI-07 結算框＋去向圖示×4；UI-08 名牌 6 人×3 狀態＋白色戳章；UI-09 章節卡（第二、三章，各有無字版）；UI-10 顏色碎片×4；UI-11 心形標誌×3（badge/line/stamp）。

### 1-6 BGM（17 檔）與 SE（183 檔）
- BGM：01 bleach_town、02 evening、03 far_shore、04 dove、05 correction_time、06 apology、07 chairs、07 chairs_stop、08 night、09 humming、10 nirvana、11 memory、12 graduation、13 escape、14 next_stop、15 special_love、16 dream。
- SE（每種 3 版 `_01～_03`）：

| 類別 | 編號 | 檔數 | 大小 |
|---|---|---|---|
| 系統 | se01–07（text、cursor、confirm、conduct_up/down、rule_break、paper、save、title_card） | 27 | 235 KB |
| 環境 | se10–16（ambience、fence_hum/off、river、chime、broadcast、negative_hum、monitor_beat/flat） | 27 | 570 KB |
| 角色 | se20–31（whistle、dove_step/crouch/clap、mask_crack、shutter、projector、fold、broom_snap、knock、bird_eye/peck、drag、train_×4、rail_switch） | 57 | 923 KB |
| 小遊戲 | se40–52（shock×3、meter_max、hold_buzz、brush、bubble、seam_rip、found、wrong、card_flip、chant、snip、snip_flesh、wind、wind_stop、chair_drag/sit、sew、stuff_in/out、unstitch、stitch_tick、memory_snip） | 72 | 894 KB |

---

## 2. 程式引用檢查

### 2-1 檔名規則（程式怎麼找圖）
| 載入點 | 規則 |
|---|---|
| `autoload/dialogue.gd` 立繪 | `ch2_<id>_portrait_` + 依序嘗試 `狀態_表情 → 狀態 → 狀態_default → a_表情 → 表情 → a_default → default`；狀態來自 `chapter2.gd::_portrait_state`，表情來自腳本 `@face`。**只有說話的人才顯示立繪** |
| `dialogue.gd` 背景／CG | `@bg x` → `ch2_bg_x.jpg`；`@bg cgNN_*` → `cg/ch2_cgNN_*.jpg`；`grey_train` → `train_grey`；black/white/train/dream/none 是純色 |
| `chapter2.gd` | 小人表 `SP + "<id>_sprite_*_sheet.png"`；BGM 表 `ch2_bgm%s.ogg`；結尾 `ending_layers/ch2_cg20_%s.png` |
| `audio/sfx.gd` | 61 個名字 → `ch2_seNN_<name>_%02d.ogg`，隨機 1～3 |
| `ui/title.gd`、`end_card.gd` | `ch2_ui_08_nameplate_%s_%s`、`ch2_ui_07_status_%s` |
| 各小遊戲 | `ART % 名字` 清單；缺圖時退回程式繪圖 |

### 2-2 程式引用但不存在
**沒有。** 所有寫死的 `res://` 路徑都存在；動態組出的 SE（61×3）、BGM、名牌、去向圖示、結尾分層、搶椅子走路圖都齊。`@bg train`／`@bg dream` 刻意只用純色（第一、二章都有用到）。

### 2-3 有檔案但遊戲從未顯示／播放（約 82 張圖）

| 分類 | 檔案 | 備註 |
|---|---|---|
| 背景 (3) | `bg_platform_negative`、`bg_treatment_window`、`bg_town_clinic_overlay` | 前兩張只列在 `dialogue_parser.gd` 白名單，劇本沒有 `@bg`；clinic 疊圖第三批已驗收但 `bleach_town.gd` 沒接 |
| CG (13) | `cg01_referral_stitch_01～03`、`cg20_ending_all`、全部 `_blank`（cg01/02/05/08/09）與 `_text_overlay`（cg01/02/05/09） | 劇本只用 stitch_04；結尾用分層不用整張 |
| 立繪：嘎嘎 (7) | 全部 | **嘎嘎在腳本裡從來沒有說話**（0 句），所以立繪永遠不會出現 |
| 立繪：其他 (23) | 白面 a_blank、a_faraway、notail_default；車掌 back、photo；和平鴿 a_turn、a_up；露露 letter；小布 ring、scared；職員 carry；條碼 s1/s2/s3_washed；重重 a_shocked；機械鳥 ×3（不在 `PORTRAITS` 表、也不說話）；以及 5 張與 `a_default` 完全相同的 `*_portrait_default.png`（白面、小棘、條碼、鼬鼬、和平鴿） | 劇本沒有對應 `@face`／狀態 |
| 小人 (4) | `baimian_sprite_notail_sheet`、`staff_sprite_walk_sheet`（1.0 MB）、`zhongzhong_sprite_shiver_sheet`、`tiaoma_sprite_s3_sheet`（=`tiaoma_sprite_sheet`） | 職員沒有地圖角色 |
| 小遊戲 (21) | apology `sticker_01`、`sticker_03_blank`；chairs `baimian_walk_01～04`、`xiaoji_walk_01～04`（=bald 版）、`musicbox`、`sticker_01`；confession `sticker_01`；restuff `step_01～04`；scrub `sticker_01`、`tiaoma_full`；trim `letter_blank`、`letter_text_overlay` | 搶椅子程式只取 pip/gaga/zhongzhong/youyou＋小棘 bald/onequill，白面走路圖沒用到 |
| UI (11) | `ui_01_dialogue`、`ui_01_nameplate`、`ui_06_diary`、`ui_09_chapter2`、`ui_09_chapter3`（有字版）、`ui_10_*` ×4、`ui_11_heart_badge`、`ui_11_heart_line` | 對話框仍是 StyleBoxFlat；日記、顏色碎片圖示沒接 |

### 2-4 音訊沒用到
- **BGM（4 檔）**：`03_far_shore`（在 BGM 表裡但沒有任何 `@bgm far_shore`）、`06_apology`、`07_chairs`、`07_chairs_stop`（道歉練習、搶椅子仍用 `Tones.play` 程式合成的旋律）。
- **SE（35 種／105 檔）從未觸發**：brush、sew、confirm、cursor、conduct_up/down、rule_break、paper、save、title_card、river、broadcast、dove_step、fold、bird_eye、bird_peck、train_whistle、meter_max、hold_buzz、bubble、seam_rip、found、wrong、card_flip、chant、snip、snip_flesh、wind、wind_stop、chair_drag、chair_sit、stuff_in、stuff_out、unstitch、stitch_tick。
  - 有用到的只有：`@sfx` 21 種＋打字 `text`＋環境 `ambience`/`negative_hum`＋電擊 short/medium/long（`Tones.buzz`）。
  - 九個小遊戲的音效全部仍是 `Tones.play` 合成音；UI 系統音效（選項、操行、存檔）都沒接。
  - 第二批回饋寫「配樂 16 首與音效全部已接入遊戲」，與程式現況不符。

### 2-5 完全相同的檔案（md5）
`bg_ending_grey` = `bg_train_grey`；`cg08_diary` = `cg08_diary_blank`（無字版其實沒有去字，或主圖本來就無字）；`confession_card_back` = `card_front`（正反面同一張）；`ui_09_chapter2_blank` = `chapter3_blank`；6 張 `nameplate_*_graduate` 相同；所有 `sticker_*_blank` 相同；apology 與 hold_endure 的 `hold_progress_00～04` 相同；scrub `cotton_01/02` = trim `cotton_puff_01/02`；5 張 `portrait_default` = `a_default`；`tiaoma_sprite_s3_sheet` = `tiaoma_sprite_sheet`；搶椅子 `xiaoji_walk` = `xiaoji_bald_walk`。

---

## 3. 需求 vs 交付

### 3-1 第二章（`chapter2_asset_requests.txt`＋`vendor/ch2_batch2_request.txt`）

| 需求 | 要求 | 現況 |
|---|---|---|
| E 立繪差分 | 白面 7、小棘 13、條碼 13、嘎嘎 6、重重 5、鼬鼬 9、和平鴿 9、車掌 3、露露 3、麻糬 4、波波 3、小布 4、職員 2、機械鳥 3 | ✅ 全交（91 檔含 6 張重複 default） |
| F 小人 F-1～F-19 | 19 項 | ✅ 全交 |
| G 地圖差分 G-1～G-7 | 傍晚、夜晚、負片、畢業、火車、焚化爐關、治療室窗 | ✅ 全交（G-7 未接入） |
| H 背景 BG-01～14 | 15 張 | ✅ 全交（BG-09、BG-10 未使用） |
| I CG-01～20 | 含 stitch 漸進、ticket 結尾版、cg18 差分、cg20 分層 | ✅ 全交 |
| J 小遊戲 9 組 | 見 1-4 | ✅ 全交；apology 沒有專用黑板背景（改用 `bg_classroom`） |
| K UI-01～11 | 11 項 | ✅ 全交（UI-01、06、10、部分 11 未接入） |
| L BGM-01～16 | 16 首＋chairs_stop | ✅ 全交（4 檔未使用） |
| M SE | 約 45 種 | ✅ 61 種 × 3（35 種未使用） |
| 技術規格 | 背景要以 2560×1440、地圖 3200×2300 繪製 | 匯入時縮成 1 倍（`tools/import_vendor_ch2.py`）；P0 稽核指出地圖原生只有 1478×1064 再放大 |
| 分層原始檔 PSD/CLIP/Krita | 必附 | ❌ 倉庫內沒有；P0 稽核也說明「未交付」，第二批是否附上無法從倉庫確認 |

**驗收後仍未結（`ch2_batch3_acceptance.txt`「之後有空再調整」＋回饋未提已修者）**
1. find_odd `stare`：第 3 輪「轉頭看玩家」差別不明顯。
2. 小棘臉型偏泰迪熊、刺蝟特徵弱。
3. 整體色調偏棕褐（需求是暖灰）；之後新素材要往暖灰。
4. UI 框是平面的，缺布料／縫線質感（第二批回饋 11，驗收單沒提已修）。
5. 全部角色與地圖為 **AI 生成**（`ch2_p0/README_交件說明.md`、`generation_prompts.json`）：Steam 上架須揭露；小人逐格一致性需整理。

### 3-2 第一章：沒有任何正式素材
確認：`main.gd`、`world/town.gd`、`forest.gd`、`critter.gd`、`interactable.gd`、ch1 小遊戲都只用程式繪圖；`player.gd` 在 `chapter != 2` 時不載入小布圖集；`hud.gd`／`board.gd` 只有第二章才用圖。唯一例外：第一章結尾的第二章開場 `@bg grey_train` 會顯示第二章的 `ch2_bg_train_grey.jpg`。
`docs/art/` 只有 9 張概念圖（README 已列待修：小布名牌的「46」、鎮長圖上的「Fen」字樣、角色細節不一致）。

| 類別 | 尚無正式素材的項目（依 `docs/script/chapter1.md`、`main.gd`、`GDD.md`） |
|---|---|
| 角色（立繪＋地圖小人） | 小布、熊熊鎮長、露露、Fen、麻糬、小玉、波波、鏡中的孩子、車掌（第一章的影子）、居民 3 隻（小狗、貓） |
| 地圖 | 棉花糖鎮全圖：守則廣場／公告欄、鐘塔、鎮長公館、修理室、鏡之屋、森林小徑、河流與石橋、郵局、Fen 的樹屋、露露的家／麵包店、小布的住處、居民小屋、火車站；時段 day/sunset/evening/night 目前用調色 |
| 室內／特殊場景 | 粉色火車車廂（序章）、小布的家（床、鏡子）、森林（第三天：小綿羊、長耳朵／黃色蝴蝶結、名牌堆、狐狸尾巴）、修理室縫合場景、夢境 1／2（醫院走廊、鉛筆線稿） |
| CG／特寫 | 車票（1 個戳章）、櫥窗裡的照片、名牌背面的字、鐘聲／被抓、縫起來的結尾畫面 |
| 小遊戲 | 接糖果、揉麵團、鏡子凝視（mirror_stare） |
| UI | 粉紅「縫在布上的標籤」對話框、公告欄、HUD（膽量／懷疑值）、日記、章節結算（縫線布告）、標題畫面 |

---

## 4. 音訊現況

| 章節 | BGM | SE |
|---|---|---|
| 第一章 | **無**。只有揉麵團小遊戲用 `scripts/audio/tones.gd` 合成音樂盒音（`Tones.play`）；`chapter1.txt` 沒有任何 `@bgm`／`@sfx` | **無**。GDD 第 10 節說「八點鐘聲是全作最重要的音效」，目前沒有聲音；火車聲、縫紉機、縫線「嗒嗒」、拆線「嗤嗤」（腳本文字有寫）也都沒有聲音 |
| 第二章 | 17 檔外包（13 首有用到；BGM 表見 `chapter2.gd:117`；humming/escape/special_love 一次性，其他循環） | 外包 61 種；實際觸發 26 種（見 2-4） |

所有 BGM/SE 都是程式合成的試玩版（P0 說明：沒有真人演奏、配音、兒童群聲）。BGM-09 哼歌、SE-14 廣播台詞、SE-46 齊喊的人聲版本要確認是否需要重做。

---

## 5. 大小與行動裝置風險

- **沒有 >2 MB 的圖、沒有 wav**（音訊全是 ogg；BGM 最大 615 KB）。最大的 png：`ch2_staff_sprite_walk_sheet.png` 1.0 MB（而且沒用到）、和平鴿圖集 0.9 MB×2。
- 立繪 91 張原檔 36 MB（每張約 400–600 KB），但匯入成有損 WebP 後約 6.5 MB；記憶體中每張解開約 1.5 MB（512×768 RGBA），有快取 `_portrait_cache`（只存路徑）。
- 網頁版 `index.pck` 33.7 MB＋`index.wasm` 35.4 MB，手機首次載入近 70 MB。沒用到的約 82 張圖＋109 個音檔仍會打包進 pck（Godot 預設匯出全部資源），粗估可省 3–5 MB。
- 匯出設定只有 `Web` 一個 preset，`vram_texture_compression/for_mobile=false`；沒有 Android／iOS preset。小人、小遊戲零件、UI 多為無損匯入（各在 1 MB 以下，影響小）。
- `game/README.md` 第 104–105、111–113 行仍寫「狀態還沒有對應的圖」「正式美術、音樂、音效未完成」，已和第二章現況不符（第一章部分仍正確）。

---

## 6. 建議優先順序

1. **第一章美術＋音訊**是最大缺口（角色 8＋、地圖 1、場景約 6、3 個小遊戲、UI、全部 BGM／SE、八點鐘聲）。可沿用第二章需求單格式寫第一章需求。
2. **把已付費的第二章素材接上**：35 種 SE（特別是小遊戲和 UI 音效）、BGM 06／07／03、對話框／日記／顏色碎片 UI、BG-09／BG-10、cg01 繡字漸進、嘎嘎立繪（需要嘎嘎的表情改由旁白觸發，或讓立繪在非說話時也能顯示）、搶椅子白面走路圖、clinic 疊圖。
3. **修正重複檔**：`confession_card_back` = `card_front`、`cg08_diary_blank` = `cg08_diary`，向外包確認。
4. 決定沒用到的檔案是要接上還是刪掉（減少網頁 pck）。
5. 上架前：AI 生成揭露；向外包索取分層原始檔；處理色調、小棘造型、find_odd stare。
