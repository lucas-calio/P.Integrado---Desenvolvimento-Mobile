class StoxAction {
  final String action;
  final Map<String, dynamic> params;

  StoxAction({
    required this.action,
    required this.params,
  });

  factory StoxAction.fromJson(Map<String, dynamic> json) {
    return StoxAction(
      action: json['action'],
      params: json['params'] ?? {},
    );
  }
}