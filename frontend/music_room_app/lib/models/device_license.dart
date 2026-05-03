enum DeviceType {
  ios,
  android,
  web;

  static DeviceType fromString(String value) {
    return DeviceType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => DeviceType.web,
    );
  }

  String toJson() => name;
}

class DeviceLicense {
  final String id;
  final String userId;
  final String deviceId;
  final DeviceType deviceType;
  final bool canControlMusic;

  DeviceLicense({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.deviceType,
    this.canControlMusic = false,
  });

  factory DeviceLicense.fromJson(Map<String, dynamic> json) {
    return DeviceLicense(
      id: json['id'] as String,
      userId: json['userId'] as String,
      deviceId: json['deviceId'] as String,
      deviceType: DeviceType.fromString(json['deviceType'] as String),
      canControlMusic: json['canControlMusic'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'deviceId': deviceId,
    'deviceType': deviceType.toJson(),
    'canControlMusic': canControlMusic,
  };
}
