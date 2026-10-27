"""外包 SVG 的路徑資料有兩個數字黏在一起（例 65.3126＝65.3 126、49.900000000000006126＝49.900000000000006 126），
畫出來頭髮會多一根長刺。依每個指令該有幾個數字，把黏在一起的拆開。"""
import sys, re, glob, os
NEED = {'M': 2, 'L': 2, 'T': 2, 'Q': 4, 'S': 4, 'C': 6, 'H': 1, 'V': 1, 'Z': 0, 'A': 7}
NUM = re.compile(r'-?\d*\.?\d+(?:e-?\d+)?')

def splits(t):
    """把一個黏住的數字拆成兩個的候選，好的排前面"""
    if '.' not in t:
        return []
    i = t.index('.')
    out = []
    for p in range(i + 2, len(t)):
        a, b = t[:p], t[p:]
        if b.startswith('.') or (b.startswith('0') and len(b) > 1 and b[1] != '.'):
            continue
        good = repr(float(a)) == a or len(a) - i - 1 == 1   # 正常的 repr，或一位小數
        out.append((0 if good else 1, -p if repr(float(a)) == a and len(a) - i > 6 else p, a, b))
    out.sort()
    return [(a, b) for _, _, a, b in out]

def fix_path(d):
    parts = re.findall(r'[MLTQSCHVZAmltqschvza]|[^MLTQSCHVZAmltqschvza]+', d)
    res = []; cmd = None; fixed = 0
    for p in parts:
        if re.fullmatch(r'[A-Za-z]', p):
            cmd = p.upper(); res.append(p); continue
        nums = NUM.findall(p)
        need = NEED.get(cmd, 0)
        while need and len(nums) % need != 0:
            # 找一個可以拆的數字（從中間往外），拆成兩個
            done = False
            for k in range(len(nums)):
                c = splits(nums[k].lstrip('-'))
                if c:
                    a, b = c[0]
                    neg = '-' if nums[k].startswith('-') else ''
                    nums[k:k + 1] = [neg + a, b]; done = True; fixed += 1; break
            if not done:
                break
        res.append(' '.join(nums) if nums else p)
    return ''.join(res), fixed

src, out = sys.argv[1], sys.argv[2]
total = 0
for f in sorted(glob.glob(src + '/h_*_walk_*.svg')):
    s = open(f, encoding='utf-8').read()
    n = [0]
    def g(m):
        d, k = fix_path(m.group(1)); n[0] += k
        return 'd="%s"' % d
    s2 = re.sub(r'd="([^"]*)"', g, s)
    total += n[0]
    open(os.path.join(out, os.path.basename(f)), 'w', encoding='utf-8').write(s2)
    print(os.path.basename(f), n[0])
print('total', total)
