import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:viro_team_v2/config/routes.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/features/auth/providers/auth_providers.dart';
import 'package:viro_team_v2/features/club_setup/models/club_setup_draft.dart';
import 'package:viro_team_v2/features/club_setup/providers/club_setup_provider.dart';
import 'package:viro_team_v2/models/club.dart';
import 'package:viro_team_v2/models/viro_user.dart';
import 'package:viro_team_v2/providers/service_providers.dart';
import 'package:viro_team_v2/utils/viro_snackbar.dart';
import 'package:viro_team_v2/widgets/common/viro_primary_button.dart';
import 'package:viro_team_v2/widgets/common/viro_scaffold.dart';

class ClubSetupWizardScreen extends ConsumerStatefulWidget {
  const ClubSetupWizardScreen({super.key});

  @override
  ConsumerState<ClubSetupWizardScreen> createState() =>
      _ClubSetupWizardScreenState();
}

class _ClubSetupWizardScreenState extends ConsumerState<ClubSetupWizardScreen> {
  final _pageController = PageController();
  int _step = 0;
  bool _submitting = false;
  static const _totalSteps = 6;

  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalController = TextEditingController();
  final _addressController = TextEditingController();
  final _locationNameController = TextEditingController();
  final _locationAddressController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _cityController.dispose();
    _postalController.dispose();
    _addressController.dispose();
    _locationNameController.dispose();
    _locationAddressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _syncDraftFromControllers() {
    ref.read(clubSetupProvider.notifier).updateDraft((d) {
      d.name = _nameController.text.trim();
      d.description = _descriptionController.text.trim();
      d.city = _cityController.text.trim();
      d.postalCode = _postalController.text.trim();
      d.address = _addressController.text.trim();
      return d;
    });
  }

  Future<ViroUser?> _resolveCurrentUser() async {
    final cached = ref.read(viroUserProvider).value;
    if (cached != null) return cached;

    final authUser = ref.read(authStateProvider).value;
    if (authUser == null) return null;

    return ref.read(userServiceProvider).getUser(authUser.uid);
  }

  void _next() {
    _dismissKeyboard();
    if (_step == 1 || _step == 3) {
      _syncDraftFromControllers();
    }
    final draft = ref.read(clubSetupProvider);
    if (_step == 1 && !draft.canProceedIdentity) {
      _showError('Nom du club et sport requis.');
      return;
    }
    if (_step == 2 && !draft.canProceedObjectives) {
      _showError('Sélectionnez au moins un objectif.');
      return;
    }
    if (_step == 3 && !draft.canProceedInfo) {
      _showError('Ville et au moins un lieu de pratique requis.');
      return;
    }
    if (_step < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() => _step++);
    }
  }

  void _back() {
    _dismissKeyboard();
    if (_step == 0) {
      context.pop();
      return;
    }
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    setState(() => _step--);
  }

  void _showError(String msg) {
    ViroSnackBar.show(context, msg);
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    ref.read(clubSetupProvider.notifier).updateDraft(
          (d) => d..logoBytes = bytes,
        );
    setState(() {});
  }

  Future<void> _addLocation() async {
    final name = _locationNameController.text.trim();
    if (name.isEmpty) return;
    ref.read(clubSetupProvider.notifier).updateDraft((d) {
      d.practiceLocations = [
        ...d.practiceLocations,
        PracticeLocation(
          name: name,
          address: _locationAddressController.text.trim().isEmpty
              ? null
              : _locationAddressController.text.trim(),
        ),
      ];
      return d;
    });
    _locationNameController.clear();
    _locationAddressController.clear();
    setState(() {});
  }

  Future<void> _submit() async {
    _dismissKeyboard();
    _syncDraftFromControllers();
    final draft = ref.read(clubSetupProvider);

    if (!draft.canProceedIdentity) {
      _showError('Nom du club et sport requis.');
      return;
    }
    if (!draft.canProceedObjectives) {
      _showError('Sélectionnez au moins un objectif.');
      return;
    }
    if (!draft.canProceedInfo) {
      _showError('Ville et au moins un lieu de pratique requis.');
      return;
    }

    final user = await _resolveCurrentUser();
    if (user == null) {
      _showError(
        'Profil introuvable. Reconnectez-vous ou vérifiez votre connexion.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(clubServiceProvider).createClubFromDraft(
            founderUid: user.uid,
            founder: user,
            draft: draft,
          );
      ref.read(clubSetupProvider.notifier).reset();
      ref.invalidate(viroUserProvider);
      ref.invalidate(viroUserFutureProvider);
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      _showError('Erreur lors de la création : $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(clubSetupProvider);
    final theme = Theme.of(context).textTheme;

    return ViroScaffold(
      appBar: ViroAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
        ),
        title: Text('Création du club (${_step + 1}/$_totalSteps)'),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_step + 1) / _totalSteps,
            backgroundColor: ViroColors.primary50,
            color: ViroColors.primary600,
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _WelcomeStep(theme: theme),
                _IdentityStep(
                  draft: draft,
                  nameController: _nameController,
                  descriptionController: _descriptionController,
                  onPickLogo: _pickLogo,
                  onChanged: (name, sport) {
                    ref.read(clubSetupProvider.notifier).updateDraft((d) {
                      d.name = name;
                      d.sport = sport;
                      return d;
                    });
                  },
                ),
                _ObjectivesStep(
                  selected: draft.objectives,
                  onToggle: (key) {
                    ref.read(clubSetupProvider.notifier).toggleObjective(key);
                  },
                ),
                _InfoStep(
                  cityController: _cityController,
                  postalController: _postalController,
                  addressController: _addressController,
                  locationNameController: _locationNameController,
                  locationAddressController: _locationAddressController,
                  locations: draft.practiceLocations,
                  onFieldChanged: () {
                    ref.read(clubSetupProvider.notifier).updateDraft((d) {
                      d.city = _cityController.text;
                      d.postalCode = _postalController.text;
                      d.address = _addressController.text;
                      d.description = _descriptionController.text;
                      return d;
                    });
                  },
                  onAddLocation: _addLocation,
                  onRemoveLocation: (i) {
                    ref.read(clubSetupProvider.notifier).updateDraft((d) {
                      d.practiceLocations = List.of(d.practiceLocations)
                        ..removeAt(i);
                      return d;
                    });
                    setState(() {});
                  },
                ),
                _BrandingStep(
                  colorHex: draft.brandColorHex,
                  onColor: (hex) {
                    ref.read(clubSetupProvider.notifier).updateDraft(
                          (d) => d..brandColorHex = hex,
                        );
                  },
                ),
                _RecapStep(draft: draft),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(ViroSpacing.lg),
            child: _step < _totalSteps - 1
                ? ViroPrimaryButton(label: 'Continuer', onPressed: _next)
                : ViroPrimaryButton(
                    label: 'Créer le club',
                    isLoading: _submitting,
                    onPressed: _submit,
                  ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.theme});

  final TextTheme theme;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(ViroSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Votre club, mieux organisé',
            style: theme.headlineSmall?.copyWith(
              color: ViroColors.primary800,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: ViroSpacing.md),
          const Text(
            'ViroTeam centralise le planning, les présences, les tournois et la vie du club. '
            'En quelques minutes, configurez votre espace et invitez vos membres par code.',
          ),
        ],
      ),
    );
  }
}

class _IdentityStep extends StatelessWidget {
  const _IdentityStep({
    required this.draft,
    required this.nameController,
    required this.descriptionController,
    required this.onPickLogo,
    required this.onChanged,
  });

  final ClubSetupDraft draft;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final VoidCallback onPickLogo;
  final void Function(String name, String sport) onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(ViroSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Nom du club'),
            onChanged: (v) => onChanged(v, draft.sport),
          ),
          const SizedBox(height: ViroSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: draft.sport,
            decoration: const InputDecoration(labelText: 'Sport'),
            items: ClubSports.all
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(draft.name, v);
            },
          ),
          const SizedBox(height: ViroSpacing.md),
          OutlinedButton.icon(
            onPressed: onPickLogo,
            icon: const Icon(Icons.image_outlined),
            label: Text(
              draft.logoBytes != null ? 'Logo sélectionné' : 'Logo (optionnel)',
            ),
          ),
          const SizedBox(height: ViroSpacing.md),
          TextFormField(
            controller: descriptionController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description courte (optionnel)',
            ),
          ),
        ],
      ),
    );
  }
}

class _ObjectivesStep extends StatelessWidget {
  const _ObjectivesStep({
    required this.selected,
    required this.onToggle,
  });

  final Set<String> selected;
  final void Function(String key) onToggle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ViroSpacing.lg),
      children: [
        Text(
          'Quels sont vos objectifs principaux ?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: ViroSpacing.md),
        ...ClubObjectives.all.map(
          (key) => CheckboxListTile(
            value: selected.contains(key),
            onChanged: (_) => onToggle(key),
            title: Text(ClubObjectives.label(key)),
          ),
        ),
      ],
    );
  }
}

class _InfoStep extends StatelessWidget {
  const _InfoStep({
    required this.cityController,
    required this.postalController,
    required this.addressController,
    required this.locationNameController,
    required this.locationAddressController,
    required this.locations,
    required this.onFieldChanged,
    required this.onAddLocation,
    required this.onRemoveLocation,
  });

  final TextEditingController cityController;
  final TextEditingController postalController;
  final TextEditingController addressController;
  final TextEditingController locationNameController;
  final TextEditingController locationAddressController;
  final List<PracticeLocation> locations;
  final VoidCallback onFieldChanged;
  final VoidCallback onAddLocation;
  final void Function(int index) onRemoveLocation;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ViroSpacing.lg),
      children: [
        TextFormField(
          controller: cityController,
          decoration: const InputDecoration(labelText: 'Ville'),
          onChanged: (_) => onFieldChanged(),
        ),
        const SizedBox(height: ViroSpacing.md),
        TextFormField(
          controller: postalController,
          decoration: const InputDecoration(labelText: 'Code postal'),
          onChanged: (_) => onFieldChanged(),
        ),
        const SizedBox(height: ViroSpacing.md),
        TextFormField(
          controller: addressController,
          decoration: const InputDecoration(labelText: 'Adresse du club'),
          onChanged: (_) => onFieldChanged(),
        ),
        const SizedBox(height: ViroSpacing.xl),
        Text(
          'Lieux de pratique',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        TextFormField(
          controller: locationNameController,
          decoration: const InputDecoration(labelText: 'Nom du lieu'),
        ),
        const SizedBox(height: ViroSpacing.sm),
        TextFormField(
          controller: locationAddressController,
          decoration: const InputDecoration(labelText: 'Adresse du lieu'),
        ),
        TextButton(onPressed: onAddLocation, child: const Text('Ajouter ce lieu')),
        ...locations.asMap().entries.map(
              (e) => ListTile(
                title: Text(e.value.name),
                subtitle: e.value.address != null ? Text(e.value.address!) : null,
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => onRemoveLocation(e.key),
                ),
              ),
            ),
      ],
    );
  }
}

class _BrandingStep extends StatelessWidget {
  const _BrandingStep({required this.colorHex, required this.onColor});

  final String? colorHex;
  final void Function(String? hex) onColor;

  static const _presets = [
    '#1E88E5',
    '#43A047',
    '#E53935',
    '#8E24AA',
    '#FB8C00',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ViroSpacing.lg),
      children: [
        Text(
          'Couleur du club (optionnel)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: ViroSpacing.md),
        Wrap(
          spacing: 12,
          children: _presets.map((hex) {
            final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
            final selected = colorHex == hex;
            return GestureDetector(
              onTap: () => onColor(selected ? null : hex),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: selected
                      ? Border.all(color: ViroColors.primary800, width: 3)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: ViroSpacing.md),
        TextButton(
          onPressed: () => onColor(null),
          child: const Text('Pas de couleur personnalisée'),
        ),
      ],
    );
  }
}

class _RecapStep extends StatelessWidget {
  const _RecapStep({required this.draft});

  final ClubSetupDraft draft;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ViroSpacing.lg),
      children: [
        Text(
          'Récapitulatif',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: ViroSpacing.md),
        _Line('Club', draft.name),
        _Line('Sport', draft.sport),
        _Line('Ville', draft.city),
        _Line('Lieux', '${draft.practiceLocations.length}'),
        _Line('Objectifs', '${draft.objectives.length}'),
        if (draft.brandColorHex != null) _Line('Couleur', draft.brandColorHex!),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
