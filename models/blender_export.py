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
def diffuse_to_p8color(rgb):
    h = "{:02X}{:02X}{:02X}".format(int(round(255*rgb.r)),int(round(255*rgb.g)),int(round(255*rgb.b)))
    try:
        #print("diffuse:{} -> {}\n".format(rgb,p8_colors.index(h)))
        return p8_colors.index(h)
    except Exception as e:
        # unknown color
        raise Exception('Unknown color: 0x{}'.format(h))

# airport lights references
# light type -> color + number of lights per meter
lights_db = {
    "ALS": { "color": 8, "n": 10 },
    "RWYEnd": { "color": 8, "n": 1 },
    "RWYStart": { "color": 11, "n": 1 },
    "RWL-Left": { "color": 7, "n": 30 },
    "RWL-Right": { "color": 7, "n": 30 },
    "RWY-CLL": { "color": 6, "n": 15 },
    "RWY-CLL-End": { "color": 8, "n": 8 },
    "TAXI": { "color": 12, "n": 20 },
    "TAXI-CLL": { "color": 11, "n": 5 }
}

# group data
# create vertex group lookup dictionary for names
vgroup_names = {vgroup.index: vgroup.name for vgroup in obcontext.vertex_groups}
# create dictionary of vertex group assignments per vertex
vgroups = {v.index: [vgroup_names[g.group] for g in v.groups] for v in obdata.vertices}

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

# create a map loop index -> vertex index (see: https://www.python.org/dev/peps/pep-0274/)
loop_vert = {l.index:l.vertex_index for l in obdata.loops}

s = s + "{:02x}".format(len(obdata.vertices))
for v in obdata.vertices:
    s = s + "{}{}{}".format(pack_double(v.co.x), pack_double(v.co.z), pack_double(v.co.y))

# faces
s = s + "{:02x}".format(len(obdata.polygons))
for f in obdata.polygons:
    # color
    if len(obcontext.material_slots)>0:
        slot = obcontext.material_slots[f.material_index]
        mat = slot.material
        s = s + "{:02x}".format(diffuse_to_p8color(mat.diffuse_color))
        # + dual-sided?
        s = s + "{:02x}".format(0 if mat.game_settings.use_backface_culling else 1)
    else:
        s = s + "{:02x}{:02x}".format(1,0)
    # face center (only z needed)
    v = f.center
    s = s + "{}".format(pack_double(v[2]))
    # + vertex count
    s = s + "{:02x}".format(len(f.loop_indices))
    # + vertex id (= edge loop)
    for li in f.loop_indices:
        s = s + "{:02x}".format(loop_vert[li]+1)

# normals
s = s + "{:02x}".format(len(obdata.polygons))
for f in obdata.polygons:
    s = s + "{}{}{}".format(pack_float(f.normal.x), pack_float(f.normal.z), pack_float(f.normal.y))

# all edges (except pure edge face)
es = ""
es_count = 0
for e in bm.edges:
    v0 = e.verts[0].index
    v1 = e.verts[1].index
    # get vertex groups
    g0 = vgroups[v0]
    g1 = vgroups[v1]
    # pure edge or light line?
    if e.is_wire or (len(g0)>0 and len(g1)>0):
        is_light=False
        light_color_index=0
        num_lights=0
        light_group_name=""
        if len(g0)>0 and len(g1)>0:
            # find common group (if any)
            cg = set(g0).intersection(g1)
            if len(cg)>1:
                raise Exception('Multiple vertex groups for the same edge ({},{}): {} x {} -> {}'.format(obdata.vertices[v0].co,obdata.vertices[v1].co,g0,g1,cg))
            if len(cg)==1:
                # get light specifications
                light_group_name=cg.pop()
                light=lights_db[light_group_name]            
                is_light=True
                light_color_index=light['color']
                # find out number of lights according to segment length
                num_lights=int(round(max(e.calc_length()/light['n'],2)))
        es = es + "{:02x}{:02x}{:02x}".format(v0+1, v1+1, 1 if is_light else 0)
        if is_light:
            # light color
            # + number of lights
            if num_lights>255:
                raise Exception('Too many lights ({}) for edge: ({},{}) category: {}'.format(num_lights,obdata.vertices[v0].co,obdata.vertices[v1].co,light_group_name))
            es = es + "{:02x}{:02x}".format(light_color_index,num_lights)
        es_count = es_count + 1

s = s + "{:02x}".format(es_count) + es

#
with open(args.out, 'w') as f:
    f.write(s)

