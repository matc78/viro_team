import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:viro_team/constants/firebase_collections.dart';
import 'package:viro_team/theme/viro_theme.dart';

/// Widget récapitulatif en haut de l'onglet Prêt : objets en prêt, prêts en cours, à venir, retards, demandes.
class LoansSummaryCard extends StatelessWidget {
  final String clubId;
  final List<Map<String, dynamic>> allLoans;

  const LoansSummaryCard({
    super.key,
    required this.clubId,
    required this.allLoans,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final activeLoans = allLoans.where((loan) {
      if (loan['status'] != 'active') return false;
      final lentAt = loan['lentAt'] as Timestamp?;
      final dueAt = loan['dueAt'] as Timestamp?;
      if (lentAt == null || dueAt == null) return false;
      final lentDate = lentAt.toDate();
      final dueDate = dueAt.toDate();
      final lentDay = DateTime(lentDate.year, lentDate.month, lentDate.day);
      final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
      return !lentDay.isAfter(today) && !dueDay.isBefore(today);
    }).toList();

    final overdueLoans = allLoans.where((loan) {
      if (loan['status'] != 'active') return false;
      final dueAt = loan['dueAt'] as Timestamp?;
      if (dueAt == null) return false;
      final dueDate = dueAt.toDate();
      final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
      return dueDay.isBefore(today);
    }).toList();

    String objectsInLoanText() {
      if (activeLoans.isEmpty) return 'Aucun prêt en cours';
      final parts = <String>[];
      for (final loan in activeLoans) {
        final name = loan['equipmentName'] as String? ?? 'Équipement';
        final qty = loan['quantity'] as int? ?? 1;
        parts.add('$name (x$qty)');
      }
      return '${activeLoans.length} prêt(s) en cours : ${parts.join(', ')}';
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirebaseCollections.clubs)
          .doc(clubId)
          .collection(FirebaseCollections.equipmentLoanRequests)
          .snapshots(),
      builder: (context, requestsSnap) {
        int pendingCount = 0;
        int upcomingCount = 0;
        if (requestsSnap.hasData) {
          final docs = requestsSnap.data?.docs ?? [];
          for (final doc in docs) {
            final data = doc.data();
            final status = data['status'] as String? ?? '';
            if (status == 'pending') {
              pendingCount++;
            } else if (status == 'accepted') {
              final requestedPickupDate =
                  data['requestedPickupDate'] as Timestamp?;
              if (requestedPickupDate != null) {
                final pickupDate = requestedPickupDate.toDate();
                final pickupDay = DateTime(
                  pickupDate.year,
                  pickupDate.month,
                  pickupDate.day,
                );
                if (pickupDay.isAfter(today)) upcomingCount++;
              }
            }
          }
        }

        return Card(
          color: ViroColors.primary.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.summarize, color: ViroColors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      "Résumé",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _summaryRow("Objets en prêt", objectsInLoanText(), null),
                const SizedBox(height: 6),
                _summaryRow(
                  "Prêts en cours",
                  "${activeLoans.length}",
                  ViroColors.success,
                ),
                const SizedBox(height: 6),
                _summaryRow(
                  "Prêts à venir",
                  "$upcomingCount",
                  ViroColors.primary,
                ),
                const SizedBox(height: 6),
                _summaryRow(
                  "Retard en cours",
                  "${overdueLoans.length}",
                  overdueLoans.isEmpty ? null : ViroColors.error,
                ),
                const SizedBox(height: 6),
                _summaryRow(
                  "Demandes de prêt",
                  "$pendingCount",
                  pendingCount > 0 ? ViroColors.warning : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _summaryRow(String label, String value, Color? valueColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: valueColor ?? Colors.grey[900],
            ),
          ),
        ),
      ],
    );
  }
}
