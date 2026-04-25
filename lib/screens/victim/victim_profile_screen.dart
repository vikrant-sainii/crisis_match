import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart'
    hide PermissionStatus;
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/sos/sos_bloc.dart';
import '../../blocs/sos/sos_event.dart';
import '../../blocs/help_request/help_request_bloc.dart';
import '../../blocs/help_request/help_request_event.dart';
import '../../blocs/chat/chat_bloc.dart';
import '../../blocs/chat/chat_event.dart';
import '../../models/profile_model.dart';

class VictimProfileScreen extends StatefulWidget {
  const VictimProfileScreen({super.key});

  @override
  State<VictimProfileScreen> createState() => _VictimProfileScreenState();
}

class _VictimProfileScreenState extends State<VictimProfileScreen> {
  static const saffron = Color(0xFFFF9933);
  static const green = Color(0xFF138808);

  static final Gradient tricolorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      saffron.withValues(alpha: 0.1),
      Colors.white,
      green.withValues(alpha: 0.1),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.watch<AuthBloc>().state;

    if (authState is! AuthAuthenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profile = authState.profile;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'YOUR PROFILE',
          style: TextStyle(
            color: theme.primaryColor,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.primaryColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 1. Profile Avatar & Name
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: tricolorGradient,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: theme.primaryColor.withOpacity(0.1),
                    child: Icon(
                      Icons.person_rounded,
                      color: theme.primaryColor,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    profile.fullName.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'VICTIM ACCOUNT',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Details List
            _buildDetailSection(
              title: 'IDENTITY DATA',
              items: [
                _buildDetailItem(Icons.email_outlined, 'EMAIL', profile.email),
                _buildDetailItem(
                  Icons.phone_outlined,
                  'PHONE',
                  profile.phone ?? 'NOT LINKED',
                ),
                _buildDetailItem(
                  Icons.fingerprint_rounded,
                  'UID',
                  profile.id.toUpperCase(),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // 3. Emergency Contacts Section
            _buildEmergencyContactsSection(context, profile),
            const SizedBox(height: 40),

            // 4. Security / Logout
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _handleLogout(context),
                icon: const Icon(Icons.power_settings_new_rounded),
                label: const Text(
                  'LOGOUT',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.blueGrey.shade400,
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueGrey.shade300, size: 20),
      title: Text(
        label,
        style: TextStyle(
          color: Colors.blueGrey.shade400,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildEmergencyContactsSection(
    BuildContext context,
    ProfileModel profile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EMERGENCY CONTACTS',
                style: TextStyle(
                  color: Colors.blueGrey.shade400,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                '${profile.emergencyContacts.length}/5',
                style: TextStyle(
                  color: Colors.blueGrey.shade300,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              if (profile.emergencyContacts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No emergency contacts added yet.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
              else
                ...profile.emergencyContacts.map(
                  (contact) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      child: Text(
                        contact.relation[0].toUpperCase(),
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(
                      contact.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      '${contact.relation.toUpperCase()} • ${contact.phone}',
                      style: TextStyle(
                        color: Colors.blueGrey.shade400,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      onPressed: () =>
                          _removeContact(context, profile, contact),
                    ),
                  ),
                ),
              if (profile.emergencyContacts.length < 5)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => _showAddContactOptions(context, profile),
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        size: 20,
                      ),
                      label: const Text(
                        'ADD CONTACT',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddContactOptions(BuildContext context, ProfileModel profile) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ADD EMERGENCY CONTACT',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.contacts_rounded, color: Colors.blue),
              title: const Text(
                'Import from Phone',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _importFromDevice(context, profile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: Colors.blue),
              title: const Text(
                'Enter Manually',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showContactDialog(context, profile);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _importFromDevice(
    BuildContext context,
    ProfileModel profile,
  ) async {
    // 1. Request permission using the new v2 API
    final status = await FlutterContacts.permissions.request(
      PermissionType.readWrite,
    );

    if (status == PermissionStatus.granted) {
      // 2. Open the native picker (Returns a String ID in v2+)
      final contactId = await FlutterContacts.native.showPicker();

      if (contactId != null) {
        // 3. Fetch the actual contact details using the ID
        final contact = await FlutterContacts.get(
          contactId,
          properties: ContactProperties.all,
        );

        if (contact != null && contact.phones.isNotEmpty) {
          final name = contact.displayName;
          final phone = contact.phones.first.number;
          if (mounted) {
            _showContactDialog(
              context,
              profile,
              initialName: name,
              initialPhone: phone,
            );
          }
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Contacts permission is required to import contacts.',
            ),
          ),
        );
      }
    }
  }

  void _showContactDialog(
    BuildContext context,
    ProfileModel profile, {
    String? initialName,
    String? initialPhone,
  }) {
    final nameController = TextEditingController(text: initialName);
    final phoneController = TextEditingController(text: initialPhone);
    final relationController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'ADD CONTACT',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. John Doe',
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: 'e.g. +91 98765 43210',
                ),
                keyboardType: TextInputType.phone,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: relationController,
                decoration: const InputDecoration(
                  labelText: 'Relation',
                  hintText: 'e.g. Father, Friend',
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final newContact = EmergencyContact(
                  name: nameController.text.trim(),
                  phone: phoneController.text.trim(),
                  relation: relationController.text.trim(),
                );
                final newList = List<EmergencyContact>.from(
                  profile.emergencyContacts,
                )..add(newContact);
                context.read<AuthBloc>().add(
                  AuthUpdateEmergencyContactsRequested(newList),
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text(
              'SAVE',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _removeContact(
    BuildContext context,
    ProfileModel profile,
    EmergencyContact contact,
  ) {
    final newList = List<EmergencyContact>.from(profile.emergencyContacts)
      ..remove(contact);
    context.read<AuthBloc>().add(AuthUpdateEmergencyContactsRequested(newList));
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('LOGOUT?'),
        content: const Text('You will be logged out of the emergency uplink.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog

              // 1. Clear active emergency states safely
              try {
                context.read<SosBloc>().add(DisableSos());
              } catch (_) {}

              try {
                context.read<HelpRequestBloc>().add(ClearHelpRequest());
              } catch (_) {}

              try {
                context.read<ChatBloc>().add(ClearChat());
              } catch (_) {}

              // 2. Finally, trigger the global sign-out
              context.read<AuthBloc>().add(AuthSignOutRequested());

              // 3. Pop the profile screen to return to the root (App will then redirect to Login)
              Navigator.pop(context);
            },
            child: const Text(
              'LOGOUT',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
