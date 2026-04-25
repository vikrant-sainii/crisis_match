import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/connectivity/connectivity_bloc.dart';
import '../blocs/connectivity/connectivity_state.dart';
import '../repositories/low_network_repository.dart';

class ConnectivityVisualizer extends StatelessWidget {
  final Widget child;

  const ConnectivityVisualizer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
