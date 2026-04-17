import 'package:equatable/equatable.dart';

class CrisisHelperModel extends Equatable {
  final String crisisType;
  final String occupation;

  const CrisisHelperModel({
    required this.crisisType,
    required this.occupation,
  });

  factory CrisisHelperModel.fromJson(Map<String, dynamic> json) {
    return CrisisHelperModel(
      crisisType: json['crisis_type'] as String? ?? '',
      occupation: json['occupation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'crisis_type': crisisType,
      'occupation': occupation,
    };
  }

  @override
  List<Object?> get props => [crisisType, occupation];
}
