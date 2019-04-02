import bpy
import bmesh
import argparse
import sys
import math
from mathutils import Vector, Matrix

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

# charset
charset="_0123456789abcdefghijklmnopqrstuvwxyz"

def tohex(val, nbits):
    return (hex((int(round(val,0)) + (1<<nbits)) % (1<<nbits))[2:]).zfill(nbits>>2)

# float must be between -3.2/+3.2
def pack_float(x):
    h = "{:02x}".format(int(round(32*x+128,0)))
    if len(h)!=2:
        raise Exception('Unable to convert: {} into a byte: {}'.format(x,h))
    return h
# double must be between -2046/+2046
def pack_double(x):
    h = "{}".format(tohex(16*x+16384,16))
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

# colliders (up to 8)
# ID must start at 1
solid_db = {
 "SOLID_1": 1,
 "SOLID_2": 2,
 "SOLID_3": 3,
 "SOLID_4": 4,
 "SOLID_5": 5,
 "SOLID_6": 6,
 "SOLID_7": 7,
 "SOLID_8": 8
}

# lines DB
lines_db = {
    # ---
    # airport lights references
    # light type -> color + distance between lights (meters)
    "ALS": { "color": 7, "n": 10, "intensity":1, "kind":0},
    "RWYEnd": { "color": 8, "n": 1, "intensity":1, "kind":0},
    "RWYStart": { "color": 11, "n": 1, "intensity":1, "kind":0},
    "RWL-Left": { "color": 7, "n": 30, "intensity":0.8, "kind":0},
    "RWL-Right": { "color": 7, "n": 30, "intensity":0.8, "kind":0},
    "RWY-CLL": { "color": 6, "n": 15, "intensity":1, "kind":0},
    "RWY-CLL-End": { "color": 8, "n": 8, "intensity":1, "kind":0},
    "TAXI": { "color": 12, "n": 20, "intensity":0.1, "kind":0},
    "TAXI-CLL": { "color": 11, "n": 5, "intensity":0.1, "kind":0},
    "RWY-Guard": { "color": 10, "n": 3, "intensity":0.1, "kind":0},
    "CITY": { "color": 9, "n": 30, "intensity":1, "kind":0},
    "CITY_FAR": { "color": 9, "n": 150, "intensity":1, "kind":0},
    # -- 
    # regular lines
    # line type -> line color
    "SHORES": { "color": 1 , "kind":2},
    "SOLID_LIGHT": { "color": 8 , "kind":4},
    "RED_LIGHT": { "color": 8 , "kind":4},
    "GREEN_LIGHT": { "color": 11 , "kind":4},
    "WHITE_LIGHT": { "color": 7 , "kind":4}
}

def export_layer(scale,l):
    # data
    s = ""
    layer = [ob for ob in scene.objects if ob.layers[l]]
    if len(layer)>0:
        obcontext = [o for o in layer if o.type == 'MESH'][0]
        lightcontexts = [o for o in layer if o.type == 'LAMP']
        obdata = obcontext.data
        bm = bmesh.new()
        bm.from_mesh(obdata)

        # create vertex group lookup dictionary for names
        vgroup_names = {vgroup.index: vgroup.name for vgroup in obcontext.vertex_groups}
        # create dictionary of vertex group assignments per vertex
        vgroups = {v.index: [vgroup_names[g.group] for g in v.groups] for v in obdata.vertices}

        # create a map loop index -> vertex index (see: https://www.python.org/dev/peps/pep-0274/)
        loop_vert = {l.index:l.vertex_index for l in obdata.loops}

        vlen = len(obdata.vertices) + len(lightcontexts)*2
        # vertices
        s = s + "{:02x}".format(vlen)
        for v in obdata.vertices:
            s = s + "{}{}{}".format(pack_double(v.co.x), pack_double(v.co.z), pack_double(v.co.y))
        # lamp vertices
        front = Vector((0,-48,0))
        for l in lightcontexts:
            # light position
            s = s + "{}{}{}".format(pack_double(l.location.x), pack_double(l.location.z), pack_double(l.location.y))
            # light direction
            tmp = front.copy()
            tmp.rotate(l.rotation_euler)
            tmp += l.location
            # light end point ("normal")
            s = s + "{}{}{}".format(pack_double(tmp.x), pack_double(tmp.z), pack_double(tmp.y))

        # faces
        faces = []
        for i in range(len(obdata.polygons)):
            f=obdata.polygons[i]
            fs = ""
            # color
            is_dual_sided = False          
            if len(obcontext.material_slots)>0:
                slot = obcontext.material_slots[f.material_index]
                mat = slot.material
                is_dual_sided = mat.game_settings.use_backface_culling==False
                fs = fs + "{:02x}".format(diffuse_to_p8color(mat.diffuse_color))
            else:
                fs = fs + "{:02x}".format(1) # default color
            # is face part of a solid?
            face_verts = {loop_vert[li]:li for li in f.loop_indices}
            solid_group = {vgroups[k][0]:v for k,v in face_verts.items() if len(vgroups[k])==1}
            solid_group = set([solid_db[k] for k,v in solid_group.items() if k in solid_db])
            if len(solid_group)>1:
                raise Exception('Multiple vertex groups for the same face') 
            if len(solid_group)==1:
                # get group ID
                solid_group=solid_group.pop()
                fs = fs + "{:02x}".format(solid_group)
            else:
                fs = fs + "{:02x}".format(0)

            # + face count
            fs = fs + "{:02x}".format(len(f.loop_indices))
            # + vertex id (= edge loop)
            for li in f.loop_indices:
                fs = fs + "{:02x}".format(loop_vert[li]+1)
            faces.append({'face': f, 'flip': False, 'data': fs})
            if is_dual_sided:
                faces.append({'face': f, 'flip': True, 'data': fs})

        # push face data to buffer (inc. dual sided faces)
        s = s + "{:02x}".format(len(faces))
        for f in faces:
            s += f['data']
                    
        # normals
        s = s + "{:02x}".format(len(faces))
        for f in faces:
            flip = -1 if f['flip'] else 1
            f = f['face']
            s = s + "{}{}{}".format(pack_float(flip * f.normal.x), pack_float(flip * f.normal.z), pack_float(flip * f.normal.y))

        # all edges (except pure edge face)
        es = ""
        es_count = 0
        # select pure edges
        edges = [e for e in bm.edges if e.is_wire]
        for e in edges:
            v0 = e.verts[0].index
            v1 = e.verts[1].index
            # get vertex groups
            g0 = vgroups[v0]
            g1 = vgroups[v1]
            # light line?
            if len(g0)>0 and len(g1)>0:
                # find common group (if any)
                cg = set(g0).intersection(g1)
                if len(cg)>1:
                    raise Exception('Multiple vertex groups for the same edge ({},{}): {} x {} -> {}'.format(obdata.vertices[v0].co,obdata.vertices[v1].co,g0,g1,cg))
                if len(cg)==1:
                    # get light specifications
                    light_group_name=cg.pop()
                    light=lines_db[light_group_name]
                    light_color_index=light['color']
                    light_kind=light['kind']
                    # light color + light type
                    es = es + "{:02x}{:02x}{:02x}{:02x}".format(v0+1, v1+1, light_kind, light_color_index)
                    es_count = es_count + 1
                    # additional properties
                    if light_kind==0:
                        # number of lights
                        # find out number of lights according to segment length
                        # convert model scale to meters (1 game unit = 48 meters)
                        num_lights=int(round(max(48*e.calc_length()/light['n']/scale,2)))
                        if num_lights>255:
                            raise Exception('Too many lights ({}) for edge: ({},{}) category: {}'.format(num_lights,obdata.vertices[v0].co,obdata.vertices[v1].co,light_group_name))
                        light_scale=light['intensity']
                        es = es + "{:02x}{}".format(num_lights,pack_float(light_scale))

        # PAPI lights
        lightindex = len(obdata.vertices)
        for l in lightcontexts:
            es = es + "{:02x}{:02x}{:02x}{:02x}".format(lightindex+1, lightindex + 2, 1, diffuse_to_p8color(l.data.color))
            lightindex += 2
            es_count = es_count + 1

        s = s + "{:02x}".format(es_count) + es
    return s

# model data
s = ""

# select first mesh object
obcontext = [o for o in scene.objects if o.type == 'MESH' and o.layers[0]][0]

# object name
name = obcontext.name.lower()
s = s + "{:02x}".format(len(name))
for c in name:
    s = s + "{:02x}".format(charset.index(c)+1)

# scale (custom scene property)
model_scale = scene.get("scale", 1)
s = s + "{:02x}".format(model_scale)

# model lod selection
lod_dist = scene.get("lod_dist", [1024])
s = s + "{:02x}".format(len(lod_dist))
for i in lod_dist:
    s = s + "{}".format(pack_double(i))

# layers = lod
ln = 0
ls = ""
for i in range(2):
    layer_data = export_layer(model_scale,i)
    if len(layer_data)>0:
        ln += 1
        ls = ls + layer_data
# number of active lods
s = s + "{:02x}".format(ln)
s = s + ls

#
with open(args.out, 'w') as f:
    f.write(s)

