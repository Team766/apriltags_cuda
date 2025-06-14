#include "DoubleValueSender.h"

#include "NetworkTablesConfig.h"

/*
Right now, the table is /SmartDashboard so we can visualize the values sent from
the Orin. Later, this should be changed to a new table, such as /Orin or
/Vision, to avoid populating the SmartDashboard with unnecessary values
*/

DoubleValueSender::DoubleValueSender(std::string key) {
  inst_ = nt::NetworkTableInstance::GetDefault();
  inst_.SetServer(TABLE_ADDRESS);
  inst_.StartClient4(TABLE_ADDRESS);
  auto table = inst_.GetTable(TABLE_NAME);
  nt::DoubleTopic topic = table->GetDoubleTopic(key);
  publisher_ = topic.Publish();
}

void DoubleValueSender::sendValue(double value) {
  publisher_.Set(value);
  inst_.Flush();
}

void DoubleValueSender::setDefaultValue(double value) {
  publisher_.SetDefault(value);
}

// Class use example

// int main(){
//   DoubleValueSender sender("NVIDIA ORIN TEST");
//   while(2>1){
//     sender.sendValue(1.0);
//     std::cout << "Sent value" << std::endl;
//   }
//   return 0;
// }