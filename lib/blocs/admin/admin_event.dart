import 'package:equatable/equatable.dart';
import '../../models/help_request_model.dart';

abstract class AdminEvent extends Equatable {
  const AdminEvent();

  @override
  List<Object?> get props => [];
}

class LoadAdminData extends AdminEvent {}

class ApproveRequest extends AdminEvent {
  final HelpRequestModel request;
  const ApproveRequest(this.request);

  @override
  List<Object?> get props => [request];
}

class AddHelperAccount extends AdminEvent {
  final String email;
  final String password;
  final String fullName;
  final String occupation;
  final String state;
  final double lat;
  final double lng;

  const AddHelperAccount({
    required this.email,
    required this.password,
    required this.fullName,
    required this.occupation,
    required this.state,
    required this.lat,
    required this.lng,
  });

  @override
  List<Object?> get props => [email, password, fullName, occupation, state, lat, lng];
}

class FilterHelpersByOccupation extends AdminEvent {
  final String? occupation;
  const FilterHelpersByOccupation(this.occupation);

  @override
  List<Object?> get props => [occupation];
}

// A new UpdateAdminApprovals event ensures that the "Approvals" tab stays 
//perfectly in sync with field operations while strictly 
//preserving the existing map state and helper filters.

class UpdateAdminApprovals extends AdminEvent {
  final List<HelpRequestModel> pendingApprovals;
  const UpdateAdminApprovals(this.pendingApprovals);

  @override
  List<Object?> get props => [pendingApprovals];
}

class BlockVictim extends AdminEvent {
  final String profileId;
  final String requestId;
  const BlockVictim({required this.profileId, required this.requestId});

  @override
  List<Object?> get props => [profileId, requestId];
}

class UpdateAdminSpamReports extends AdminEvent {
  final List<HelpRequestModel> spamReports;
  const UpdateAdminSpamReports(this.spamReports);

  @override
  List<Object?> get props => [spamReports];
}
