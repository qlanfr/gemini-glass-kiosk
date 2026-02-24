// GlassKiosk Copilot - API 응답 모델

class Coordinates {
  final int x;
  final int y;
  final int width;
  final int height;

  Coordinates({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory Coordinates.fromJson(Map<String, dynamic> json) {
    return Coordinates(
      x: json['x'] ?? 0,
      y: json['y'] ?? 0,
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
}

class KioskResponse {
  final String detectedLanguage;
  final String? targetItem;
  final String? confirmationMsg;
  final Coordinates? coordinates;
  final String audioResponse;
  final String status;

  KioskResponse({
    required this.detectedLanguage,
    this.targetItem,
    this.confirmationMsg,
    this.coordinates,
    required this.audioResponse,
    required this.status,
  });

  factory KioskResponse.fromJson(Map<String, dynamic> json) {
    return KioskResponse(
      detectedLanguage: json['detected_language'] ?? 'en-US',
      targetItem: json['target_item'],
      confirmationMsg: json['confirmation_msg'],
      coordinates: json['coordinates'] != null
          ? Coordinates.fromJson(json['coordinates'])
          : null,
      audioResponse: json['audio_response'] ?? '',
      status: json['status'] ?? 'error',
    );
  }

  bool get isSuccess => status == 'success';
  bool get needsClarification => status == 'need_clarification';
  bool get hasCoordinates => coordinates != null;
}
