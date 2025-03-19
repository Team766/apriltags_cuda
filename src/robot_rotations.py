import numpy as np
import math
import json

np.set_printoptions(precision=4, suppress=True)


def rotation_x(angle_degrees):
    """
    3x3 rotation matrix about X-axis (right-handed).
    """
    theta = math.radians(angle_degrees)
    c = math.cos(theta)
    s = math.sin(theta)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]], dtype=float)


def rotation_y(angle_degrees):
    """
    3x3 rotation matrix about Y-axis (right-handed).
    """
    theta = math.radians(angle_degrees)
    c = math.cos(theta)
    s = math.sin(theta)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]], dtype=float)


def rotation_z(angle_degrees):
    """
    3x3 rotation matrix about Z-axis (right-handed).
    """
    theta = math.radians(angle_degrees)
    c = math.cos(theta)
    s = math.sin(theta)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]], dtype=float)


def compose_rotations_xyz(roll_deg, pitch_deg, yaw_deg):
    """
    Compose rotations in the order Rx(roll) * Ry(pitch) * Rz(yaw).
    Adjust if your convention differs.
    """
    Rx = rotation_x(roll_deg)
    Ry = rotation_y(pitch_deg)
    Rz = rotation_z(yaw_deg)
    return Rx @ Ry @ Rz

def camera_to_robot():
    # Converts camera coords to robot frame.
    return compose_rotations_xyz(-90, 90, 0)

if __name__ == "__main__":
    """
    Robot coordinates (right-handed):
        X forward, Y to the right, Z up.

    Camera coordinates (OpenCV style):
        Z out of the camera (optical axis),
        X to the right (columns),
        Y down (rows).

    Goal:
      - Left/Right front cameras => on Rev A/B these point towards robot -X and are angled up
      - Left/Right back cameras  => on Rev A these point forwards and are offset by Z
    """

    cam_vec_z = np.array([0, 0, 1])

    # ------------------------------------------------------------
    # LEFT FRONT CAMERA
    # Camera is pointed backwards towards -X and up slightly
    LF_roll = 0.0
    LF_pitch = 23.0
    LF_yaw = 180.0

    R_left_front = compose_rotations_xyz(LF_roll, LF_pitch, LF_yaw) @ camera_to_robot()
    print(f'left front sanity check: {R_left_front @ cam_vec_z}')

    # ------------------------------------------------------------
    # RIGHT FRONT CAMERA
    # Same as left front camera
    RF_roll = 0.0
    RF_pitch = 23.0
    RF_yaw = 180.0

    R_right_front = compose_rotations_xyz(RF_roll, RF_pitch, RF_yaw) @ camera_to_robot()
    print(f'right front sanity check: {R_right_front @ cam_vec_z}')

    # ------------------------------------------------------------
    # LEFT BACK CAMERA
    # Camera points forward but yaws 45 degrees
    LB_roll = 0
    LB_pitch = 0
    LB_yaw = 30

    R_left_back = compose_rotations_xyz(LB_roll, LB_pitch, LB_yaw) @ camera_to_robot()
    print(f'left back sanity check: {R_left_back @ cam_vec_z}')

    # ------------------------------------------------------------
    # RIGHT BACK CAMERA
    # Same as left back camera but yaws -45 degrees.
    RB_roll = 0
    RB_pitch = 0
    RB_yaw = -30

    R_right_back = compose_rotations_xyz(RB_roll, RB_pitch, RB_yaw) @ camera_to_robot()
    print(f'right back sanity check: {R_right_back @ cam_vec_z}')

    rotation_data = {
        "left_front": np.round(R_left_front, 6).tolist(),
        "right_front": np.round(R_right_front, 6).tolist(),
        "left_back": np.round(R_left_back, 6).tolist(),
        "right_back": np.round(R_right_back, 6).tolist(),
    }

    # Print in JSON format
    print(json.dumps(rotation_data, indent=4))
