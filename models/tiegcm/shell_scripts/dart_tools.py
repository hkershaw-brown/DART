import math
from mpl_toolkits import mplot3d
import matplotlib.pyplot as plt 
import subprocess 
import os
import sys 

def dart_dir():
    """ return the top level directory of DART """
    try:
        dart = subprocess.check_output(['git', 'rev-parse', '--show-toplevel'])
    except subprocess.CalledProcessError:
        raise IOError('Current working directory is not a git repository')
    return dart.decode('utf-8').strip()

def build_qty_types_mod():
    """ build a python module qt from the qtys and types in obs_kind_mod.f90

        qt contains the qtys and type parameter used in DART
        Assumes that obs_kind_mod.f90 is in the default location
        DART/assimilation_code/modules/observations/obs_kind_mod.f90
    """ 

    obs_kind_file = os.path.join(dart_dir(),"assimilation_code/modules/observations/obs_kind_mod.f90")
    if not os.path.exists(obs_kind_file):
        sys.exit("file {} does not exist".format(obs_kind_file))

    print("running the build") 
    p = subprocess.run(["grep", "-i", "integer, parameter, public", obs_kind_file], capture_output=True) #, ">", "qty_types.f90"])
    with open('qty_types.f90', 'w') as f:
        f.write('module qty_types_mod\n')
        f.write(p.stdout.strip().decode('utf8'))
        f.write('\nend module qty_types_mod\n')

    subprocess.run(["f2py", "-c", "qty_types.f90", "-m", "qt"])


def golden_spiral(samples=1000):

    points = []
    phi = math.pi * (math.sqrt(5.) - 1.)  # golden angle in radians

    for i in range(samples):
        y = 1 - (i / float(samples - 1)) * 2  # y goes from 1 to -1
        radius = math.sqrt(1 - y * y)  # radius at y

        theta = phi * i  # golden angle increment

        x = math.cos(theta) * radius
        z = math.sin(theta) * radius

        points.append((x, y, z)) 

    return points


def plot_points(points):

    x = [x[0] for x in points]
    y = [x[1] for x in points]
    z = [x[2] for x in points]
    
    ax = plt.axes(projection='3d')
    ax.scatter3D(x,y,z)
    plt.show()
 


