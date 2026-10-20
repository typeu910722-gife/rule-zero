#!/usr/bin/env python3
"""產生 iPhone 描述檔（Web Clip）：主畫面加入「第零條規則」圖示，全螢幕開啟網頁試玩版。
用法：make_ios_profile.py <網站網址，例 https://try.yzprojecttw.com> <輸出 .mobileconfig>"""
import io, plistlib, sys, uuid
from pathlib import Path
from PIL import Image

base, out = sys.argv[1].rstrip("/"), sys.argv[2]
root = Path(__file__).resolve().parent.parent
ic = Image.open(root / "game/art/branding/icon.png").convert("RGB").resize((180, 180), Image.LANCZOS)
buf = io.BytesIO()
ic.save(buf, "PNG")
clip = {
    "PayloadType": "com.apple.webClip.managed", "PayloadVersion": 1,
    "PayloadIdentifier": "com.yzprojecttw.rulezero.webclip",
    "PayloadUUID": str(uuid.uuid5(uuid.NAMESPACE_URL, base + "/webclip")).upper(),
    "PayloadDisplayName": "第零條規則", "Label": "第零條規則",
    "URL": base + "/rule-zero/", "Icon": buf.getvalue(),
    "FullScreen": True, "IsRemovable": True, "Precomposed": True, "IgnoreManifestScope": True,
}
profile = {
    "PayloadType": "Configuration", "PayloadVersion": 1,
    "PayloadIdentifier": "com.yzprojecttw.rulezero",
    "PayloadUUID": str(uuid.uuid5(uuid.NAMESPACE_URL, base + "/profile")).upper(),
    "PayloadDisplayName": "第零條規則（試玩）", "PayloadOrganization": "歪計劃 YZ ProJect",
    "PayloadDescription": "在主畫面加入「第零條規則」圖示，用全螢幕開啟試玩版。不會讀取或更改手機上的任何資料，隨時可以在「設定 → 一般 → VPN 與裝置管理」移除。",
    "PayloadRemovalDisallowed": False, "PayloadContent": [clip],
}
Path(out).write_bytes(plistlib.dumps(profile))
print("描述檔：", out, "→", clip["URL"])
