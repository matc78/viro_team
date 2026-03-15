import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/utils/firestore_instance.dart';
import 'package:viro_team/utils/club_emoji_utils.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import '../theme/viro_theme.dart';
import '../utils/firebase_error_handler.dart';

/// Widget réutilisable pour rechercher et sélectionner un club
class ClubSearchWidget extends StatefulWidget {
  final String? selectedClubId;
  final String? selectedClubName;
  final Function(String clubId, String clubName, String? clubSport) onClubSelected;
  final String? sportFilter;
  final Function(String?)? onSportFilterChanged;
  final List<String>? excludedClubIds; // Clubs à exclure (déjà membres)

  const ClubSearchWidget({
    super.key,
    this.selectedClubId,
    this.selectedClubName,
    required this.onClubSelected,
    this.sportFilter,
    this.onSportFilterChanged,
    this.excludedClubIds,
  });

  @override
  State<ClubSearchWidget> createState() => _ClubSearchWidgetState();
}

class _ClubSearchWidgetState extends State<ClubSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = "";
  String _sportFilter = "Tous";

  // Stream mémorisé : recréé uniquement si le filtre sport change
  Stream<QuerySnapshot>? _cachedStream;
  String _cachedStreamSportFilter = '';

  static const List<String> _sports = [
    "Tous",
    "Football",
    "Basketball",
    "Volleyball",
    "Handball",
    "Rugby",
    "Tennis",
    "Judo",
    "Natation",
    "Autre",
  ];

  @override
  void initState() {
    super.initState();
    _sportFilter = widget.sportFilter ?? "Tous";
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Retourne le stream mémorisé. Le recrée uniquement si le filtre sport a changé.
  Stream<QuerySnapshot> _getClubStream() {
    if (_cachedStream == null || _cachedStreamSportFilter != _sportFilter) {
      _cachedStreamSportFilter = _sportFilter;
      Query query = appFirestore.collection(FirebaseCollections.clubs);
      if (_sportFilter != 'Tous') {
        query = query.where('sport', isEqualTo: _sportFilter);
      }
      _cachedStream = query.snapshots();
    }
    return _cachedStream!;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Filtrer par sport",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _sportFilter,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: _sports
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _sportFilter = val;
              });
              widget.onSportFilterChanged?.call(val);
            }
          },
        ),
        const SizedBox(height: 20),
        const Text(
          "Rechercher votre club",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: "Nom du club ou ville...",
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (val) => setState(() => _searchTerm = val.trim()),
        ),
        const SizedBox(height: 12),
        _buildClubList(),
        if (widget.selectedClubName != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ViroColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: ViroColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Club sélectionné : ${widget.selectedClubName}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ViroColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _clubSubtitle(Map<String, dynamic> club) {
    final pc = club['postalCode']?.toString().trim();
    final hasPostal = pc != null && pc.isNotEmpty;
    final city = club['city'] ?? '';
    final sport = club['sport'] ?? '';
    if (hasPostal) return '$pc $city - $sport';
    return '$city - $sport';
  }

  Widget _buildClubList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getClubStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
                const SizedBox(height: 8),
                Text(
                  FirebaseErrorHandler.getErrorMessage(snapshot.error),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    // Le StreamBuilder se reconnectera automatiquement
                    setState(() {});
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Réessayer'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const SizedBox(
            height: 150,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final city = (data['city'] ?? '').toString().toLowerCase();
          final postalCode = (data['postalCode'] ?? '').toString().toLowerCase();
          final searchLower = _searchTerm.toLowerCase();

          // Filtrer par recherche
          final matchesSearch =
              searchLower.isEmpty ||
              name.contains(searchLower) ||
              city.contains(searchLower) ||
              postalCode.contains(searchLower);

          // Exclure les clubs déjà membres
          final isExcluded = widget.excludedClubIds?.contains(doc.id) ?? false;

          return matchesSearch && !isExcluded;
        }).toList();

        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "Aucun club trouvé.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          );
        }

        return Container(
          height: 150,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final club = docs[index].data() as Map<String, dynamic>;
              final clubId = docs[index].id;
              final isSelected = widget.selectedClubId == clubId;

              return ListTile(
                visualDensity: VisualDensity.compact,
                selected: isSelected,
                title: Text(
                  formatClubNameWithEmoji(club['name'] as String, club['sport'] as String?),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isSelected ? ViroColors.primary : Colors.black,
                  ),
                ),
                subtitle: Text(
                  _clubSubtitle(club),
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: ViroColors.primary)
                    : null,
                onTap: () {
                  widget.onClubSelected(clubId, club['name'], club['sport'] as String?);
                },
              );
            },
          ),
        );
      },
    );
  }
}
