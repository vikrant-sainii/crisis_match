import 'package:equatable/equatable.dart';
import '../../models/help_request_model.dart';

abstract class AdminState extends Equatable {
  const AdminState();

  @override
  List<Object?> get props => [];
}

class AdminInitial extends AdminState {}

class AdminLoading extends AdminState {}

class AdminDataLoaded extends AdminState {
  final List<Map<String, dynamic>> helpers;
  final List<HelpRequestModel> pendingApprovals;
  final List<HelpRequestModel> spamReports;
  final List<String> occupations;
  final String? selectedOccupation;

  const AdminDataLoaded({
    required this.helpers,
    required this.pendingApprovals,
    required this.spamReports,
    required this.occupations,
    this.selectedOccupation,
  });

  @override
  List<Object?> get props => [helpers, pendingApprovals, spamReports, occupations, selectedOccupation];
}

class AdminActionSuccess extends AdminState {
  final String message;
  const AdminActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class AdminActionError extends AdminState {
  final String error;
  const AdminActionError(this.error);

  @override
  List<Object?> get props => [error];
}
