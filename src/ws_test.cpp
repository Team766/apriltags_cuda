// Copyright (c) 2013-2017, Matt Godbolt
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation
// and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

// An extraordinarily simple test which presents a web page with some buttons.
// Clicking on the numbered button increments the number, which is visible to
// other connected clients.  WebSockets are used to do this: by the rather
// suspicious means of sending raw JavaScript commands to be executed on other
// clients.

#include <cstring>
#include <iostream>
#include <memory>
#include <set>
#include <sstream>
#include <string>
#include <thread>

#include "opencv2/opencv.hpp"
#include "seasocks/PrintfLogger.h"
#include "seasocks/Server.h"
#include "seasocks/StringUtil.h"
#include "seasocks/WebSocket.h"
#include "seasocks/util/Json.h"

using namespace cv;
using namespace seasocks;

class MyHandler : public WebSocket::Handler {
public:
  explicit MyHandler(Server *server) : _server(server) {}

  void onConnect(WebSocket *connection) override {
    _connections.insert(connection);
    std::cout << "Connected: " << connection->getRequestUri() << " : "
              << formatAddress(connection->getRemoteAddress())
              << "\nCredentials: " << *(connection->credentials()) << "\n";
  }

  void onData(WebSocket *connection, const char *data) override {}

  void sendImage(const cv::Mat &image) {
    for (auto c : _connections) {
      std::vector<uchar> buf;
      cv::imencode(".jpg", image, buf);
      c->send(buf.data(), buf.size());
    }
  }

  void onDisconnect(WebSocket *connection) override {
    _connections.erase(connection);
    std::cout << "Disconnected: " << connection->getRequestUri() << " : "
              << formatAddress(connection->getRemoteAddress()) << "\n";
  }

private:
  std::set<WebSocket *> _connections;
  Server *_server;
};

void send_data(std::shared_ptr<MyHandler> handler) {
  Mat bgr_img = cv::imread("data/colorimage.jpg", cv::IMREAD_COLOR);
  while (true) {
    handler->sendImage(bgr_img);
    std::this_thread::sleep_for(std::chrono::seconds(1));
  }
}

int main(int /*argc*/, const char * /*argv*/[]) {
  auto logger = std::make_shared<PrintfLogger>(Logger::Level::Debug);

  Server server(logger);

  auto handler = std::make_shared<MyHandler>(&server);
  server.addWebSocketHandler("/ws", handler);

  std::thread serverThread([&]() { server.serve("web", 9090); });

  std::thread send_thread(send_data, handler);

  send_thread.join();
  serverThread.join();

  return 0;
}
