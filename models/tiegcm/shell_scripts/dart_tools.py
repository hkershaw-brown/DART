import math
from mpl_toolkits import mplot3d
import matplotlib.pyplot as plt 
from subprocess import check_output, CalledProcessError

def dart_dir():
    """ return the top level directory of DART """
    try:
        dart = check_output(['git', 'rev-parse', '--show-toplevel'])
    except CalledProcessError:
        raise IOError('Current working directory is not a git repository')
    return dart.decode('utf-8').strip()


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
 


