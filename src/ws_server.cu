#include <gflags/gflags.h>
#include <glog/logging.h>
#include <seasocks/PrintfLogger.h>
#include <seasocks/Server.h>
#include <seasocks/StringUtil.h>
#include <seasocks/WebSocket.h>

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <memory>
#include <mutex>
#include <nlohmann/json.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/opencv.hpp>
#include <set>
#include <span>
#include <string>
#include <thread>
#include <vector>

#include "BooleanValueSender.h"
#include "DoubleArraySender.h"
#include "DoubleValueSender.h"
#include "IntegerArraySender.h"
#include "IntegerValueSender.h"
#include "NetworkTablesUtil.h"
#include "apriltag_gpu.h"
#include "apriltag_utils.h"
#include "cameraexception.h"
#include "opencv2/opencv.hpp"

extern "C" {
#include "apriltag.h"
#include "apriltag_pose.h"
#include "common/zarray.h"
}

// todo: make this work
#define TAGSIZE 0.1651 // tag size, in meters

using json = nlohmann::json;

DEFINE_int32(camera_idx, 0, "Camera index");
DEFINE_string(cal_file, "", "path name to calibration file");
DEFINE_bool(rotate_vertical, false,
            "Rotates image by 180 degrees prior to detecting apriltags");
DEFINE_bool(rotate_horizontal, false,
            "Rotates image by 90 degrees prior to detecting apriltags");
DEFINE_int32(port, -1, "Server port to run webserver");
DEFINE_string(camera_name, "", "name of camera as setup on java side");
DEFINE_string(position_file, "", "path name to the position file");

enum ExposureMode { AUTO = 0, MANUAL = 1 };

class AprilTagHandler : public seasocks::WebSocket::Handler {
 public:
  AprilTagHandler(std::shared_ptr<seasocks::Server> server) : server_(server) {}

  void onConnect(seasocks::WebSocket* socket) override {
    std::lock_guard<std::mutex> lock(mutex_);
    clients_.insert(socket);
  }

  void onDisconnect(seasocks::WebSocket* socket) override {
    std::lock_guard<std::mutex> lock(mutex_);
    clients_.erase(socket);
  }

  void onData(seasocks::WebSocket* socket, const char* data) override {
    try {
      std::cerr << "Received data: " << data << std::endl;
      auto j = json::parse(data);
      settings_changed_ = false;
      if (j["type"] == "brightness") {
        brightness_ = j["value"].get<int>();
        settings_changed_ = true;
      }
      if (j["type"] == "exposure") {
        exposure_ = j["value"].get<int>();
        settings_changed_ = true;
      }
      if (j["type"] == "exposure-mode") {
        exposure_mode_ = j["value"].get<int>();
        settings_changed_ = true;
      }
      if (j["type"] == "flipVertical") {
        flipVertical_ = j["value"].get<bool>();
        settings_changed_ = true;
      }
      if (j["type"] == "flipHorizontal") {
        flipHorizontal_ = j["value"].get<bool>();
        settings_changed_ = true;
      }
      if(j["type"] == "developer_mode"){
        developer_mode_ = j["value"].get<bool>();
        settings_changed_ = true;
      }
      if(j["type"] == "rotation_matrix") {
        std::vector<double> rotationMatrix = j["value"];
        rotationCoefficentsDevMode_ = (cv::Mat_<double>(3, 3) << 
                       rotationMatrix[0], rotationMatrix[1], rotationMatrix[2],
                       rotationMatrix[3], rotationMatrix[4], rotationMatrix[5],
                       rotationMatrix[6], rotationMatrix[7], rotationMatrix[8]);
      }
      if(j["type"] == "offset_vector") {
        std::vector<double> offsetVector = j["value"];
        offsetCoefficentsFromDevMode_ = (cv::Mat_<double> (3, 1) << offsetVector[0], offsetVector[1], offsetVector[2]);
      }

    } catch (const json::parse_error& e) {
      LOG(ERROR) << "JSON parse error: " << e.what();
    }
  }

  void broadcastImage(const std::vector<uint8_t>& imageData) {
    std::vector<uint8_t> message;
    // Prefix for image messages (5 bytes)
    const std::string prefix = "IMG::";
    message.insert(message.end(), prefix.begin(), prefix.end());
    message.insert(message.end(), imageData.begin(), imageData.end());

    server_->execute([this, message] {
      std::lock_guard<std::mutex> lock(mutex_);
      for (auto client : clients_) {
        client->send(message.data(), message.size());
      }
    });
  }

  void broadcastPoseData(const std::string& poseDataJson) {
    std::string prefix = "POSE:";
    std::string message = prefix + poseDataJson;
    std::vector<uint8_t> messageBytes(message.begin(), message.end());

    server_->execute([this, messageBytes] {
      std::lock_guard<std::mutex> lock(mutex_);
      for (auto client : clients_) {
        client->send(messageBytes.data(), messageBytes.size());
      }
    });
  }

  bool parsecal_file(const std::string& cal_filepath,
                     const std::string& position_filepath,
                     frc971::apriltag::CameraMatrix* cam,
                     frc971::apriltag::DistCoeffs* dist) {
    std::ifstream f(cal_filepath);
    json data = json::parse(f);
    std::ifstream f2(position_filepath);
    json data2 = json::parse(f2);

    // Ensure the keys that we are expecting to find are actually
    // present in the file.
    if (!data.contains("matrix")) {
      LOG(ERROR) << "key \"matrix\" not found in calibration file.";
      return false;
    }
    if (!data.contains("disto")) {
      LOG(ERROR) << "key \"disto\" not found in calibration file.";
      return false;
    }
    if(!data2.contains("rotation")){ 
      LOG(ERROR) << "key \"rotation\" not found in location file.";
      return false;
    }
    if(!data2.contains("offset")){
      LOG(ERROR) << "key \"offset\" not found in location file.";
      return false;
    }

    // Setup Camera Matrix
    // Intrinsic Matrices are explained here:
    // https://docs.opencv.org/4.x/d9/d0c/group__calib3d.html
    cam->fx = data["matrix"][0][0];
    cam->fy = data["matrix"][1][1];
    cam->cx = data["matrix"][0][2];
    cam->cy = data["matrix"][1][2];

    // Setup Distortion Coefficients
    // OpenCV writes them out in the order specified here:
    // https://docs.opencv.org/4.x/d9/d0c/group__calib3d.html
    dist->k1 = data["disto"][0][0];
    dist->k2 = data["disto"][0][1];
    dist->p1 = data["disto"][0][2];
    dist->p2 = data["disto"][0][3];
    dist->k3 = data["disto"][0][4];

    double rotationCoefficents[9] = {0,0,0,0,0,0,0,0,0};
    int c = 0;
    for(int i = 0; i < 3; i++){
      for(int j = 0; j < 3; j++){
        rotationCoefficents[c] = data2["rotation"][i][j];
        c += 1;
      }
    }
    double offsetCoeficients[3] = {0,0,0};
    for(int i = 0; i < 3; i++){
      offsetCoeficients[i] = data2["offset"][i];
    }

    rotationCoefficents_ = (cv::Mat_<double>(3, 3) << 
                       rotationCoefficents[0], rotationCoefficents[1], rotationCoefficents[2],
                       rotationCoefficents[3], rotationCoefficents[4], rotationCoefficents[5],
                       rotationCoefficents[6], rotationCoefficents[7], rotationCoefficents[8]);

    offsetCoefficents_ = (cv::Mat_<double>(3,1) <<
                       offsetCoeficients[0], offsetCoeficients[1], offsetCoeficients[2]);
    // Some debug print statements
    std::cout << "Loaded calibration matrix:" << std::endl;
    std::cout << "cam.fx: " << cam->fx << std::endl;
    std::cout << "cam.fy: " << cam->fy << std::endl;
    std::cout << "cam.cx: " << cam->cx << std::endl;
    std::cout << "cam.cy: " << cam->cy << std::endl << std::endl;
    std::cout << "Loaded distortion coefficients: " << std::endl;
    std::cout << "dist.k1: " << dist->k1 << std::endl;
    std::cout << "dist.k2: " << dist->k2 << std::endl;
    std::cout << "dist.p1: " << dist->p1 << std::endl;
    std::cout << "dist.p2: " << dist->p2 << std::endl;
    std::cout << "dist.k3: " << dist->k3 << std::endl << std::endl;
    

    return true;
  }
  // Flipcode -1 = both directions
  void flipVertical(const cv::Mat& bgr_img, cv::Mat* output_img) {
    cv::flip(bgr_img, *output_img, 0);
  }
  void flipHorizontal(const cv::Mat& bgr_img, cv::Mat* output_img) {
    cv::flip(bgr_img, *output_img, 1);
  }
  void flipBoth(const cv::Mat& bgr_img, cv::Mat* output_img) {
    cv::flip(bgr_img, *output_img, -1);
  }
  void startReadAndSendThread(const int camera_idx, const std::string& cal_file,
                              const std::string& position_file,
                              const bool rotate_vertical,
                              const bool rotate_horizontal) {
    read_thread_ = std::thread(&AprilTagHandler::readAndSend, this, camera_idx,
                               cal_file, position_file, rotate_vertical, rotate_horizontal);
  }

  void joinReadAndSendThread() {
    if (read_thread_.joinable()) {
      read_thread_.join();
    }
  }

  void printCameraSettings(const cv::VideoCapture& cap) {
    int frame_width = cap.get(cv::CAP_PROP_FRAME_WIDTH);
    int frame_height = cap.get(cv::CAP_PROP_FRAME_HEIGHT);
    int frame_rate = cap.get(cv::CAP_PROP_FPS);

    std::cout << "  " << frame_width << "x" << frame_height << " @"
              << frame_rate << "FPS" << std::endl;

    std::cout << " format is: " << cap.get(cv::CAP_PROP_FORMAT) << std::endl;

    std::cout << "AUTO Exposure: " << cap.get(cv::CAP_PROP_AUTO_EXPOSURE)
              << std::endl;
    std::cout << "Brightness: " << cap.get(cv::CAP_PROP_BRIGHTNESS)
              << std::endl;
    std::cout << "Contrast: " << cap.get(cv::CAP_PROP_CONTRAST) << std::endl;
  }

  void readAndSend(const int camera_idx, const std::string& cal_file,
                   const std::string& position_file,
                   const bool rotate_vertical, const bool rotate_horizontal) {
    std::cout << "Enabling video capture" << std::endl;
    bool camera_started = false;
    cv::VideoCapture cap;
    while (!camera_started) {
      try {
        cap.open(camera_idx, cv::CAP_V4L);
        if (cap.isOpened()) {
          camera_started = true;
          std::cout << "Camera started successfully on index " << camera_idx
                    << std::endl;
        } else {
          throw CameraException();
        }
      } catch (const CameraException& e) {
        std::cout << "Couldn't open video capture device: " << e.what()
                  << std::endl;
        std::cout << "Retrying in 1 second ...";
        std::this_thread::sleep_for(std::chrono::seconds(1));
      }
    }

    // Set video mode, resolution and frame rate.
    int fourcc = cv::VideoWriter::fourcc('M', 'J', 'P', 'G');
    cap.set(cv::CAP_PROP_FOURCC, fourcc);
    cap.set(cv::CAP_PROP_FRAME_WIDTH, 1280);
    cap.set(cv::CAP_PROP_FRAME_HEIGHT, 800);
    cap.set(cv::CAP_PROP_FPS, 30);
    cap.set(cv::CAP_PROP_CONVERT_RGB, true);

    int frame_width = cap.get(cv::CAP_PROP_FRAME_WIDTH);
    int frame_height = cap.get(cv::CAP_PROP_FRAME_HEIGHT);
    printCameraSettings(cap);

    // Setup the apriltag detector.
    apriltag_family_t* tf = nullptr;
    apriltag_detector_t* td = nullptr;
    const char* tag_family = "tag36h11";
    setup_tag_family(&tf, tag_family);
    td = apriltag_detector_create();
    apriltag_detector_add_family(td, tf);

    td->quad_decimate = 2.0;
    td->quad_sigma = 0.0;
    td->nthreads = 1;
    td->debug = false;
    td->refine_edges = true;
    td->wp = workerpool_create(4);

    // Read Camera Matrix and Distortion Coeffs from file.
    frc971::apriltag::CameraMatrix cam;
    frc971::apriltag::DistCoeffs dist;
    if (!parsecal_file(cal_file, position_file, &cam, &dist)) {
      std::cout << "Unable to read parameters from cal file " << cal_file
                << "or parameters from location file " << position_file
                << std::endl;
      return;
    }

    auto gpucreatestart = std::chrono::high_resolution_clock::now();
    frc971::apriltag::GpuDetector detector(frame_width, frame_height, td, cam,
                                           dist);
    auto gpucreateend = std::chrono::high_resolution_clock::now();

    auto gpucreateduration =
        std::chrono::duration_cast<std::chrono::milliseconds>(gpucreateend -
                                                              gpucreatestart);
    std::cout << "GPU Detector Create Time: " << gpucreateduration.count()
              << " ms" << std::endl;

    // Setup the detection info struct for use down below.
    apriltag_detection_info_t info;
    info.tagsize = TAGSIZE;  // Measured in meters, with a ruler, for tag family 36h11
    info.fx = cam.fx;
    info.fy = cam.fy;
    info.cx = cam.cx;
    info.cy = cam.cy;

    // Set the value of the gui rotate image variable to the value
    // that is passed in on the command line.  The user can change it
    // later on from the gui.
    flipVertical_ = rotate_vertical;
    flipHorizontal_ = rotate_horizontal;

    int frame_counter = 0;
    cv::Mat bgr_img, yuyv_img;
    while (running_) {
      // Handle settings changes.
      if (settings_changed_.exchange(false)) {
        std::cout << "Setting changed" << std::endl;
        if (exposure_mode_ == 0) {
          std::cout << "Auto Exposure set to Auto" << std::endl;
          cap.set(cv::CAP_PROP_AUTO_EXPOSURE, 3);
        } else if (exposure_mode_ == 1) {
          std::cout << "Auto Exposure set to Manual" << std::endl;
          cap.set(cv::CAP_PROP_AUTO_EXPOSURE, 1);
          cap.set(cv::CAP_PROP_BRIGHTNESS, brightness_);
          cap.set(cv::CAP_PROP_EXPOSURE, exposure_);
        }
      }

      try {
        cap >> bgr_img;
        double frameReadTime = ntUtil_.getTime();
        frame_counter++;

        auto overallstart = std::chrono::high_resolution_clock::now();
        // Let's check the time this takes, can always combine to one call if
        // both are true later. Best case scenario is we don't place the camera
        // wrong so we do not need this method at all.
        if (flipVertical_ && flipHorizontal_) {
          flipBoth(bgr_img.clone(), &bgr_img);
        } else {
          // if (flipVertical_) {
          //   flipVertical(bgr_img.clone(), &bgr_img);
          // }
          // if (flipHorizontal_) {
          //   flipHorizontal(bgr_img.clone(), &bgr_img);
          // }
        }

        cv::cvtColor(bgr_img, yuyv_img, cv::COLOR_BGR2YUV_YUYV);
        auto gpudetectstart = std::chrono::high_resolution_clock::now();
        detector.Detect(yuyv_img.data);
        auto gpudetectend = std::chrono::high_resolution_clock::now();
        const zarray_t* detections = detector.Detections();
        draw_detection_outlines(bgr_img, const_cast<zarray_t*>(detections));

        // Broadcast the image to websocket clients.
        if (frame_counter % 50 == 0) {
          // Encode the image to JPEG
          std::vector<uchar> buffer;
          cv::imencode(".jpg", bgr_img, buffer);
          broadcastImage(buffer);
          frame_counter = 0;
        }
        std::vector<double> networktables_pose_data = {};
        json empty_detections_record;
        std::string pose_json = "";
        empty_detections_record["type"] = "pose_data";
        empty_detections_record["EMPTY"] = "true";
        pose_json = empty_detections_record.dump();
        // Determine the pose of the tags.
        if (zarray_size(detections) > 0) {
          // std::vector<std::vector<double>> poses = {};
          json detections_record;
          detections_record["type"] = "pose_data";
          detections_record["detections"] = json::array();

          for (int i = 0; i < zarray_size(detections); i++) {
            json record;

            apriltag_detection_t* det;
            zarray_get(const_cast<zarray_t*>(detections), i, &det);

            // Setup the detection info struct for use down below.
            info.det = det;

            apriltag_pose_t pose;
            double err = estimate_tag_pose(&info, &pose);
            matd_print(pose.R, "%.3f ");
            matd_print(pose.t, "%.3f ");
            // std::vector <double> pose_data = {pose.R, pose.t};
            std::cout << "Pose Error: " << err << std::endl;

            record["id"] = det->id;
            record["hamming"] = det->hamming;
            record["pose_error"] = err;

            // Store pose in the json record
            record["rotation"] = {
                {pose.R->data[0], pose.R->data[1], pose.R->data[2]},
                {pose.R->data[3], pose.R->data[4], pose.R->data[5]},
                {pose.R->data[6], pose.R->data[7], pose.R->data[8]}};

            cv::Vec3d aprilTagInCameraFrame(pose.t->data[0], pose.t->data[1], pose.t->data[2]);
            cv::Mat aprilTagInCameraFrameAsMat = cv::Mat(aprilTagInCameraFrame);
            cv::Mat aprilTagInRobotFrame;
            if(developer_mode_){
              aprilTagInRobotFrame = rotationCoefficentsDevMode_ * aprilTagInCameraFrameAsMat + offsetCoefficentsFromDevMode_;
            } else {
              aprilTagInRobotFrame = rotationCoefficents_ * aprilTagInCameraFrameAsMat + offsetCoefficents_;
            }
            
            record["translation"] = {aprilTagInRobotFrame.at<double>(0), aprilTagInRobotFrame.at<double>(1), aprilTagInRobotFrame.at<double>(2)};

            detections_record["detections"].push_back(record);
            networktables_pose_data.push_back(frameReadTime);
            networktables_pose_data.push_back(det->id * 1.0);

            networktables_pose_data.push_back(aprilTagInRobotFrame.at<double>(0));
            networktables_pose_data.push_back(aprilTagInRobotFrame.at<double>(1));
            networktables_pose_data.push_back(aprilTagInRobotFrame.at<double>(2));
          }

          // Send the pose data
          pose_json = detections_record.dump();

          auto overallend = std::chrono::high_resolution_clock::now();
          auto overallduration =
              std::chrono::duration_cast<std::chrono::milliseconds>(
                  overallend - overallstart);
          auto gpudetectduration =
              std::chrono::duration_cast<std::chrono::milliseconds>(
                  gpudetectend - gpudetectstart);
          std::cout << "Total Elapsed time: " << overallduration.count()
                    << " ms" << std::endl;
          // std::cout << "GPU Elapsed time: " << gpuoverallduration.count() <<
          // " ms" << std::endl; std::cout << "GPU Detector Create time: " <<
          // gpucreateduration.count() << " ms" << std::endl;
          std::cout << "GPU Detect time: " << gpudetectduration.count() << " ms"
                    << std::endl;

          detector.ReinitializeDetections();
        }
        broadcastPoseData(pose_json);
        tagSender_.sendValue(networktables_pose_data);

      } catch (const std::exception& ex) {
        std::cout << "Encounted exception " << ex.what() << std::endl;
        std::cout << "Continuing." << std::endl;
      }
    }
    // Clean up
    apriltag_detector_destroy(td);
    teardown_tag_family(&tf, tag_family);
  }

  void stop() { running_ = false; }

 private:
  DoubleArraySender tagSender_{FLAGS_camera_name};

  cv::Mat rotationCoefficents_;
  cv::Mat offsetCoefficents_;
  NetworkTablesUtil ntUtil_{};
  std::set<seasocks::WebSocket*> clients_;
  std::mutex mutex_;
  std::shared_ptr<seasocks::Server> server_;
  std::atomic<bool> running_{true};
  std::atomic<int> brightness_{50};
  std::atomic<int> exposure_{50};
  std::atomic<int> exposure_mode_{0};
  std::atomic<bool> settings_changed_{false};
  std::atomic<bool> flipVertical_{false};
  std::atomic<bool> flipHorizontal_{false};
  std::atomic<bool> developer_mode_{false};
  std::thread read_thread_;
  cv::Mat rotationCoefficentsDevMode_;
  cv::Mat offsetCoefficentsFromDevMode_;
};

int main(int argc, char* argv[]) {
  google::InitGoogleLogging(argv[0]);
  google::SetVLOGLevel("*", FLAGS_v);

  gflags::ParseCommandLineFlags(&argc, &argv, true);

  if (FLAGS_cal_file.empty() || FLAGS_position_file.empty()) {
    LOG(ERROR) << "Usage: ws_server -camera_idx <index> -cal_file <path to cal "
                  "file> -position_file <path to position file> -port <webserver "
                  "port>";
  }

  if (FLAGS_camera_name.empty()) {
    LOG(ERROR) << "camera_name is required";
    return 1;
  }

  if (!std::filesystem::exists(FLAGS_cal_file)) {
    LOG(ERROR) << "calibration file does not exist: " << FLAGS_cal_file;
    return 1;
  }
  
  if (!std::filesystem::exists(FLAGS_position_file)) {
    LOG(ERROR) << "position file does not exist: " << FLAGS_position_file;
    return 1;
  }

  auto logger = std::make_shared<seasocks::PrintfLogger>();
  auto server = std::make_shared<seasocks::Server>(logger);

  try {
    auto handler = std::make_shared<AprilTagHandler>(server);
    server->addWebSocketHandler("/ws", handler);

    handler->startReadAndSendThread(FLAGS_camera_idx, FLAGS_cal_file,
                                    FLAGS_position_file,
                                    FLAGS_rotate_vertical,
                                    FLAGS_rotate_horizontal);
    int port;
    if (FLAGS_port == -1) {
      // User did not specify the port so make it relative to
      // the camera idx to support multiple cameras seamlessly.
      port = 8080 + FLAGS_camera_idx;

    } else {
      // User asked for a specific port so we'll serve from that.
      port = FLAGS_port;
    }
    LOG(INFO) << "Serving the webpage on port " << port;
    server->serve("public", port);

    handler->stop();
    handler->joinReadAndSendThread();
  } catch (const std::exception& e) {
    LOG(ERROR) << e.what();
    return 1;
  }

  gflags::ShutDownCommandLineFlags();

  return 0;
}
