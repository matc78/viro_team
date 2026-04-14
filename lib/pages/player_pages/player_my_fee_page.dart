import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/club_fee_settings.dart';
import '../../models/fee_season.dart';
import '../../models/member_fee.dart';
import '../../services/fee_service.dart';
import '../../theme/viro_theme.dart';
import '../../utils/fee_format.dart';
import '../../utils/fee_status_ui.dart';
import '../../widget/viro_loader.dart';

/// Page "Ma cotisation" (lecture seule cote joueur).
/// Affiche automatiquement la saison active du club.
class PlayerMyFeePage extends StatelessWidget {
  final String clubId;

  const PlayerMyFeePage({super.key, required this.clubId});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ma cotisation')),
        body: const Center(child: Text('Non connecte')),
      );
    }

    return Scaffold(
      backgroundColor: ViroColors.background,
      appBar: AppBar(title: const Text('Ma cotisation'), centerTitle: true),
      body: StreamBuilder<({MemberFee? fee, FeeSeason? season})>(
        stream: FeeService.instance.watchActiveMemberFee(clubId, uid),
        builder: (context, snap) {
          if (!snap.hasData &&
              snap.connectionState == ConnectionState.waiting) {
            return const Center(child: ViroLoader(size: 56));
          }

          final season = snap.data?.season;
          final fee = snap.data?.fee;

          if (season == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.euro_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune saison de cotisation active',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Le club te tiendra informe.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final settings = season.toClubFeeSettings();
          final effective =
              fee ??
              MemberFee(userId: uid, status: MemberFeeStatus.nonConfigure);
          final now = DateTime.now();
          final displayStatus = effective.effectiveDisplayStatus(settings, now);

          final due = effective.amountDueCents(settings);
          final paid = effective.amountPaidCents;
          final rest = effective.remainingCents(settings);
          final progress =
              due > 0 ? (paid / due).clamp(0.0, 1.0) : 0.0;

          final tierLabel = _resolveTierLabel(effective, settings);

          // Deadline urgency: within 7 days and not yet passed
          final deadline = settings.paymentDeadlineAt;
          final today = DateTime(now.year, now.month, now.day);
          final deadlinePassed = deadline != null &&
              DateTime(deadline.year, deadline.month, deadline.day)
                  .isBefore(today);
          final deadlineUrgent = deadline != null &&
              !deadlinePassed &&
              deadline.difference(today).inDays <= 7;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (settings.seasonLabel.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    settings.seasonLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),

              // Deadline card — urgent styling within 7 days
              if (deadline != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: deadlineUrgent
                        ? Colors.orange.shade50
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      leading: Icon(
                        deadlineUrgent
                            ? Icons.timer_outlined
                            : Icons.event_outlined,
                        color: deadlineUrgent
                            ? Colors.orange.shade700
                            : ViroColors.primary,
                      ),
                      title: const Text('Date limite de cotisation'),
                      subtitle: Text.rich(
                        TextSpan(
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 14,
                          ),
                          children: [
                            const TextSpan(text: 'Dernier jour inclus : '),
                            TextSpan(
                              text: DateFormat.yMMMMd('fr_FR').format(deadline),
                              style: TextStyle(
                                color: deadlineUrgent
                                    ? Colors.orange.shade800
                                    : ViroColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // Late warning banner
              if (displayStatus == MemberFeeStatus.enRetard && rest > 0) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ViroColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ViroColors.error.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: ViroColors.error,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Cotisation en retard : un solde reste du. '
                            'Merci de regulariser ou de contacter le club.',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.35,
                              color: Colors.grey[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Summary card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Statut',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          FeeStatusChip(status: displayStatus, fontSize: 13),
                        ],
                      ),
                      const Divider(height: 24),
                      _line('Montant du', formatEurosFromCents(due)),
                      _line('Deja paye', formatEurosFromCents(paid)),
                      _line(
                        'Reste a payer',
                        formatEurosFromCents(rest),
                        emphasize: rest > 0,
                      ),
                      if (due > 0) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 7,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress >= 1.0
                                  ? ViroColors.success
                                  : ViroColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${(progress * 100).round()} % regle',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                      if (tierLabel != null) ...[
                        const Divider(height: 24),
                        Text(
                          'Detail du tarif',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tierLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Prochaines actions',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: ViroColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _nextActionsText(
                  displayStatus,
                  effective.status,
                  rest,
                  settings,
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                  height: 1.4,
                ),
              ),

              // Payment instructions with copy button
              if (settings.paymentInstructions.trim().isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Text(
                      'Instructions de paiement',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: ViroColors.primary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      tooltip: 'Copier',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(
                          text: settings.paymentInstructions,
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Instructions copiees'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SelectableText(
                    settings.paymentInstructions,
                    style: const TextStyle(fontSize: 14, height: 1.45),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _line(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: emphasize ? ViroColors.error : Colors.grey[900],
            ),
          ),
        ],
      ),
    );
  }

  String? _resolveTierLabel(MemberFee fee, ClubFeeSettings settings) {
    if (fee.status == MemberFeeStatus.exonere) {
      return 'Exoneration \u2014 aucun montant du.';
    }
    if (fee.customAmountCents != null) {
      return 'Montant personnalise : ${formatEurosFromCents(fee.customAmountCents!)}';
    }
    if (fee.tierId != null) {
      for (final t in settings.tiers) {
        if (t.tierId == fee.tierId) {
          final desc = (t.description != null && t.description!.isNotEmpty)
              ? '\n${t.description}'
              : '';
          return '${t.label} \u2014 ${formatEurosFromCents(t.amountCents)}$desc';
        }
      }
    }
    if (fee.status == MemberFeeStatus.nonConfigure) {
      return 'Ta cotisation n\u2019a pas encore ete parametree par le club.';
    }
    return null;
  }

  String _nextActionsText(
    MemberFeeStatus displayStatus,
    MemberFeeStatus storedStatus,
    int restCents,
    ClubFeeSettings settings,
  ) {
    final deadline = settings.paymentDeadlineAt;
    final overdueByDate =
        settings.isPaymentDeadlineElapsed() == true &&
        restCents > 0 &&
        storedStatus != MemberFeeStatus.nonConfigure &&
        storedStatus != MemberFeeStatus.exonere;

    switch (displayStatus) {
      case MemberFeeStatus.nonConfigure:
        return 'Le club n\u2019a pas encore defini ta cotisation pour cette saison. '
            'Tu recevras une mise a jour lorsque ce sera le cas.';
      case MemberFeeStatus.exonere:
        return 'Aucune action requise : tu es exonere de cotisation.';
      case MemberFeeStatus.paye:
        return 'Ta cotisation est reglee pour la periode affichee. '
            'Conserve une preuve de paiement si besoin.';
      case MemberFeeStatus.aPayer:
        return restCents > 0
            ? 'Merci de regler la cotisation selon les instructions ci-dessous '
                  '${deadline != null ? "avant le ${DateFormat.yMMMMd('fr_FR').format(deadline)} (dernier jour inclus). " : ""}'
                  'Suis les modalites indiquees par le club.'
            : 'Verifie avec le club le montant attendu et les modalites de paiement.';
      case MemberFeeStatus.partiel:
        return restCents > 0
            ? 'Il reste un solde a regler. Utilise les memes modalites de paiement '
                  'que pour le premier versement, sauf consigne contraire du club.'
            : 'Contacte le club pour confirmer le solde restant.';
      case MemberFeeStatus.enRetard:
        if (overdueByDate && storedStatus != MemberFeeStatus.enRetard) {
          return 'La date limite de paiement est depassee et un solde est encore du. '
              'Merci de regulariser rapidement selon les instructions ci-dessous '
              'ou de contacter le club en cas de difficulte.';
        }
        return 'Un retard de paiement a ete signale. Merci de regulariser '
            'des que possible et de prevenir le club si besoin.';
    }
  }
}
