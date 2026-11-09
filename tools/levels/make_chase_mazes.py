"""3D 追逐「單一路線」迷宮（2026-11-09 使用者：要有壓迫感、只有一條路、跑錯就重開）。
用轉折點畫出唯一的正確路線，再在路口加短短的死路（X＝跑進去就被抓）。
會檢查：路線是一棵樹（沒有繞圈的捷徑）、S→E 的路不經過 X、每條死路只接在一個路口上、D 在 S 正後方。
輸出 GDScript 常數，貼進 game/scripts/ch3/chase3d.gd。
用法：py -3.11 tools/levels/make_chase_mazes.py"""
from collections import deque

MAZES = {
    # 第三章 捉迷藏：畢業生
    "MAZE_LINEAR_HOSP": dict(
        size=(21, 13),
        path=[(2, 1), (8, 1), (8, 5), (3, 5), (3, 9), (10, 9), (10, 3), (16, 3), (16, 7), (13, 7), (13, 11), (19, 11)],
        traps=[((5, 1), (0, 1), 2), ((3, 7), (1, 0), 3), ((7, 9), (0, 1), 2), ((10, 5), (1, 0), 3), ((16, 5), (1, 0), 2),
               ((16, 11), (0, -1), 2)],
        check=(10, 6)),
    # 第三章 點名：比較長
    "MAZE_LINEAR_ROLLCALL": dict(
        size=(23, 15),
        path=[(2, 1), (6, 1), (6, 5), (2, 5), (2, 9), (6, 9), (6, 13), (11, 13), (11, 7), (9, 7), (9, 3), (14, 3), (14, 9),
              (18, 9), (18, 1), (21, 1), (21, 13)],
        traps=[((4, 1), (0, 1), 2), ((2, 7), (1, 0), 2), ((6, 11), (-1, 0), 3), ((11, 10), (-1, 0), 3),
               ((12, 3), (0, 1), 3), ((14, 6), (1, 0), 1), ((18, 5), (-1, 0), 2), ((21, 7), (-1, 0), 1), ((21, 11), (-1, 0), 2)],
        check=(11, 9)),
    # 終章 A：理事（人類的身體會喘，路短一點）
    "MAZE_LINEAR_REAL": dict(
        size=(19, 11),
        path=[(2, 1), (7, 1), (7, 5), (3, 5), (3, 9), (11, 9), (11, 3), (16, 3), (16, 9)],
        traps=[((5, 1), (0, 1), 2), ((3, 7), (1, 0), 3), ((9, 9), (0, -1), 2), ((11, 6), (1, 0), 2), ((14, 3), (0, 1), 2)],
        check=(11, 6)),
}


def build(spec):
    w, h = spec["size"]
    g = [["#"] * w for _ in range(h)]
    pts = spec["path"]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        assert x0 == x1 or y0 == y1, ("轉折點要水平或垂直", (x0, y0), (x1, y1))
        for x in range(min(x0, x1), max(x0, x1) + 1):
            for y in range(min(y0, y1), max(y0, y1) + 1):
                g[y][x] = "."
    for (rx, ry), (dx, dy), n in spec["traps"]:
        assert g[ry][rx] == ".", ("死路要接在路線上", (rx, ry))
        for k in range(1, n + 1):
            x, y = rx + dx * k, ry + dy * k
            assert 0 < x < w - 1 and 0 < y < h - 1, ("死路超出範圍", (x, y))
            g[y][x] = "X"
    sx, sy = pts[0]
    ex, ey = pts[-1]
    g[sy][sx] = "S"
    g[ey][ex] = "E"
    # D：起點正後方（第一段的反方向）
    nx, ny = pts[1]
    bx, by = sx - (1 if nx > sx else -1 if nx < sx else 0), sy - (1 if ny > sy else -1 if ny < sy else 0)
    g[by][bx] = "D"
    cx, cy = spec["check"]
    assert g[cy][cx] == ".", ("檢查點要在路線上", (cx, cy))
    g[cy][cx] = "C"
    return ["".join(r) for r in g]


def check(name, m):
    h, w = len(m), len(m[0])
    cells = {(x, y) for y in range(h) for x in range(w) if m[y][x] != "#"}
    edges = 0
    for (x, y) in cells:
        for d in ((1, 0), (0, 1)):
            if (x + d[0], y + d[1]) in cells:
                edges += 1
    assert edges == len(cells) - 1, (name, "有繞圈的捷徑（不是樹）", edges, len(cells))
    find = lambda ch: next((x, y) for y in range(h) for x in range(w) if m[y][x] == ch)
    S, E, D = find("S"), find("E"), find("D")
    prev = {S: None}
    q = deque([S])
    while q:
        c = q.popleft()
        for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (c[0] + d[0], c[1] + d[1])
            if n in cells and n not in prev:
                prev[n] = c
                q.append(n)
    assert E in prev, (name, "走不到出口")
    path, c = [], E
    while c:
        path.append(c)
        c = prev[c]
    assert all(m[y][x] != "X" for x, y in path), (name, "正確路線經過死路")
    assert len(prev) == len(cells), (name, "有走不到的格子")
    junctions = sum(1 for p in path if sum((p[0] + d[0], p[1] + d[1]) in cells for d in ((1, 0), (-1, 0), (0, 1), (0, -1))) > 2)
    return len(path) - 1, junctions


if __name__ == "__main__":
    for name, spec in MAZES.items():
        m = build(spec)
        n, j = check(name, m)
        print("## %s：正確路線 %d 格、%d 個岔路" % (name, n, j))
        print("const %s := [" % name)
        for r in m:
            print('\t"%s",' % r)
        print("]")
