import os
from subprocess import Popen, PIPE
import re
import tempfile
import random
import math

local_dir = os.path.dirname(os.path.realpath(__file__))
blender_dir = os.path.expandvars("%programfiles%/Blender Foundation/Blender")

def call(args):
    proc = Popen(args, stdout=PIPE, stderr=PIPE)
    out, err = proc.communicate()
    exitcode = proc.returncode
    #
    return exitcode, out, err

# data buffer
s = ""

# random stars
# float must be between -3.2/+3.2
def pack_float(x):
    h = "{:02x}".format(int(round(32*x+128,0)))
    if len(h)!=2:
        raise Exception('Unable to convert: {} into a byte: {}'.format(x,h))
    return h
def random_three_vector():
    """
    Generates a random 3D unit vector (direction) with a uniform spherical distribution
    Algo from http://stackoverflow.com/questions/5408276/python-uniform-spherical-distribution
    :return:
    """
    phi = random.uniform(0,2*math.pi)
    theta = random.uniform(0,math.pi)
    x = math.sin(theta) * math.cos( phi )
    z = math.sin(theta) * math.sin( phi )
    y = abs(math.cos(theta))
    return (x,y,z)
s = s + "{:02x}".format(48)
for i in range(48):
    v = random_three_vector()
    s = s + "{}{}{}".format(pack_float(v[0]),pack_float(v[1]),pack_float(v[2]))

# 3d models
file_list = ['landing_strip','city1','ground','mnt_big','ship','windg','small_strip']
s = s + "{:02x}".format(len(file_list))
for blend_file in file_list:
    print("Exporting: {}.blend".format(blend_file))
    fd, path = tempfile.mkstemp()
    try:
        os.close(fd)
        exitcode, out, err = call([os.path.join(blender_dir,"blender.exe"),os.path.join(local_dir,blend_file + ".blend"),"--background","--python",os.path.join(local_dir,"blender_export.py"),"--","--out",path])
        if err:
            raise Exception('Unable to loadt: {}. Exception: {}'.format(blend_file,err))
        print("exit: {} \n out:{}\n err: {}\n".format(exitcode,out,err))
        with open(path, 'r') as outfile:
            s = s + outfile.read()
    finally:
        os.remove(path)

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

