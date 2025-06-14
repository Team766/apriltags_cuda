#include "DoubleArraySender.h"

#include "NetworkTablesConfig.h"

/*
Right now, the table is /SmartDashboard so we can visualize the values sent from
the Orin. Later, this should be changed to a new table, such as /Orin or
/Vision, to avoid populating the SmartDashboard with unnecessary values
*/

DoubleArraySender::DoubleArraySender(std::string key) {
  inst_ = nt::NetworkTableInstance::GetDefault();
  inst_.SetServer(TABLE_ADDRESS);
  inst_.StartClient4(TABLE_ADDRESS);
  auto table = inst_.GetTable(TABLE_NAME);
  nt::DoubleArrayTopic topic = table->GetDoubleArrayTopic(key);
  publisher_ = topic.Publish();
}
void DoubleArraySender::sendValue(std::vector<double> value) {
  publisher_.Set(value);
  inst_.Flush();
}
void DoubleArraySender::setDefaultValue(std::vector<double> value) {
  publisher_.SetDefault(value);
}

// Class use example

// int main(){
//   DoubleArraySender sender("NVIDIA ORIN ARRAY TEST");
//   while(2>1){
//     std::vector<double> values = {1.0, 2.0, 3.0};
//     sender.sendValue(values);
//     std::cout << "Sent value" << std::endl;
//   }
//   return 0;
// }