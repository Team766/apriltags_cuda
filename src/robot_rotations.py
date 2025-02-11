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


if __name__ == "__main__":
    """
    Robot coordinates (right-handed):
        X forward, Y to the right, Z up.

    Camera coordinates (OpenCV style):
        Z out of the camera (optical axis),
        X to the right (columns),
        Y down (rows).

    Goal:
      - Left/Right front cameras => camera Z aligns with robot +X.
      - Left/Right back cameras  => camera Z aligns with robot -X.

    That means:
      [0, 0, 1]_cam -> [+1, 0, 0]_robot  (front)
      [0, 0, 1]_cam -> [-1, 0, 0]_robot  (back)
    """

    # ------------------------------------------------------------
    # LEFT FRONT CAMERA
    # We want the camera Z-axis to map to robot -X-axis.
    LF_roll = -90
    LF_pitch = -90 + 24.784
    LF_yaw = 0

    # LF_roll = -90
    # LF_pitch = 90  # about Y
    # LF_yaw = 0
    R_left_front = compose_rotations_xyz(LF_roll, LF_pitch, LF_yaw)

    # ------------------------------------------------------------
    # RIGHT FRONT CAMERA
    # Likely the same if it also points forward, or you might tweak
    # roll/yaw if physically mounted differently.
    RF_roll = -90
    RF_pitch = -90 + 24.784
    RF_yaw = 0

    # RF_roll = -90
    # RF_pitch = 90
    # RF_yaw = 0
    R_right_front = compose_rotations_xyz(RF_roll, RF_pitch, RF_yaw)

    # ------------------------------------------------------------
    # LEFT BACK CAMERA
    # We want the camera Z-axis to map to robot +X-axis
    # LF_roll = -90
    # LF_pitch = 90  # about Y
    # LF_yaw = 0

    LB_roll = -90
    LB_pitch = 90
    LB_yaw = 45
    R_left_back = compose_rotations_xyz(LB_roll, LB_pitch, LB_yaw)

    # ------------------------------------------------------------
    # RIGHT BACK CAMERA
    # Also mapping camera Z to -X. Possibly add slight tweaks for real hardware.
    # RB_roll = -90
    # RB_pitch = -90
    # RB_yaw = 0

    RB_roll = -90
    RB_pitch = 90
    RB_yaw = -45
    R_right_back = compose_rotations_xyz(RB_roll, RB_pitch, RB_yaw)

    rotation_data = {
        "left_front": np.round(R_left_front, 6).tolist(),
        "right_front": np.round(R_right_front, 6).tolist(),
        "left_back": np.round(R_left_back, 6).tolist(),
        "right_back": np.round(R_right_back, 6).tolist(),
    }

    # Print in JSON format
    print(json.dumps(rotation_data, indent=4))
