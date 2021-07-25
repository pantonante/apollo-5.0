#include "modules/perception/prefuse_proxy/app/prefuse_proxy.h"

#include <iostream>
#include <string>

#include "modules/common/time/time.h"
#include "modules/common/time/time_util.h"

namespace apollo {
namespace perception {
namespace onboard {

bool PrefusedProxyComponent::Init() {
  // AINFO << "PrefusedProxyComponent init";
  writer_ = node_->CreateWriter<PrefusedObstacles>("/apollo/prefuse");
  AINFO << "PrefusedProxyComponent init";
  seq_num_ = 0;
  return true;
}

bool PrefusedProxyComponent::Proc(
    const std::shared_ptr<SensorFrameMessage>& msg) {
  AINFO << "Prefuse [" << msg->sensor_id_ << "@" << msg->timestamp_ << "]";
  base::FramePtr sensor_frame = msg->frame_;

  std::shared_ptr<PrefusedObstacles> prefused_obstacles =
      std::make_shared<PrefusedObstacles>();
  auto* header = prefused_obstacles->mutable_header();
  // double publish_time = apollo::common::time::Clock::NowInSeconds();
  header->set_timestamp_sec(msg->timestamp_);
  header->set_sequence_num(seq_num_++);
  prefused_obstacles->set_sensor_name(msg->sensor_id_);

  if (sensor_frame != nullptr) {
    AINFO << "Measurement: " << sensor_frame->sensor_info.name
              << ", obj_cnt : " << sensor_frame->objects.size() << ", "
              << sensor_frame->timestamp;

    for (base::ObjectPtr object : sensor_frame->objects) {
      auto* obstacle = prefused_obstacles->add_obstacle();
      auto* hull = obstacle->mutable_hull();
      obstacle->set_theta(object->theta);
      for (auto& pt:object->polygon){
        auto* hull_pt = hull->add_point();
        hull_pt->set_x(pt.x);
        hull_pt->set_y(pt.y);
        hull_pt->set_z(pt.z);
      }
      obstacle->set_type(static_cast<PrefusedObstacle_Type>(object->type));
      obstacle->set_sub_type(static_cast<PrefusedObstacle_SubType>(object->sub_type));
    }
    writer_->Write(prefused_obstacles);
    AINFO << "Send lidar detect output message.";
  } else {
    AINFO << "Empty frame" << std::endl;
  }

  return true;
}

}  // namespace onboard
}  // namespace perception
}  // namespace apollo