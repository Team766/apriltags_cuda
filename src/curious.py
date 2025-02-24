import robot_rotations as r
import numpy as np

nominal_left_front = np.array([[0, -0.422, 0.906], [-1, 0, 0], [0, -0.906, -0.422]])

print(f"\nLeft front matrix from discord: \n{nominal_left_front}")

cam_vec_z = np.array([0, 0, 1])
print(f"\nCamera vector, z-axis: {cam_vec_z}")
print(
    f"\nMultiply camera z vector by that matrix: nominal_left_front @ cam_vec_z \n{nominal_left_front @ cam_vec_z}"
)
print(
    "Notice how the x coordinate is positive.  It should be negative since the camera points towards robot -X"
)

print(f"\n\nCompose rotations from discord instructions:\n")
cam_to_robot = r.camera_to_robot()
z_rot = r.rotation_z(180)
y_rot = r.rotation_y(25)
matrix = y_rot @ z_rot @ cam_to_robot
print(f"\n cam_to_robot: \n {cam_to_robot}")
print(f"\n z_rot: \n {z_rot}")
print(f"\n y_rot: \n {y_rot}")
print(f"\n matrix m: y_rot @ z_rot @ cam_to_robot: \n {matrix}")
print(f"\nMultiply camera z vector by matrix m: m @ cam_vec_z \n{matrix @ cam_vec_z}")
print(
    "The x coordinate is negative meaning that the camera is pointing towards robot -X"
)
