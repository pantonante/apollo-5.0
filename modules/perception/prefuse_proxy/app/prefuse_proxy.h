#pragma once

#include <memory>
#include <string>
#include <vector>

#include "cyber/component/component.h"
#include "cyber/cyber.h"
#include "modules/perception/onboard/inner_component_messages/inner_component_messages.h"
#include "modules/perception/prefuse_proxy/proto/prefuse_obstacle.pb.h"

namespace apollo {
namespace perception {
namespace onboard {

class PrefusedProxyComponent : public cyber::Component<SensorFrameMessage> {
 private:
  std::shared_ptr<apollo::cyber::Writer<PrefusedObstacles>> writer_;
  unsigned int seq_num_;


 public:
  bool Init() override;
  bool Proc(const std::shared_ptr<SensorFrameMessage>& msg) override;
};
CYBER_REGISTER_COMPONENT(PrefusedProxyComponent)

}  // namespace onboard
}  // namespace perception
}  // namespace apollo