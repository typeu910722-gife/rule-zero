# 測試版 APK 的簽章金鑰

`debug.keystore` 只給**測試版**用（密碼 android／別名 androiddebugkey，是公開的 Android 預設值）。
固定用同一把，玩家下載新的測試版才能直接覆蓋安裝、保留存檔。

正式上架（Google Play）要另外建立**私人**的 release 金鑰，不能放進 Git。
