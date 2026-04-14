import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../constants/firebase_collections.dart';
import '../../models/club_fee_settings.dart';
import '../../models/member_fee.dart';
import '../../services/fee_service.dart';
import '../../theme/viro_theme.dart';
import '../../utils/fee_format.dart';
import '../../utils/fee_status_ui.dart';
import '../../utils/firestore_instance.dart';
import '../../widget/viro_loader.dart';
import 'admin_fee_members_page.dart';
import 'admin_fee_settings_page.dart';
import 'widgets/fee_admin_bottom_nav.dart';

/// Tableau de bord des cotisations (compteurs par statut + totaux financiers).
class AdminFeeDashboardPage extends StatelessWidget {
  final String clubId;
  final String seasonId;

  const AdminFeeDashboardPage({
    super.key,
    required this.clubId,
    required this.seasonId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(
        title: const Text('Cotisations'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Paramètres',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      AdminFeeSettingsPage(clubId: clubId, seasonId: seasonId),
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: const FeeAdminBottomNav(currentIndex: 2),
      body: StreamBuilder<ClubFeeSettings?>(
        stream: FeeService.instance.watchFeeSettings(clubId, seasonId),
        builder: (context, settingsSnap) {
          final settings = settingsSnap.data;
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: appFirestore
                .collection(FirebaseCollections.clubs)
                .doc(clubId)
                .collection(FirebaseCollections.members)
                .snapshots(),
            builder: (context, membersSnap) {
              if (!membersSnap.hasData) {
                return const Center(child: ViroLoader(size: 48));
              }
              final playerUids = <String>{};
              for (final doc in membersSnap.data!.docs) {
                final roles =
                    (doc.data()['roles'] as List?)
                        ?.whereType<String>()
                        .toList() ??
                    [];
                if (roles.contains('player')) playerUids.add(doc.id);
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: appFirestore
                    .collection(FirebaseCollections.clubs)
                    .doc(clubId)
                    .collection(FirebaseCollections.pendingMembers)
                    .snapshots(),
                builder: (context, pendingSnap) {
                  if (!pendingSnap.hasData) {
                    return const Center(child: ViroLoader(size: 48));
                  }
                  final pendingIds = <String>{};
                  for (final doc in pendingSnap.data!.docs) {
                    final d = doc.data();
                    final status =
                        (d['invitationStatus'] as String?) ??
                        (d['status'] as String?) ??
                        'pending';
                    if (status != 'declined') {
                      pendingIds.add(doc.id);
                    }
                  }

                  return StreamBuilder<List<MemberFee>>(
                    stream:
                        FeeService.instance.watchAllMemberFees(clubId, seasonId),
                    builder: (context, feeSnap) {
                      if (!feeSnap.hasData) {
                        return const Center(child: ViroLoader(size: 48));
                      }
                      final fees = feeSnap.data!;
                      final feeMap = {for (final f in fees) f.userId: f};
                      final now = DateTime.now();
                      final trackedIds = <String>{...playerUids, ...pendingIds};

                      int countFor(MemberFeeStatus status) {
                        var n = 0;
                        for (final uid in trackedIds) {
                          final mf = feeMap[uid];
                          final fee =
                              mf ??
                              MemberFee(
                                userId: uid,
                                status: MemberFeeStatus.nonConfigure,
                              );
                          if (fee.effectiveDisplayStatus(settings, now) == status) {
                            n++;
                          }
                        }
                        return n;
                      }

                      // Totaux financiers — joueurs + pending_members suivis en cotisation
                      var totalDue = 0;
                      var totalPaid = 0;
                      for (final uid in trackedIds) {
                        final mf = feeMap[uid];
                        if (mf == null) continue;
                        final due = mf.amountDueCents(settings);
                        totalDue += due;
                        totalPaid += mf.amountPaidCents.clamp(0, due);
                      }
                      final totalRemaining = (totalDue - totalPaid).clamp(0, totalDue);

                      final statuses = [
                        MemberFeeStatus.nonConfigure,
                        MemberFeeStatus.aPayer,
                        MemberFeeStatus.partiel,
                        MemberFeeStatus.enRetard,
                        MemberFeeStatus.paye,
                        MemberFeeStatus.exonere,
                      ];

                      return ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                      // En-tête saison
                      if (settings != null && settings.seasonLabel.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            settings.seasonLabel,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: ViroColors.primary,
                            ),
                          ),
                        ),
                      Text(
                        'Suivi des cotisations — ${trackedIds.length} profil${trackedIds.length > 1 ? 's' : ''} (${playerUids.length} joueur${playerUids.length > 1 ? 's' : ''}, ${pendingIds.length} compte${pendingIds.length > 1 ? 's' : ''} non créé${pendingIds.length > 1 ? 's' : ''})',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Chips par statut
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        runAlignment: WrapAlignment.center,
                        children: [
                          for (final s in statuses)
                            _StatChip(
                              status: s,
                              count: countFor(s),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => AdminFeeMembersPage(
                                      clubId: clubId,
                                      seasonId: seasonId,
                                      initialStatusFilter: s,
                                    ),
                                  ),
                                );
                              },
                            ),
                          _PendingAccountChip(
                            count: pendingIds.length,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => AdminFeeMembersPage(
                                    clubId: clubId,
                                    seasonId: seasonId,
                                    initialPendingOnlyFilter: true,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      // Résumé financier
                      if (totalDue > 0) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Résumé financier',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 10),
                        _FinancialSummaryCard(
                          totalDue: totalDue,
                          totalPaid: totalPaid,
                          totalRemaining: totalRemaining,
                        ),
                      ],

                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => AdminFeeMembersPage(
                                  clubId: clubId,
                                  seasonId: seasonId,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.people_outline),
                          label: const Text('Liste des joueurs'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AdminFeeSettingsPage(
                                clubId: clubId,
                                seasonId: seasonId,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_note_outlined),
                        label: const Text('Grille tarifaire et consignes'),
                      ),
                    ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Chip de statut cliquable avec ripple, icône et compteur.
class _StatChip extends StatelessWidget {
  final MemberFeeStatus status;
  final int count;
  final VoidCallback onTap;

  const _StatChip({
    required this.status,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = status == MemberFeeStatus.partiel
        ? Colors.purple.shade800
        : feeStatusTextColor(status);
    final bg = status == MemberFeeStatus.partiel
        ? Colors.purple.shade100
        : feeStatusColor(status);
    final icon = feeStatusIcon(status);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 14, color: color),
                ),
                const SizedBox(width: 8),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  status.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingAccountChip extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _PendingAccountChip({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Colors.indigo.shade800;
    final bg = Colors.indigo.shade100;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.person_off_outlined,
                    size: 14,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Compte non créé',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte résumé des totaux financiers.
class _FinancialSummaryCard extends StatelessWidget {
  final int totalDue;
  final int totalPaid;
  final int totalRemaining;

  const _FinancialSummaryCard({
    required this.totalDue,
    required this.totalPaid,
    required this.totalRemaining,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalDue > 0 ? (totalPaid / totalDue).clamp(0.0, 1.0) : 0.0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _FinRow(
              label: 'Total attendu',
              value: formatEurosFromCents(totalDue),
              valueColor: Colors.grey[800]!,
            ),
            const SizedBox(height: 8),
            _FinRow(
              label: 'Encaissé',
              value: formatEurosFromCents(totalPaid),
              valueColor: ViroColors.primary,
            ),
            const SizedBox(height: 8),
            _FinRow(
              label: 'Reste à collecter',
              value: formatEurosFromCents(totalRemaining),
              valueColor:
                  totalRemaining > 0 ? ViroColors.error : ViroColors.success,
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1.0 ? ViroColors.success : ViroColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${(progress * 100).round()} % encaissé',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _FinRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
