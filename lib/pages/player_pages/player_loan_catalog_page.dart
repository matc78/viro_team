import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../constants/firebase_collections.dart';
import '../../theme/viro_theme.dart';
import '../../utils/firebase_error_handler.dart';
import '../../widget/viro_loader.dart';

class PlayerLoanCatalogPage extends StatefulWidget {
  final String clubId;

  const PlayerLoanCatalogPage({super.key, required this.clubId});

  @override
  State<PlayerLoanCatalogPage> createState() => _PlayerLoanCatalogPageState();
}

class _PlayerLoanCatalogPageState extends State<PlayerLoanCatalogPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String? _selectedClubId;
  bool _initialized = false;
  Map<String, String> _clubNamesCache = {};

  // Extraire tous les clubIds du joueur depuis roles
  List<String> _extractClubIds(Map<String, dynamic>? userData) {
    final Set<String> clubIdsSet = {};
    final roles = userData?['roles'] as Map<String, dynamic>? ?? {};

    // Player
    if (roles['player'] is Map) {
      final playerData = roles['player'] as Map;
      // Nouvelle structure : liste de clubs
      if (playerData['clubs'] is List) {
        final clubs = (playerData['clubs'] as List).whereType<Map>();
        for (var club in clubs) {
          final clubId = club['clubId'] as String?;
          if (clubId != null) clubIdsSet.add(clubId);
        }
      }
      // Ancienne structure : clubId direct (compatibilité)
      else {
        final playerClubId = playerData['clubId'] as String?;
        if (playerClubId != null) clubIdsSet.add(playerClubId);
      }
    }

    // Fallback pour compatibilité
    final legacyClubId = userData?['clubId'] as String?;
    if (legacyClubId != null) clubIdsSet.add(legacyClubId);

    return clubIdsSet.toList();
  }

  Future<void> _loadClubNames(List<String> clubIds) async {
    if (clubIds.isEmpty) return;
    final Map<String, String> names = {};
    for (var i = 0; i < clubIds.length; i += 10) {
      final batch = clubIds.sublist(
        i,
        i + 10 > clubIds.length ? clubIds.length : i + 10,
      );
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('clubs')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        for (var doc in snapshot.docs) {
          names[doc.id] = doc.data()['name'] as String? ?? doc.id;
        }
      } catch (_) {
        for (var id in batch) {
          names[id] = id;
        }
      }
    }
    if (mounted) setState(() => _clubNamesCache = names);
  }

  static const _keyLastClubId = 'player_loan_catalog_last_club_id';

  Future<String> _getCachedClubId(List<String> allClubIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_keyLastClubId);
      if (cached != null && allClubIds.contains(cached)) return cached;
    } catch (_) {}
    return allClubIds.contains(widget.clubId)
        ? widget.clubId
        : allClubIds.first;
  }

  Future<void> _saveClubIdToCache(String clubId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastClubId, clubId);
    } catch (_) {}
  }

  void _ensureInitialized(List<String> allClubIds) {
    if (_initialized || allClubIds.isEmpty) return;
    _initialized = true;
    _getCachedClubId(allClubIds).then((sel) {
      if (mounted) setState(() => _selectedClubId = sel);
    });
    _loadClubNames(allClubIds);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildClubFilter(List<String> allClubIds, String selectedClubId) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: DropdownButtonFormField<String>(
        initialValue: selectedClubId,
        decoration: InputDecoration(
          labelText: "Club",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        items: allClubIds
            .map(
              (id) => DropdownMenuItem(
                value: id,
                child: Text(
                  _clubNamesCache[id] ?? id,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (id) {
          if (id != null) {
            setState(() => _selectedClubId = id);
            _saveClubIdToCache(id);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .snapshots(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: ViroLoader(size: 80));
        }

        final userData = userSnap.data?.data();
        final allClubIds = _extractClubIds(userData);

        if (allClubIds.isEmpty) {
          return const Scaffold(body: Center(child: Text("Aucun club trouvé")));
        }

        if (!_initialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _ensureInitialized(allClubIds);
          });
        }

        final selectedClubId = _selectedClubId ?? widget.clubId;
        final showFilter = allClubIds.length > 1;

        return Scaffold(
          backgroundColor: ViroColors.background,
          appBar: AppBar(
            title: const Text("Catalogue de prêt"),
            centerTitle: true,
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: "Catalogue"),
                Tab(text: "Mes demandes"),
              ],
            ),
          ),
          body: Column(
            children: [
              if (showFilter) _buildClubFilter(allClubIds, selectedClubId),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _CatalogTab(
                      clubId: selectedClubId,
                      currentUserId: _currentUserId,
                    ),
                    _MyRequestsTab(
                      clubId: selectedClubId,
                      currentUserId: _currentUserId,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Onglet Catalogue : affiche les équipements disponibles au prêt
class _CatalogTab extends StatelessWidget {
  final String clubId;
  final String currentUserId;

  const _CatalogTab({required this.clubId, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentCatalog)
          .snapshots(),
      builder: (context, catalogSnap) {
        if (catalogSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: ViroLoader(size: 60));
        }

        if (catalogSnap.hasError) {
          return Center(
            child: FirebaseErrorHandler.buildErrorWidget(
              context,
              catalogSnap.error,
            ),
          );
        }

        final catalogItems = catalogSnap.data?.docs ?? [];

        if (catalogItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  "Aucun équipement disponible au prêt",
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection(FirebaseCollections.clubs)
              .doc(clubId)
              .get(),
          builder: (context, clubSnap) {
            final clubData = clubSnap.data?.data() ?? {};
            final paymentMethods =
                clubData['paymentMethods'] as List<dynamic>? ?? [];
            final loanAllowedWeekdays =
                clubData['loanAllowedWeekdays'] as List<dynamic>? ?? [];
            final loanScheduleRaw =
                clubData['loanSchedule'] as Map<String, dynamic>? ?? {};
            final allowedDaysSet = loanAllowedWeekdays
                .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
                .where((e) => e >= 1 && e <= 7)
                .toSet();
            final effectiveWeekdays = allowedDaysSet.isNotEmpty
                ? allowedDaysSet
                : loanScheduleRaw.keys
                      .map((k) => int.tryParse(k) ?? 0)
                      .where((e) => e >= 1 && e <= 7)
                      .toSet();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _LoanRecapCard(clubData: clubData),
                const SizedBox(height: 16),
                ...List.generate(catalogItems.length, (index) {
                  final catalogData = catalogItems[index].data();
                  final equipmentId = catalogItems[index].id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _EquipmentCard(
                      clubId: clubId,
                      equipmentId: equipmentId,
                      catalogData: catalogData,
                      paymentMethods: paymentMethods,
                      currentUserId: currentUserId,
                      allowedWeekdays: effectiveWeekdays,
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }
}

/// Récap des horaires/jours/lieu et moyens de paiement pour les prêts
class _LoanRecapCard extends StatelessWidget {
  final Map<String, dynamic> clubData;

  const _LoanRecapCard({required this.clubData});

  static const _weekdayLabels = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  String _formatTime(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}h${minute.toString().padLeft(2, '0')}';
  }

  String _getPaymentMethodLabel(String method) {
    final m = method.toString().toLowerCase();
    switch (m) {
      case 'cash':
      case 'especes':
        return 'Espèces';
      case 'card':
      case 'carte':
        return 'Carte bancaire';
      case 'transfer':
      case 'virement':
        return 'Virement';
      case 'check':
      case 'cheque':
        return 'Chèque';
      default:
        return method.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final address = clubData['address'] as String? ?? '';
    final loanScheduleRaw =
        clubData['loanSchedule'] as Map<String, dynamic>? ?? {};
    final loanAllowedWeekdays =
        clubData['loanAllowedWeekdays'] as List<dynamic>? ?? [];
    final paymentMethods = clubData['paymentMethods'] as List<dynamic>? ?? [];

    // Construire la liste des jours avec horaires et lieu (loanSchedule ou défaut 8h-20h + adresse)
    final List<String> dayLines = [];
    final Set<int> allowedDays = loanAllowedWeekdays
        .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
        .where((e) => e >= 1 && e <= 7)
        .toSet();
    if (allowedDays.isEmpty && loanScheduleRaw.isEmpty) {
      // Pas de config : on affiche rien ou "Non renseigné"
      dayLines.add("Jours et horaires non renseignés.");
    } else {
      final effectiveDays = allowedDays.isEmpty
          ? loanScheduleRaw.keys
                .map((k) => int.tryParse(k) ?? 0)
                .where((e) => e >= 1 && e <= 7)
                .toSet()
          : allowedDays;
      if (effectiveDays.isEmpty) {
        dayLines.add("Aucun jour configuré.");
      } else {
        for (int d = 1; d <= 7; d++) {
          if (!effectiveDays.contains(d)) continue;
          final key = d.toString();
          final raw = loanScheduleRaw[key] as Map<String, dynamic>?;
          final startHour = raw?['startHour'] as int? ?? 8;
          final startMinute = raw?['startMinute'] as int? ?? 0;
          final endHour = raw?['endHour'] as int? ?? 20;
          final endMinute = raw?['endMinute'] as int? ?? 0;
          final place = raw?['place'] as String? ?? address;
          final label = _weekdayLabels[d - 1];
          final timeStr =
              '${_formatTime(startHour, startMinute)} - ${_formatTime(endHour, endMinute)}';
          if (place.isNotEmpty) {
            dayLines.add('$label : $timeStr — $place');
          } else {
            dayLines.add('$label : $timeStr');
          }
        }
      }
    }

    return Card(
      margin: EdgeInsets.zero,
      color: ViroColors.primary.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: ViroColors.primary),
                const SizedBox(width: 8),
                const Text(
                  "Récap prêts de la semaine",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "Jours et horaires de récupération / retour",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            ...dayLines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  line,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[800],
                    height: 1.3,
                  ),
                ),
              ),
            ),
            if (address.isNotEmpty &&
                !dayLines.any((l) => l.contains(address))) ...[
              const SizedBox(height: 4),
              Text(
                "Adresse du club : $address",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              "Moyens de paiement acceptés",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            if (paymentMethods.isEmpty)
              Text(
                "Non renseignés.",
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: paymentMethods
                    .map(
                      (method) => Chip(
                        label: Text(
                          _getPaymentMethodLabel(method.toString()),
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor: ViroColors.primary.withOpacity(0.15),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Carte d'un équipement dans le catalogue
class _EquipmentCard extends StatelessWidget {
  final String clubId;
  final String equipmentId;
  final Map<String, dynamic> catalogData;
  final List<dynamic> paymentMethods;
  final String currentUserId;
  final Set<int> allowedWeekdays;

  const _EquipmentCard({
    required this.clubId,
    required this.equipmentId,
    required this.catalogData,
    required this.paymentMethods,
    required this.currentUserId,
    required this.allowedWeekdays,
  });

  String _getPaymentMethodLabel(String method) {
    final m = method.toString().toLowerCase();
    switch (m) {
      case 'cash':
      case 'especes':
        return 'Espèces';
      case 'card':
      case 'carte':
        return 'Carte bancaire';
      case 'transfer':
      case 'virement':
        return 'Virement';
      case 'check':
      case 'cheque':
        return 'Chèque';
      default:
        return method.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipment)
          .doc(equipmentId)
          .snapshots(),
      builder: (context, equipmentSnap) {
        if (!equipmentSnap.hasData) {
          return const SizedBox.shrink();
        }

        final equipmentData = equipmentSnap.data!.data() ?? {};
        final name = equipmentData['name'] as String? ?? 'Équipement inconnu';
        final maxQuantity = catalogData['maxQuantity'] as int? ?? 1;

        final price = catalogData['price'] as num?;
        final priceUnit = catalogData['priceUnit'] as String? ?? 'jour';
        final caution = catalogData['caution'] as num?;
        final maxLoanDurationDays = catalogData['maxLoanDurationDays'] as int?;

        String priceUnitLabel(String unit) {
          switch (unit) {
            case 'jour':
              return 'jour';
            case 'semaine':
              return 'semaine';
            case 'mois':
              return 'mois';
            default:
              return unit;
          }
        }

        String? formatMaxLoanDuration(int? days, String unit) {
          if (days == null) return null;
          switch (unit) {
            case 'jour':
              return '$days jour(s)';
            case 'semaine':
              final weeks = (days / 7).round();
              return '$weeks semaine(s)';
            case 'mois':
              final months = (days / 30).round();
              return '$months mois';
            default:
              return '$days jour(s)';
          }
        }

        final isAvailable = maxQuantity > 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    if (!isAvailable)
                      Chip(
                        label: const Text(
                          "Indisponible",
                          style: TextStyle(fontSize: 12),
                        ),
                        backgroundColor: ViroColors.error.withOpacity(0.15),
                      )
                    else
                      Chip(
                        label: Text(
                          "$maxQuantity disponible(s)",
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: ViroColors.success.withOpacity(0.15),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (price != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.euro, size: 16, color: Colors.grey[700]),
                        const SizedBox(width: 4),
                        Text(
                          '${price.toStringAsFixed(2)} €/${priceUnitLabel(priceUnit)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (maxLoanDurationDays != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Durée max: ${formatMaxLoanDuration(maxLoanDurationDays, priceUnit)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (caution != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.security, size: 16, color: Colors.grey[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Caution: ${caution.toStringAsFixed(2)} € (si perdu ou endommagé)',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (paymentMethods.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Icon(Icons.payment, size: 14, color: Colors.grey[600]),
                      ...paymentMethods.map((method) {
                        return Chip(
                          label: Text(
                            _getPaymentMethodLabel(method.toString()),
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: ViroColors.primary.withOpacity(0.1),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        );
                      }),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isAvailable
                        ? () => _showRequestLoanDialog(
                            context,
                            clubId,
                            equipmentId,
                            name,
                            catalogData,
                            maxQuantity,
                          )
                        : null,
                    child: const Text("Demander"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRequestLoanDialog(
    BuildContext context,
    String clubId,
    String equipmentId,
    String equipmentName,
    Map<String, dynamic> catalogData,
    int maxQuantity,
  ) {
    showDialog(
      context: context,
      builder: (_) => _RequestLoanDialog(
        clubId: clubId,
        equipmentId: equipmentId,
        equipmentName: equipmentName,
        catalogData: catalogData,
        maxQuantity: maxQuantity,
        currentUserId: currentUserId,
        allowedWeekdays: allowedWeekdays,
      ),
    );
  }
}

/// Dialog pour créer une demande de prêt
class _RequestLoanDialog extends StatefulWidget {
  final String clubId;
  final String equipmentId;
  final String equipmentName;
  final Map<String, dynamic> catalogData;
  final int maxQuantity;
  final String currentUserId;
  final Set<int> allowedWeekdays;

  const _RequestLoanDialog({
    required this.clubId,
    required this.equipmentId,
    required this.equipmentName,
    required this.catalogData,
    required this.maxQuantity,
    required this.currentUserId,
    required this.allowedWeekdays,
  });

  @override
  State<_RequestLoanDialog> createState() => _RequestLoanDialogState();
}

class _RequestLoanDialogState extends State<_RequestLoanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  int _selectedQuantity = 1;
  DateTime? _selectedPickupDate;
  DateTime? _selectedReturnDate;
  String _calendarMode = 'pickup'; // 'pickup' ou 'return'
  bool _isSubmitting = false;
  DateTime _focusedDay = DateTime.now();
  final Map<DateTime, int> _availabilityCache =
      {}; // Cache pour les disponibilités
  final Map<DateTime, bool> _pickupDayAvailability =
      {}; // Disponibilité par jour pour la quantité sélectionnée (mode récup.)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPickupMonthAvailability();
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  /// Vérifie si la date tombe sur un jour autorisé pour récupération/retour (config club).
  bool _isAllowedWeekday(DateTime date) {
    final allowed = widget.allowedWeekdays;
    if (allowed.isEmpty) return true;
    return allowed.contains(date.weekday);
  }

  /// Charge la disponibilité des jours du mois focalisé pour la quantité sélectionnée (mode récup.).
  Future<void> _loadPickupMonthAvailability() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final monthEnd = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    final Map<DateTime, bool> result = {};
    for (
      var d = monthStart;
      !d.isAfter(monthEnd);
      d = d.add(const Duration(days: 1))
    ) {
      final normalized = DateTime(d.year, d.month, d.day);
      if (normalized.isBefore(today)) {
        result[normalized] = false;
      } else if (!_isAllowedWeekday(normalized)) {
        result[normalized] = false;
      } else {
        final available = await _checkAvailabilityForDate(
          normalized,
          _selectedQuantity,
        );
        result[normalized] = available >= _selectedQuantity;
      }
    }
    if (mounted) {
      setState(() {
        _pickupDayAvailability.clear();
        _pickupDayAvailability.addAll(result);
      });
    }
  }

  /// Vérifie la disponibilité d'un équipement à une date donnée
  Future<int> _checkAvailabilityForDate(
    DateTime date,
    int requestedQuantity,
  ) async {
    // Normaliser la date (sans heures)
    final normalizedDate = DateTime(date.year, date.month, date.day);

    // Vérifier le cache
    if (_availabilityCache.containsKey(normalizedDate)) {
      return _availabilityCache[normalizedDate]!;
    }

    try {
      final maxQuantity = widget.catalogData['maxQuantity'] as int? ?? 1;

      // 1. Récupérer tous les prêts actifs pour cet équipement
      final activeLoansSnapshot = await FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.equipmentLoans)
          .where('equipmentId', isEqualTo: widget.equipmentId)
          .where('status', isEqualTo: 'active')
          .get();

      int rentedQuantity = 0;

      // Compter les prêts qui chevauchent la date
      for (var loanDoc in activeLoansSnapshot.docs) {
        final loanData = loanDoc.data();
        final lentAt = (loanData['lentAt'] as Timestamp?)?.toDate();
        final dueAt = (loanData['dueAt'] as Timestamp?)?.toDate();
        final quantity = loanData['quantity'] as int? ?? 1;

        if (lentAt != null && dueAt != null) {
          final loanStart = DateTime(lentAt.year, lentAt.month, lentAt.day);
          final loanEnd = DateTime(dueAt.year, dueAt.month, dueAt.day);

          // Vérifier si la date est dans la plage du prêt
          if (normalizedDate.isAfter(
                loanStart.subtract(const Duration(days: 1)),
              ) &&
              normalizedDate.isBefore(loanEnd.add(const Duration(days: 1)))) {
            rentedQuantity += quantity;
          }
        }
      }

      // 2. Récupérer les demandes acceptées en attente de récupération
      final acceptedRequestsSnapshot = await FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.equipmentLoanRequests)
          .where('equipmentId', isEqualTo: widget.equipmentId)
          .where('status', isEqualTo: 'accepted')
          .get();

      for (var requestDoc in acceptedRequestsSnapshot.docs) {
        final requestData = requestDoc.data();
        final requestedPickupDate =
            (requestData['requestedPickupDate'] as Timestamp?)?.toDate();
        final duration = requestData['duration'] as int? ?? 0;
        final durationUnit = requestData['durationUnit'] as String? ?? 'jour';
        final quantity = requestData['quantity'] as int? ?? 1;

        if (requestedPickupDate != null) {
          // Calculer la date de retour estimée
          int durationDays = duration;
          if (durationUnit == 'semaine') {
            durationDays = duration * 7;
          } else if (durationUnit == 'mois') {
            durationDays = duration * 30;
          }

          final estimatedReturnDate = requestedPickupDate.add(
            Duration(days: durationDays),
          );
          final pickupStart = DateTime(
            requestedPickupDate.year,
            requestedPickupDate.month,
            requestedPickupDate.day,
          );
          final returnEnd = DateTime(
            estimatedReturnDate.year,
            estimatedReturnDate.month,
            estimatedReturnDate.day,
          );

          // Vérifier si la date est dans la plage estimée
          if (normalizedDate.isAfter(
                pickupStart.subtract(const Duration(days: 1)),
              ) &&
              normalizedDate.isBefore(returnEnd.add(const Duration(days: 1)))) {
            rentedQuantity += quantity;
          }
        }
      }

      final available = maxQuantity - rentedQuantity;
      _availabilityCache[normalizedDate] = available;
      return available;
    } catch (e) {
      // En cas d'erreur, retourner 0 pour être sûr
      return 0;
    }
  }

  /// Vérifie si une date est disponible pour la récupération
  Future<bool> _isPickupDateAvailable(DateTime date) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final checkDate = DateTime(date.year, date.month, date.day);

    // Les dates passées ne sont pas disponibles
    if (checkDate.isBefore(today)) {
      return false;
    }
    // Seuls les jours autorisés par le club (récup./retour) sont disponibles
    if (!_isAllowedWeekday(checkDate)) {
      return false;
    }

    final available = await _checkAvailabilityForDate(date, _selectedQuantity);
    return available >= _selectedQuantity;
  }

  /// Vérifie si une date est disponible pour le retour
  Future<bool> _isReturnDateAvailable(DateTime date) async {
    if (_selectedPickupDate == null) {
      return false;
    }

    final pickupDate = DateTime(
      _selectedPickupDate!.year,
      _selectedPickupDate!.month,
      _selectedPickupDate!.day,
    );
    final returnDate = DateTime(date.year, date.month, date.day);
    final maxLoanDurationDays =
        widget.catalogData['maxLoanDurationDays'] as int?;

    // Les dates avant la date de récupération ne sont pas disponibles
    if (returnDate.isBefore(pickupDate)) {
      return false;
    }
    // Seuls les jours autorisés par le club (récup./retour) sont disponibles
    if (!_isAllowedWeekday(returnDate)) {
      return false;
    }

    // Vérifier la durée maximale
    if (maxLoanDurationDays != null) {
      final maxReturnDate = pickupDate.add(Duration(days: maxLoanDurationDays));
      if (returnDate.isAfter(maxReturnDate)) {
        return false;
      }
    }

    // Vérifier la disponibilité
    final available = await _checkAvailabilityForDate(date, _selectedQuantity);
    return available >= _selectedQuantity;
  }

  String _getDurationUnitLabel() {
    final priceUnit = widget.catalogData['priceUnit'] as String? ?? 'jour';
    switch (priceUnit) {
      case 'jour':
        return 'jours';
      case 'semaine':
        return 'semaines';
      case 'mois':
        return 'mois';
      default:
        return 'jours';
    }
  }

  /// Calcule la durée en jours entre pickup et return
  int _calculateDurationDays() {
    if (_selectedPickupDate == null || _selectedReturnDate == null) {
      return 0;
    }
    final pickup = DateTime(
      _selectedPickupDate!.year,
      _selectedPickupDate!.month,
      _selectedPickupDate!.day,
    );
    final returnDate = DateTime(
      _selectedReturnDate!.year,
      _selectedReturnDate!.month,
      _selectedReturnDate!.day,
    );
    return returnDate.difference(pickup).inDays;
  }

  /// Convertit les jours en unité appropriée (jour/semaine/mois)
  int _convertDaysToUnit(int days, String unit) {
    switch (unit) {
      case 'jour':
        return days;
      case 'semaine':
        return (days / 7).round();
      case 'mois':
        return (days / 30).round();
      default:
        return days;
    }
  }

  /// Calcule le prix total du prêt
  double? _calculateTotalPrice() {
    final price = widget.catalogData['price'] as num?;
    if (price == null) return null;

    final priceUnit = widget.catalogData['priceUnit'] as String? ?? 'jour';

    if (_selectedPickupDate == null || _selectedReturnDate == null) {
      return null;
    }

    final durationDays = _calculateDurationDays();
    if (durationDays < 1) return null;

    // Calculer le nombre d'unités selon l'unité de prix
    double units;
    switch (priceUnit) {
      case 'jour':
        units = durationDays.toDouble();
        break;
      case 'semaine':
        units = (durationDays / 7);
        break;
      case 'mois':
        units = (durationDays / 30);
        break;
      default:
        units = durationDays.toDouble();
    }

    // Arrondir à l'unité supérieure pour les semaines et mois
    if (priceUnit == 'semaine' || priceUnit == 'mois') {
      units = units.ceilToDouble();
    }

    return (price.toDouble() * units * _selectedQuantity);
  }

  Future<void> _submitRequest() async {
    try {
      // Vérifier que le formulaire est valide
      if (_formKey.currentState == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Erreur: formulaire non initialisé."),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!_formKey.currentState!.validate()) {
        // Afficher un message si la validation échoue
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Veuillez corriger les erreurs dans le formulaire.",
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur de validation: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final quantity = _selectedQuantity;
    final reason = _reasonController.text.trim();
    final priceUnit = widget.catalogData['priceUnit'] as String? ?? 'jour';
    final maxLoanDurationDays =
        widget.catalogData['maxLoanDurationDays'] as int?;

    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez indiquer une raison.")),
      );
      return;
    }

    if (_selectedPickupDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez sélectionner une date de récupération."),
        ),
      );
      return;
    }

    if (_selectedReturnDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez sélectionner une date de retour."),
        ),
      );
      return;
    }

    // Calculer la durée en jours
    final durationDays = _calculateDurationDays();
    if (durationDays < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "La date de retour doit être après la date de récupération.",
          ),
        ),
      );
      return;
    }

    // Vérifier la durée maximale
    if (maxLoanDurationDays != null && durationDays > maxLoanDurationDays) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "La durée maximale est de $maxLoanDurationDays jours (${(maxLoanDurationDays / (priceUnit == 'semaine'
                    ? 7
                    : priceUnit == 'mois'
                    ? 30
                    : 1)).round()} ${_getDurationUnitLabel().replaceAll('s', '')}).",
          ),
        ),
      );
      return;
    }

    // Convertir la durée en unité appropriée
    final duration = _convertDaysToUnit(durationDays, priceUnit);

    setState(() => _isSubmitting = true);

    try {
      // Récupérer les informations du joueur
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .get();
      final userData = userDoc.data() ?? {};
      final firstName = userData['firstName'] as String? ?? '';
      final lastName = userData['lastName'] as String? ?? '';
      var playerName = "$firstName $lastName".trim();
      if (playerName.isEmpty) {
        playerName = userData['email'] as String? ?? 'Joueur';
      }

      await FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(widget.clubId)
          .collection(FirebaseCollections.equipmentLoanRequests)
          .add({
            'equipmentId': widget.equipmentId,
            'equipmentName': widget.equipmentName,
            'playerId': widget.currentUserId,
            'playerName': playerName,
            'quantity': quantity,
            'duration': duration,
            'durationUnit': priceUnit,
            'reason': reason,
            'requestedPickupDate': Timestamp.fromDate(_selectedPickupDate!),
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Demande envoyée. Consultez l'onglet Mes demandes pour suivre votre demande.",
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        FirebaseErrorHandler.showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildCalendar() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(now.year + 1, 12, 31);
    final maxLoanDurationDays =
        widget.catalogData['maxLoanDurationDays'] as int?;
    DateTime? maxReturnDate;

    if (_selectedPickupDate != null && maxLoanDurationDays != null) {
      maxReturnDate = _selectedPickupDate!.add(
        Duration(days: maxLoanDurationDays),
      );
    }

    return TableCalendar(
      firstDay: today,
      lastDay: lastDay,
      focusedDay: _focusedDay,
      locale: 'fr_FR',
      calendarFormat: CalendarFormat.month,
      startingDayOfWeek: StartingDayOfWeek.monday,
      availableGestures: AvailableGestures.all,
      selectedDayPredicate: (day) {
        final normalizedDay = DateTime(day.year, day.month, day.day);
        if (_calendarMode == 'pickup' && _selectedPickupDate != null) {
          final normalizedPickup = DateTime(
            _selectedPickupDate!.year,
            _selectedPickupDate!.month,
            _selectedPickupDate!.day,
          );
          return normalizedDay == normalizedPickup;
        } else if (_calendarMode == 'return') {
          // En mode return, on sélectionne la date de retour pour le style vert
          if (_selectedReturnDate != null) {
            final normalizedReturn = DateTime(
              _selectedReturnDate!.year,
              _selectedReturnDate!.month,
              _selectedReturnDate!.day,
            );
            return normalizedDay == normalizedReturn;
          }
        }
        return false;
      },
      enabledDayPredicate: (day) {
        final normalizedDay = DateTime(day.year, day.month, day.day);

        // Seuls les jours autorisés par le club (récup./retour) sont sélectionnables
        if (!_isAllowedWeekday(normalizedDay)) return false;

        if (_calendarMode == 'pickup') {
          // Pour la récupération : pas de dates passées
          if (normalizedDay.isBefore(today)) return false;
          // Barrer (désactiver) les dates non dispo pour la quantité sélectionnée
          if (_pickupDayAvailability[normalizedDay] == false) return false;
          return true;
        } else {
          // Pour le retour
          if (_selectedPickupDate == null) {
            return false;
          }
          final pickupDate = DateTime(
            _selectedPickupDate!.year,
            _selectedPickupDate!.month,
            _selectedPickupDate!.day,
          );

          // Pas de dates avant la récupération
          if (normalizedDay.isBefore(pickupDate)) {
            return false;
          }

          // Pas de dates après la durée max
          if (maxReturnDate != null) {
            final normalizedMaxReturn = DateTime(
              maxReturnDate.year,
              maxReturnDate.month,
              maxReturnDate.day,
            );
            if (normalizedDay.isAfter(normalizedMaxReturn)) {
              return false;
            }
          }

          return true;
        }
      },
      onDaySelected: (selectedDay, focusedDay) async {
        setState(() {
          _focusedDay = focusedDay;
        });

        if (_calendarMode == 'pickup') {
          final isAvailable = await _isPickupDateAvailable(selectedDay);
          if (isAvailable) {
            setState(() {
              _selectedPickupDate = selectedDay;
              _selectedReturnDate = null; // Réinitialiser le retour
              _calendarMode = 'return';
              _availabilityCache.clear(); // Vider le cache
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Cette date n'est pas disponible pour la récupération.",
                ),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          final isAvailable = await _isReturnDateAvailable(selectedDay);
          if (isAvailable) {
            setState(() {
              _selectedReturnDate = selectedDay;
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Cette date n'est pas disponible pour le retour.",
                ),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      },
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
        });
        _loadPickupMonthAvailability();
      },
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        weekendTextStyle: TextStyle(color: Colors.grey[600]),
        disabledTextStyle: TextStyle(
          color: Colors.grey[300],
          decoration: TextDecoration.lineThrough,
        ),
        selectedDecoration: BoxDecoration(
          color: _calendarMode == 'pickup'
              ? ViroColors.primary
              : ViroColors.success,
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: Colors.grey[300],
          shape: BoxShape.circle,
        ),
        markerDecoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        leftChevronIcon: const Icon(Icons.chevron_left),
        rightChevronIcon: const Icon(Icons.chevron_right),
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, date, _) {
          final normalizedDay = DateTime(date.year, date.month, date.day);
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          // Afficher la date de récupération avec un fond bleu en mode return
          if (_calendarMode == 'return' && _selectedPickupDate != null) {
            final normalizedPickup = DateTime(
              _selectedPickupDate!.year,
              _selectedPickupDate!.month,
              _selectedPickupDate!.day,
            );
            if (normalizedDay == normalizedPickup) {
              return Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: ViroColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${date.day}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            }
          }

          // Dates passées ou non dispo pour la quantité (mode pickup) : barrées + cadenas
          if (_calendarMode == 'pickup') {
            final isPast = normalizedDay.isBefore(today);
            final isUnavailable =
                !isPast && _pickupDayAvailability[normalizedDay] == false;
            if (isPast || isUnavailable) {
              return Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        color: Colors.grey[300],
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Icon(
                        Icons.lock_outline,
                        size: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              );
            }
          }

          // Vérifier si c'est une date après la durée max (pour le mode return)
          if (_calendarMode == 'return' && _selectedPickupDate != null) {
            final maxLoanDurationDays =
                widget.catalogData['maxLoanDurationDays'] as int?;
            if (maxLoanDurationDays != null) {
              final pickupDate = DateTime(
                _selectedPickupDate!.year,
                _selectedPickupDate!.month,
                _selectedPickupDate!.day,
              );
              final maxReturnDate = pickupDate.add(
                Duration(days: maxLoanDurationDays),
              );
              final normalizedMaxReturn = DateTime(
                maxReturnDate.year,
                maxReturnDate.month,
                maxReturnDate.day,
              );

              if (normalizedDay.isAfter(normalizedMaxReturn)) {
                return Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          color: Colors.grey[300],
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Icon(
                          Icons.lock_outline,
                          size: 12,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                );
              }
            }
          }

          // Jours possibles (aujourd'hui à lastDay) : texte en bleu pour bien les différencier
          if (!normalizedDay.isBefore(today) &&
              !normalizedDay.isAfter(lastDay)) {
            return Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  color: ViroColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }

          return null;
        },
        disabledBuilder: (context, date, _) {
          return Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: TextStyle(
                    color: Colors.grey[300],
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(
                    Icons.lock_outline,
                    size: 12,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxQuantity = widget.catalogData['maxQuantity'] as int? ?? 1;
    final maxLoanDurationDays =
        widget.catalogData['maxLoanDurationDays'] as int?;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.95,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Header avec titre et bouton fermer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Demande de prêt",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Contenu scrollable
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.equipmentName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedQuantity,
                        decoration: InputDecoration(
                          labelText: "Quantité",
                          helperText: "Maximum: $maxQuantity",
                        ),
                        items: List.generate(
                          maxQuantity,
                          (i) => DropdownMenuItem<int>(
                            value: i + 1,
                            child: Text('${i + 1}'),
                          ),
                        ),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedQuantity = value;
                            _pickupDayAvailability.clear();
                            _selectedPickupDate = null;
                            _selectedReturnDate = null;
                            _calendarMode = 'pickup';
                          });
                          _loadPickupMonthAvailability();
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _reasonController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: "Raison de la demande",
                          hintText:
                              "Expliquez pourquoi vous avez besoin de cet équipement",
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Veuillez indiquer une raison";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Affichage des dates sélectionnées
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Date aller
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _selectedPickupDate != null
                                            ? ViroColors.primary
                                            : Colors.grey[300],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Center(
                                        child: Text(
                                          _selectedPickupDate != null
                                              ? DateFormat(
                                                  'dd/MM/yyyy',
                                                  'fr_FR',
                                                ).format(_selectedPickupDate!)
                                              : 'Date aller',
                                          style: TextStyle(
                                            color: _selectedPickupDate != null
                                                ? Colors.white
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.arrow_forward,
                                    color: Colors.grey[600],
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  // Date retour
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _selectedReturnDate != null
                                            ? ViroColors.success
                                            : Colors.grey[300],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Center(
                                        child: Text(
                                          _selectedReturnDate != null
                                              ? DateFormat(
                                                  'dd/MM/yyyy',
                                                  'fr_FR',
                                                ).format(_selectedReturnDate!)
                                              : 'Date retour',
                                          style: TextStyle(
                                            color: _selectedReturnDate != null
                                                ? Colors.white
                                                : Colors.grey[600],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Bouton retour en arrière
                            if (_selectedPickupDate != null ||
                                _selectedReturnDate != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: IconButton(
                                  icon: const Icon(Icons.undo, size: 20),
                                  color: Colors.grey[700],
                                  onPressed: () {
                                    setState(() {
                                      if (_selectedReturnDate != null) {
                                        // Désélectionner la date de retour
                                        _selectedReturnDate = null;
                                        _calendarMode = 'return';
                                      } else if (_selectedPickupDate != null) {
                                        // Désélectionner la date de récupération
                                        _selectedPickupDate = null;
                                        _selectedReturnDate = null;
                                        _calendarMode = 'pickup';
                                      }
                                      _availabilityCache.clear();
                                    });
                                  },
                                  tooltip: 'Annuler la dernière sélection',
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_selectedPickupDate != null &&
                          _selectedReturnDate != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.grey[600],
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Durée : ${_calculateDurationDays()} jour(s)",
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Calendrier
                      SizedBox(height: 350, child: _buildCalendar()),
                      if (maxLoanDurationDays != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          "Durée maximale : $maxLoanDurationDays jour(s)",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Footer avec boutons
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[300] ?? Colors.grey),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Prix total
                  Expanded(
                    child: _calculateTotalPrice() != null
                        ? Row(
                            children: [
                              const SizedBox(width: 4),
                              Text(
                                '${_calculateTotalPrice()!.toStringAsFixed(2)} €',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                  // Boutons
                  Row(
                    children: [
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text("Annuler"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () {
                                // Wrapper pour s'assurer que la méthode est bien appelée
                                _submitRequest();
                              },
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text("Envoyer"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Onglet Mes demandes : affiche l'historique des demandes
class _MyRequestsTab extends StatelessWidget {
  final String clubId;
  final String currentUserId;

  const _MyRequestsTab({required this.clubId, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoanRequests)
          .where('playerId', isEqualTo: currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: ViroLoader(size: 60));
        }

        if (snapshot.hasError) {
          final error = snapshot.error.toString();
          // Vérifier si c'est une erreur d'index manquant
          if (error.contains('index') ||
              error.contains('requires an index') ||
              error.contains('Condition requise non remplie')) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Index Firestore requis",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Un index composite est nécessaire pour afficher vos demandes.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Créez un index sur: playerId (Ascending), createdAt (Descending)",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(
            child: FirebaseErrorHandler.buildErrorWidget(
              context,
              snapshot.error,
            ),
          );
        }

        final requests = snapshot.data?.docs ?? [];

        // Trier côté client par createdAt (descendant)
        final sortedRequests = requests.toList()
          ..sort((a, b) {
            final aCreated = a.data()['createdAt'] as Timestamp?;
            final bCreated = b.data()['createdAt'] as Timestamp?;
            if (aCreated == null && bCreated == null) return 0;
            if (aCreated == null) return 1;
            if (bCreated == null) return -1;
            return bCreated.compareTo(aCreated); // Descendant
          });

        if (sortedRequests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  "Aucune demande de prêt",
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedRequests.length,
          itemBuilder: (context, index) {
            final requestData = sortedRequests[index].data();
            return _RequestHistoryCard(
              requestId: sortedRequests[index].id,
              requestData: requestData,
            );
          },
        );
      },
    );
  }
}

/// Carte pour une demande dans l'historique
class _RequestHistoryCard extends StatelessWidget {
  final String requestId;
  final Map<String, dynamic> requestData;

  const _RequestHistoryCard({
    required this.requestId,
    required this.requestData,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return ViroColors.warning;
      case 'accepted':
        return ViroColors.success;
      case 'refused':
        return ViroColors.error;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'accepted':
        return 'Acceptée';
      case 'refused':
        return 'Refusée';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = requestData['status'] as String? ?? 'pending';
    final equipmentName =
        requestData['equipmentName'] as String? ?? 'Équipement';
    final quantity = requestData['quantity'] as int? ?? 1;
    final duration = requestData['duration'] as int? ?? 0;
    final durationUnit = requestData['durationUnit'] as String? ?? 'jour';
    final reason = requestData['reason'] as String? ?? '';
    final requestedPickupDate =
        requestData['requestedPickupDate'] as Timestamp?;
    final adminResponse = requestData['adminResponse'] as String?;
    final createdAt = requestData['createdAt'] as Timestamp?;
    final respondedAt = requestData['respondedAt'] as Timestamp?;

    String durationUnitLabel(String unit) {
      switch (unit) {
        case 'jour':
          return 'jour(s)';
        case 'semaine':
          return 'semaine(s)';
        case 'mois':
          return 'mois';
        default:
          return unit;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    equipmentName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    _getStatusLabel(status),
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  backgroundColor: _getStatusColor(status),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Quantité: $quantity • Durée: $duration ${durationUnitLabel(durationUnit)}",
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            if (requestedPickupDate != null) ...[
              const SizedBox(height: 4),
              Text(
                "Récupération souhaitée: ${DateFormat('dd/MM/yyyy', 'fr_FR').format(requestedPickupDate.toDate())}",
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ],
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Raison:",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reason,
                      style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                    ),
                  ],
                ),
              ),
            ],
            if (adminResponse != null && adminResponse.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: status == 'accepted'
                      ? ViroColors.success.withOpacity(0.1)
                      : ViroColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status == 'accepted'
                          ? "Réponse de l'admin:"
                          : "Raison du refus:",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: status == 'accepted'
                            ? ViroColors.success
                            : ViroColors.error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      adminResponse,
                      style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                    ),
                  ],
                ),
              ),
            ],
            if (createdAt != null) ...[
              const SizedBox(height: 8),
              Text(
                "Demandé le: ${DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(createdAt.toDate())}",
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
            if (respondedAt != null) ...[
              Text(
                "Répondu le: ${DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(respondedAt.toDate())}",
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
