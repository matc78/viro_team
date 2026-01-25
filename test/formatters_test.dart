import 'package:flutter_test/flutter_test.dart';
import 'package:viro_team/utils/formatters.dart';

void main() {
  group('NameFormatter', () {
    group('formatFirst', () {
      test('retourne une chaîne vide pour null', () {
        expect(NameFormatter.formatFirst(null), '');
      });

      test('retourne une chaîne vide pour chaîne vide', () {
        expect(NameFormatter.formatFirst(''), '');
      });

      test('retourne une chaîne vide pour espaces uniquement', () {
        expect(NameFormatter.formatFirst('   '), '');
      });

      test('met la première lettre en majuscule et le reste en minuscule', () {
        expect(NameFormatter.formatFirst('jean'), 'Jean');
        expect(NameFormatter.formatFirst('MARIE'), 'Marie');
      });

      test('ignore les espaces avant/après', () {
        expect(NameFormatter.formatFirst('  jean  '), 'Jean');
      });
    });

    group('formatLast', () {
      test('retourne une chaîne vide pour null', () {
        expect(NameFormatter.formatLast(null), '');
      });

      test('retourne une chaîne vide pour chaîne vide', () {
        expect(NameFormatter.formatLast(''), '');
      });

      test('met tout en majuscule', () {
        expect(NameFormatter.formatLast('dupont'), 'DUPONT');
        expect(NameFormatter.formatLast('Dupont'), 'DUPONT');
      });

      test('ignore les espaces avant/après', () {
        expect(NameFormatter.formatLast('  dupont  '), 'DUPONT');
      });
    });

    group('format', () {
      test('prénom + nom formatés correctement', () {
        expect(
          NameFormatter.format(firstName: 'jean', lastName: 'DUPONT'),
          'Jean DUPONT',
        );
      });

      test('utilise fallback si prénom et nom vides', () {
        expect(
          NameFormatter.format(firstName: null, lastName: null),
          'Membre',
        );
        expect(
          NameFormatter.format(
            firstName: null,
            lastName: null,
            fallback: 'Invité',
          ),
          'Invité',
        );
      });

      test('nom seul si prénom vide', () {
        expect(
          NameFormatter.format(firstName: null, lastName: 'DUPONT'),
          'DUPONT',
        );
      });

      test('prénom seul si nom vide', () {
        expect(
          NameFormatter.format(firstName: 'Jean', lastName: null),
          'Jean',
        );
      });
    });

    group('formatFromData', () {
      test('parse depuis des données dynamiques', () {
        expect(
          NameFormatter.formatFromData('jean', 'dupont'),
          'Jean DUPONT',
        );
      });

      test('utilise fallback si données vides', () {
        expect(
          NameFormatter.formatFromData(null, null, fallback: 'Membre'),
          'Membre',
        );
      });
    });
  });
}
