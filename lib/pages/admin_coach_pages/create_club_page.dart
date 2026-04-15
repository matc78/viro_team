import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import '../../theme/viro_theme.dart';
import '../../widget/viro_loader.dart';
import '../../utils/app_logger.dart';
import '../../utils/safe_navigation.dart';
import '../../utils/firebase_error_handler.dart';
import '../../services/membership_service.dart';
import '../../services/user_session.dart';
import 'admin_shell.dart';

class CreateClubPage extends StatefulWidget {
  const CreateClubPage({super.key});

  @override
  State<CreateClubPage> createState() => _CreateClubPageState();
}

class _CreateClubPageState extends State<CreateClubPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers pour les champs de texte
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedSport;
  final List<String> _sports = [
    'Football',
    'Basketball',
    'Tennis',
    'Volleyball',
    'Handball',
    'Rugby',
    'Judo',
    'Natation',
    'Autre',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createClub() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Calcul de la date de fin de saison par défaut (31 juillet 23h59 de l'année en cours)
      final now = DateTime.now();
      final defaultSeasonEnd = DateTime(now.year, 7, 31, 23, 59);

      // 1. Création du document Club
      DocumentReference
      clubRef = await appFirestore.collection(FirebaseCollections.clubs).add({
        'name': _nameController.text.trim(),
        'city': _cityController.text.trim(),
        'postalCode': _postalCodeController.text.trim(),
        'address': _addressController.text.trim(),
        'sport': _selectedSport,
        'contactEmail': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'description': _descriptionController.text.trim(),
        'adminId': user.uid,
        'admins': [user.uid],
        'members': [user.uid],
        'createdAt': FieldValue.serverTimestamp(),
        'memberCount': 1,
        'seasonEndDate': Timestamp.fromDate(defaultSeasonEnd),
      });

      // 2. Mise à jour de l'utilisateur : activeContext + member/profileSummaries via ensureMemberAndProfileSummary
      final userDoc = await appFirestore
          .collection(FirebaseCollections.users)
          .doc(user.uid)
          .get();
      final existingData = userDoc.data() ?? {};

      final Map<String, dynamic> newActiveContext = {
        'role': 'admin_fondateur',
        'clubId': clubRef.id,
      };

      await appFirestore.collection(FirebaseCollections.users).doc(user.uid).set({
        'activeContext': newActiveContext,
      }, SetOptions(merge: true));

      await MembershipService.instance.ensureMemberAndProfileSummary(
        uid: user.uid,
        clubId: clubRef.id,
        role: 'admin_fondateur',
        isFounderAdmin: true,
        userDataOverride: existingData,
      );

      AppLogger.instance.info(
        'Club créé',
        {
          'clubId': clubRef.id,
          'clubName': _nameController.text.trim(),
          'adminId': user.uid,
          'sport': _selectedSport,
          'city': _cityController.text.trim(),
        },
      );

      if (mounted) {
        await context.read<UserSession>().loadUser(user.uid);
      }
      if (mounted) {
        scheduleDeferredNavigation(() {
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AdminShell()),
            (route) => false,
          );
        });
      }
    } catch (e) {
      AppLogger.instance.error(
        'Erreur lors de la création du club',
        error: e,
        context: {
          'adminId': user.uid,
          'clubName': _nameController.text.trim(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FirebaseErrorHandler.getErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: ViroLoader(size: 80));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Créer mon Club"),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Informations générales",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              _buildTextField(
                controller: _nameController,
                label: "Nom du club",
                hint: "ex: Viroflay FC",
                icon: Icons.business,
              ),

              DropdownButtonFormField<String>(
                initialValue: _selectedSport,
                decoration: _inputDecoration(
                  "Sport principal",
                  Icons.sports_soccer,
                ),
                items: _sports
                    .map(
                      (sport) =>
                          DropdownMenuItem(value: sport, child: Text(sport)),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedSport = val),
                validator: (val) => val == null ? "Champ requis" : null,
              ),

              const SizedBox(height: 16),
              _buildTextField(
                controller: _cityController,
                label: "Ville",
                hint: "ex: Viroflay",
                icon: Icons.location_city,
              ),

              _buildTextField(
                controller: _postalCodeController,
                label: "Code postal",
                hint: "ex: 92130",
                icon: Icons.markunread_mailbox,
                keyboardType: TextInputType.number,
              ),

              _buildTextField(
                controller: _addressController,
                label: "Adresse du siège / terrain",
                hint: "12 rue des sports",
                icon: Icons.map,
              ),

              const Divider(height: 40),
              Text(
                "Contact & Détails",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              _buildTextField(
                controller: _emailController,
                label: "Email de contact",
                hint: "contact@club.com",
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),

              _buildTextField(
                controller: _phoneController,
                label: "Téléphone",
                hint: "06 00 00 00 00",
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),

              _buildTextField(
                controller: _descriptionController,
                label: "Description du club",
                hint: "Parlez-nous de l'histoire du club...",
                icon: Icons.description_outlined,
                maxLines: 3,
              ),

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _createClub,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ViroColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "CRÉER LE CLUB",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: _inputDecoration(label, icon).copyWith(hintText: hint),
        validator: (val) =>
            val == null || val.isEmpty ? "Champ obligatoire" : null,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: ViroColors.primary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ViroColors.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ViroColors.borderColor),
      ),
    );
  }
}
