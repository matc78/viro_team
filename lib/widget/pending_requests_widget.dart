import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/viro_theme.dart';

/// Widget pour afficher les demandes en attente et traitées
class PendingRequestsWidget extends StatelessWidget {
  final String userId;

  const PendingRequestsWidget({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('join_requests')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final pendingRequests = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'pending';
        }).toList();

        final processedRequests = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'accepted' || data['status'] == 'refused';
        }).toList();

        if (pendingRequests.isEmpty && processedRequests.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pendingRequests.isNotEmpty) ...[
              const Text(
                "MES DEMANDES EN ATTENTE",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              ...pendingRequests.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _buildRequestCard(
                  data['clubName'] ?? 'Club inconnu',
                  data['roleRequested'] == 'player' ? 'joueur' : 'coach',
                  'pending',
                );
              }),
            ],
            if (processedRequests.isNotEmpty) ...[
              if (pendingRequests.isNotEmpty) const SizedBox(height: 20),
              const Text(
                "DEMANDES TRAITÉES",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              ...processedRequests.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final isAccepted = data['status'] == 'accepted';
                return _buildRequestCard(
                  data['clubName'] ?? 'Club inconnu',
                  data['roleRequested'] == 'player' ? 'joueur' : 'coach',
                  isAccepted ? 'accepted' : 'refused',
                );
              }),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRequestCard(String clubName, String role, String status) {
    final isAccepted = status == 'accepted';
    final isPending = status == 'pending';
    final isRefused = status == 'refused';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAccepted
            ? Colors.green.shade50
            : isRefused
            ? Colors.red.shade50
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAccepted
              ? Colors.green
              : isRefused
              ? Colors.red
              : ViroColors.borderColor,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isAccepted
                ? Icons.check_circle
                : isRefused
                ? Icons.cancel
                : Icons.pending,
            color: isAccepted
                ? Colors.green
                : isRefused
                ? Colors.red
                : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isPending
                  ? "Demande $role chez $clubName"
                  : "${isAccepted ? 'Accepté' : 'Refusé'} : $role chez $clubName",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isAccepted
                    ? Colors.green.shade900
                    : isRefused
                    ? Colors.red.shade900
                    : Colors.black,
              ),
            ),
          ),
          if (isPending)
            const Badge(
              label: Text("En attente"),
              backgroundColor: Colors.orange,
            ),
        ],
      ),
    );
  }
}
