import sys, lupa
try:
    from lupa import lua51 as L
except ImportError:
    L = lupa
rt = L.LuaRuntime()
load = rt.eval("function(src, name) local f, err = (loadstring or load)(src, name) return f ~= nil, err end")
for path in sys.argv[1:]:
    src = open(path, encoding="utf-8").read()
    ok, err = load(src, "=" + path.replace("\\", "/").split("/")[-1])
    print("SYNTAX OK" if ok else "SYNTAX ERROR: %s" % err)
