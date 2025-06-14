#include "BooleanValueSender.h"

#include "NetworkTablesConfig.h"

/*
Right now, the table is /SmartDashboard so we can visualize the values sent from
the Orin. Later, this should be changed to a new table, such as /Orin or
/Vision, to avoid populating the SmartDashboard with unnecessary values
*/

BooleanValueSender::BooleanValueSender(std::string key) {
  inst_ = nt::NetworkTableInstance::GetDefault();
  inst_.SetServer(TABLE_ADDRESS);
  inst_.StartClient4(TABLE_ADDRESS);
  auto table = inst_.GetTable(TABLE_NAME);
  nt::BooleanTopic topic = table->GetBooleanTopic(key);
  publisher_ = topic.Publish();
}

void BooleanValueSender::sendValue(bool value) {
  publisher_.Set(value);
  inst_.Flush();
}

void BooleanValueSender::setDefaultValue(bool value) {
  publisher_.SetDefault(value);
}

// Class use example

// int main(){
//   BooleanValueSender sender("NVIDIA ORIN TEST");
//   while(2>1){
//     sender.sendValue(true);
//     std::cout << "Sent value" << std::endl;
//   }
//   return 0;
// }