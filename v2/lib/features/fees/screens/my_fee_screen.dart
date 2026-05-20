import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:viro_team_v2/config/project_config.dart';
import 'package:viro_team_v2/config/viro_colors.dart';
import 'package:viro_team_v2/config/viro_icons.dart';
import 'package:viro_team_v2/config/viro_spacing.dart';
import 'package:viro_team_v2/constants/firestore_fields.dart';
import 'package:viro_team_v2/features/auth/providers/auth_providers.dart';
import 'package:viro_team_v2/features/fees/models/fee_season.dart';
import 'package:viro_team_v2/features/fees/models/member_fee.dart';
import 'package:viro_team_v2/features/fees/providers/fee_providers.dart';
import 'package:viro_team_v2/features/fees/utils/fee_format.dart';
import 'package:viro_team_v2/features/fees/widgets/fee_status_chip.dart';
import 'package:viro_team_v2/providers/service_providers.dart';
import 'package:viro_team_v2/utils/viro_snackbar.dart';
import 'package:viro_team_v2/widgets/common/viro_card.dart';
import 'package:viro_team_v2/widgets/common/viro_scaffold.dart';

class MyFeeScreen extends ConsumerStatefulWidget {
  const MyFeeScreen({super.key, required this.clubId});

  final String clubId;

  @override
  ConsumerState<MyFeeScreen> createState() => _MyFeeScreenState();
}

class _MyFeeScreenState extends ConsumerState<MyFeeScreen> {
  String? _audienceId;

  @override
  void initState() {
    super.initState();
    _resolveAudience();
  }

  Future<void> _resolveAudience() async {
    final authUid = ref.read(authStateProvider).value?.uid;
    if (authUid == null) return;
    final id = await ref.read(eventServiceProvider).resolveAudienceId(
          clubId: widget.clubId,
          authUid: authUid,
        );
    if (mounted) setState(() => _audienceId = id);
  }

  @override
  Widget build(BuildContext context) {
    final audienceId = _audienceId;
    if (audienceId == null) {
      return const ViroScaffold(
        appBar: ViroAppBar(title: Text('Ma cotisation')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final feeAsync = ref.watch(
      myFeeProvider((clubId: widget.clubId, memberId: audienceId)),
    );

    return ViroScaffold(
      appBar: const ViroAppBar(
        title: Text('Ma cotisation'),
      ),
      body: feeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (data) {
          final season = data.season;
          if (season == null) {
            return _EmptyState(
              message:
                  'Aucune saison de cotisation active.\nLe club te tiendra informé.',
            );
          }

          final fee = data.fee;
          if (fee == null) {
            return _EmptyState(
              message:
                  'Ta cotisation n\'a pas encore été paramétrée par le club.',
            );
          }

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: ProjectConfig.contentMaxWidth,
              ),
              child: _FeeContent(season: season, fee: fee),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ViroSpacing.xl),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: ViroColors.gray600,
              ),
        ),
      ),
    );
  }
}

class _FeeContent extends StatelessWidget {
  const _FeeContent({
    required this.season,
    required this.fee,
  });

  final FeeSeason season;
  final MemberFee fee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final display = fee.displayStatus(season.paymentDeadlineAt);
    final tier = fee.resolveTier(season);
    final amount = fee.amountDueCents(season);
    final deadline = season.paymentDeadlineAt;

    return ListView(
      padding: const EdgeInsets.all(ViroSpacing.screenHorizontal),
      children: [
        if (season.seasonLabel.isNotEmpty)
          Text(
            season.seasonLabel,
            style: theme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: ViroColors.gray600,
            ),
          ),
        const SizedBox(height: ViroSpacing.md),

        if (display == MemberFeeDisplayStatus.enRetard) ...[
          _WarningCard(
            text:
                'Cotisation en retard. Merci de régulariser selon les consignes ci-dessous.',
          ),
          const SizedBox(height: ViroSpacing.md),
        ],

        if (display == MemberFeeDisplayStatus.paye) ...[
          ViroCard(
            child: Column(
              children: [
                ViroIcon(ViroIcons.check, color: ViroColors.success, size: 40),
                const SizedBox(height: ViroSpacing.sm),
                Text(
                  'Votre cotisation ${season.seasonLabel} est à jour',
                  textAlign: TextAlign.center,
                  style: theme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ViroColors.success,
                  ),
                ),
                if (fee.paidAt != null) ...[
                  const SizedBox(height: ViroSpacing.sm),
                  Text(
                    'Confirmé le ${DateFormat.yMMMMd('fr_FR').format(fee.paidAt!)}',
                    style: theme.bodyMedium?.copyWith(
                      color: ViroColors.gray600,
                    ),
                  ),
                ],
                if (amount > 0) ...[
                  const SizedBox(height: ViroSpacing.xs),
                  Text(
                    formatFeeAmountCents(amount),
                    style: theme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ] else if (display == MemberFeeDisplayStatus.exonere) ...[
          ViroCard(
            child: Text(
              'Vous êtes exonéré(e) de cotisation pour la saison ${season.seasonLabel}.',
              textAlign: TextAlign.center,
              style: theme.bodyLarge,
            ),
          ),
        ] else ...[
          Center(
            child: Text(
              formatFeeAmountCents(amount),
              style: theme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: ViroColors.primary800,
              ),
            ),
          ),
          const SizedBox(height: ViroSpacing.sm),
          Center(
            child: FeeStatusChip(status: display),
          ),
          if (tier != null) ...[
            const SizedBox(height: ViroSpacing.sm),
            Center(
              child: Text(
                'Catégorie : ${tier.label}',
                style: theme.bodyLarge?.copyWith(
                  color: ViroColors.gray600,
                ),
              ),
            ),
          ],
          const SizedBox(height: ViroSpacing.md),
          if (deadline != null)
            ViroCard(
              child: Row(
                children: [
                  ViroIcon(ViroIcons.calendar, color: ViroColors.primary600),
                  const SizedBox(width: ViroSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date limite',
                          style: theme.labelMedium?.copyWith(
                            color: ViroColors.gray600,
                          ),
                        ),
                        Text(
                          DateFormat.yMMMMd('fr_FR').format(deadline),
                          style: theme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'Pas de date limite',
              textAlign: TextAlign.center,
              style: theme.bodyMedium?.copyWith(color: ViroColors.gray600),
            ),
        ],

        const SizedBox(height: ViroSpacing.lg),

        if (display == MemberFeeDisplayStatus.aPayer ||
            display == MemberFeeDisplayStatus.enRetard) ...[
          if (season.paymentInstructions.trim().isNotEmpty) ...[
            Text(
              'Consignes de paiement',
              style: theme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: ViroSpacing.sm),
            ViroCard(
              child: Text(
                season.paymentInstructions,
                style: theme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
            const SizedBox(height: ViroSpacing.md),
          ],

          if (season.iban != null && season.iban!.trim().isNotEmpty) ...[
            ViroCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'IBAN',
                          style: theme.labelMedium?.copyWith(
                            color: ViroColors.gray600,
                          ),
                        ),
                        const SizedBox(height: ViroSpacing.xs),
                        Text(
                          season.iban!,
                          style: theme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: ViroIcon(ViroIcons.copy, color: ViroColors.primary600),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: season.iban!));
                      ViroSnackBar.show(context, 'IBAN copié');
                    },
                    tooltip: 'Copier',
                  ),
                ],
              ),
            ),
            const SizedBox(height: ViroSpacing.md),
          ],

          if (season.paymentMethods.isNotEmpty) ...[
            Text(
              'Moyens de paiement acceptés',
              style: theme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: ViroSpacing.sm),
            Wrap(
              spacing: ViroSpacing.sm,
              children: [
                for (final method in season.paymentMethods)
                  Chip(
                    label: Text(FeePaymentMethods.label(method)),
                    backgroundColor: ViroColors.primary50,
                  ),
              ],
            ),
            const SizedBox(height: ViroSpacing.md),
          ],
        ],

        ViroCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ViroIcon(ViroIcons.bell, color: ViroColors.primary600, size: 20),
              const SizedBox(width: ViroSpacing.sm),
              Expanded(
                child: Text(
                  'Le club vérifie manuellement les paiements. '
                  'Seuls les administrateurs peuvent confirmer qu\'une cotisation est réglée.',
                  style: theme.bodySmall?.copyWith(
                    color: ViroColors.gray600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ViroSpacing.xl),
      ],
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ViroColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(ViroSpacing.cardRadius),
        border: Border.all(color: ViroColors.error.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ViroSpacing.md),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ViroColors.error,
                height: 1.35,
              ),
        ),
      ),
    );
  }
}
