import bpy
import bmesh
import argparse
import sys

argv = sys.argv
if "--" not in argv:
    argv = []
else:
   argv = argv[argv.index("--") + 1:]

try:
    parser = argparse.ArgumentParser(description='Exports Blender model as a byte array for wireframe rendering',prog = "blender -b -P "+__file__+" --")
    parser.add_argument('-o','--out', help='Output file', required=True, dest='out')
    args = parser.parse_args(argv)
except Exception as e:
    sys.exit(repr(e))

scene = bpy.context.scene
# select first mesh object
obcontext = [o for o in scene.objects if o.type == 'MESH'][0]
obdata = obcontext.data

# charset
charset="_0123456789abcdefghijklmnopqrstuvwxyz"

# float must be between -3.2/+3.2
def pack_float(x):
    h = "{:02x}".format(int(round(32*x+128,0)))
    if len(h)!=2:
        raise Exception('Unable to convert: {} into a byte: {}'.format(x,h))
    return h
# double must be between -2046/+2046
def pack_double(x):
    h = "{:04x}".format(int(round(16*x+16384,0)))
    if len(h)!=4:
        raise Exception('Unable to convert: {} into a double-byte: {}'.format(x,h))
    return h

p8_colors = ['000000','1D2B53','7E2553','008751','AB5236','5F574F','C2C3C7','FFF1E8','FF004D','FFA300','FFEC27','00E436','29ADFF','83769C','FF77A8','FFCCAA']
def to_p8color(rgb):
    h = "{:02X}{:02X}{:02X}".format(int(round(255*rgb.r)),int(round(255*rgb.g)),int(round(255*rgb.b)))
    try:
        #print("diffuse:{} -> {}\n".format(rgb,p8_colors.index(h)))
        return p8_colors.index(h)
    except Exception as e:
        # unknown color
        raise Exception('Unknown color: 0x{}'.format(h))

# model data
s = ""

# object name
name = obcontext.name.lower()
s = s + "{:02x}".format(len(name))
for c in name:
    s = s + "{:02x}".format(charset.index(c)+1)

# scale (custom model property)
s = s + "{:02x}".format(obcontext.get("scale", 1))

bm = bmesh.new()
bm.from_mesh(obdata)

s = s + "{:02x}".format(len(obdata.vertices))
for v in obdata.vertices:
    s = s + "{}{}{}".format(pack_double(v.co.x), pack_double(v.co.z), pack_double(v.co.y))

# faces
s = s + "{:02x}".format(len(bm.faces))
for f in bm.faces:
    # shortcut to first vertex
    s = s + "{:02x}".format(f.verts[0].index+1)
    # edge id's
    s = s + "{:02x}".format(len(f.edges))
    for e in f.edges:
        s = s + "{:02x}".format(e.index+1)

# normals
s = s + "{:02x}".format(len(obdata.polygons))
for f in obdata.polygons:
    s = s + "{}{}{}".format(pack_float(f.normal.x), pack_float(f.normal.z), pack_float(f.normal.y))

# all edges
s = s + "{:02x}".format(len(bm.edges))
for e in bm.edges:
    s = s + "{:02x}{:02x}{:02x}".format(e.verts[0].index+1, e.verts[1].index+1,1 if e.is_wire else 0)

#
with open(args.out, 'w') as f:
    f.write(s)

