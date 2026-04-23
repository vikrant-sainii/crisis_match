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
    return BlocBuilder<ConnectivityBloc, ConnectivityState>(
      builder: (context, state) {
        Color barColor;
        String statusText;
        IconData icon;

        switch (state.status) {
          case ConnectivityStatus.online:
            barColor = Colors.greenAccent.shade700;
            statusText = "ONLINE";
            icon = Icons.wifi;
            break;
          case ConnectivityStatus.lowNetwork:
            barColor = Colors.orangeAccent;
            statusText = "LOW NETWORK (${state.latency}ms)";
            icon = Icons.network_check;
            break;
          case ConnectivityStatus.offline:
            barColor = Colors.redAccent;
            statusText = "OFFLINE - SMS MODE";
            icon = Icons.portable_wifi_off;
            break;
        }

        return Stack(
          children: [
            Column(
              children: [
                // The Signal Bar
                Container(
                  height: 3,
                  width: double.infinity,
                  color: barColor,
                  child: state.status == ConnectivityStatus.online
                      ? null
                      : LinearProgressIndicator(
                          backgroundColor: barColor.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        ),
                ),
                Expanded(child: child),
              ],
            ),
            // Floating Status Pill (Top Right)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: AnimatedOpacity(
                opacity: state.status == ConnectivityStatus.online ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 500),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: barColor, width: 1),
                    boxShadow: [
                      BoxShadow(color: barColor.withOpacity(0.5), blurRadius: 8)
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: barColor, size: 12),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: barColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
