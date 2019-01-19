import os
from subprocess import Popen, PIPE
import re
import tempfile

local_dir = os.path.dirname(os.path.realpath(__file__))
blender_dir = os.path.expandvars("%programfiles%/Blender Foundation/Blender")

def call(args):
    proc = Popen(args, stdout=PIPE, stderr=PIPE)
    out, err = proc.communicate()
    exitcode = proc.returncode
    #
    return exitcode, out, err

# charset
charset="_0123456789abcdefghijklmnopqrstuvwxyz !\n.,-:{}\"[]"
json='{"scenarios":[{"name":"visual approach","lat":-417,"lon":326.3,"hdg":85,"alt":600,"pitch":-1,"bank":0,"throttle":25,"gps":3,"nav1":2,"nav2":1},{"name":"final approach","lat":-408.89,"lon":230.77,"hdg":85,"alt":1000,"pitch":1,"bank":0,"throttle":75,"gps":3,"nav1":2,"nav2":1},{"name":"full approach","lat":-222.22,"lon":461.54,"hdg":313,"alt":3000,"pitch":0,"bank":0,"throttle":91,"gps":3,"nav1":2,"nav2":1},{"name":"engine failure!","lat":-244.44,"lon":261.54,"hdg":50,"alt":3500,"pitch":0,"bank":0,"throttle":0,"gps":4,"nav1":2,"nav2":5},{"name":"unusual attitude","lat":-222.22,"lon":461.54,"hdg":330,"alt":450,"pitch":99,"bank":99,"throttle":100,"gps":3,"nav1":2,"nav2":1}],"wx":[{"name":"clear, calm","wind":[0,0],"ceiling":20000},{"name":"clouds, breezy","wind":[60,10],"ceiling":500},{"name":"low clouds, stormy","wind":[10,45],"ceiling":200}],"db":[{"lat":-251.11,"lon":430.77,"name":"pco","type":"vor"},{"lat":-422.2,"lon":370,"name":"itn","type":"ils","angle":85},{"lat":-422.2,"lon":384.6,"name":"tny","type":"apt","angle":85,"model":"runway"},{"lat":-66.67,"lon":153.85,"name":"smv","type":"apt","angle":40,"model":"runway"},{"lat":-177.78,"lon":246.15,"name":"wee","type":"vor"}],"hsic":[64,111],"bp":{"v":[[64,98],[64,102],[62,100],[66,100],[64,120],[64,124]],"e":[[1,2],[1,3],[1,4],[5,6]]},"nesw":[[64,99,52],[52,111,53],[64,123,36],[76,111,37]],"cdii":{"v":[[64,98],[64,102],[62,100],[66,100],[64,120],[64,124],[64,104],[64,118]],"e":[[1,2],[1,3],[1,4],[5,6],[7,8]]},"cockpit":[{"fn":"rectfill","args":[10,36,127,42,0]},{"fn":"print","args":["nav1",11,37,7]},{"fn":"line","args":[43,36,43,42,7]},{"fn":"spr","args":[7,47,37]},{"fn":"print","args":["dis",75,37,7]},{"fn":"print","args":["gs",107,37]},{"fn":"rectfill","args":[0,115,8,127,0]},{"fn":"line","args":[4,90,4,110,5]},{"fn":"line","args":[5,90,5,110,13]},{"fn":"line","args":[5,90,5,110,13]},{"fn":"rectfill","args":[11,97,33,119,0]},{"fn":"line","args":[40,71,45,71,10]},{"fn":"line","args":[83,71,88,71]},{"fn":"rectfill","args":[57,88,71,94,0]},{"fn":"pset","args":[70,89,7]},{"fn":"rectfill","args":[107,121,127,127,0]},{"fn":"line","args":[45,111,47,111,7]},{"fn":"line","args":[81,111,83,111,7]},{"fn":"spr","args":[18,71,120,1,1,true,false]},{"fn":"spr","args":[34,79,115,1,1,true,false]},{"fn":"rectfill","args":[87,115,100,127,0]},{"fn":"rectfill","args":[79,123,86,127]},{"fn":"spr","args":[35,79,122,1,1,true,false]},{"fn":"rectfill","args":[40,95,45,100,0]}],"models":{"runway":{"c":6,"v":[[15,0,0],[15,0,-1500],[-15,0,0],[-15,0,-1500],[20,0,-1500],[-20,0,-1500],[15,0,-1550],[-15,0,-1550],[0,0,-1500],[0,0,-1600],[-2,0,-1600],[-2,0,-1800],[2,0,-1600],[2,0,-1800],[0,0,0],[0,0,-1500],[-5,0,-1550],[5,0,-1550],[-8,0,-1600],[8,0,-1600],[-10,0,-1700],[10,0,-1700],[-20,0,-1800],[20,0,-1800]],"e":[[1,2,1],[3,4,1],[1,2,7,128],[3,4,7,128],[1,3,8,10],[5,6,11,20],[2,7,8,5],[4,8,8,5],[9,10,10,10],[11,12,10,10],[13,14,10,10],[15,16,6,128],[17,18,7,8],[19,20,7,8],[21,22,7,10],[23,24,7,10]]}}}'
s = ""
for c in json:
    try:
        s = s + "{:02x}".format(charset.index(c)+1)
    except Exception as e:
        raise Exception("Missing token: {}".format(c))
print("String length: {}".format(len(s)))

# pico-8 map format
# first 4096 bytes -> gfx (shared w/ map)
# second 4096 bytes -> map
if len(s)>=2*8192:
    raise Exception('Data string too long ({})'.format(len(s)))

tmp=s[:8192]
print("__gfx__")
# swap bytes
gfx_data = ""
for i in range(0,len(tmp),2):
    gfx_data = gfx_data + tmp[i+1:i+2] + tmp[i:i+1]
print(re.sub("(.{128})", "\\1\n", gfx_data, 0, re.DOTALL))

map_data=s[8192:]
if len(map_data)>0:
    print("__map__")
    print(re.sub("(.{256})", "\\1\n", map_data, 0, re.DOTALL))

