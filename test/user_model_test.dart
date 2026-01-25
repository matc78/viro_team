import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viro_team/models/user_model.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  Future<DocumentSnapshot<Map<String, dynamic>>> getDoc(String path) async {
    final ref = firestore.doc(path);
    return ref.get();
  }

  group('UserModel.fromFirestore', () {
    test('parse un utilisateur joueur simple', () async {
      await firestore.collection('users').doc('u1').set({
        'email': 'jean@test.fr',
        'firstName': 'Jean',
        'lastName': 'Dupont',
        'activeContext': {'role': 'player', 'clubId': 'c1'},
        'roles': {
          'player': {
            'clubId': 'c1',
            'teamIds': ['u15'],
            'license': '123',
          },
        },
      });

      final snap = await getDoc('users/u1');
      final user = UserModel.fromFirestore(snap);

      expect(user.uid, 'u1');
      expect(user.email, 'jean@test.fr');
      expect(user.firstName, 'Jean');
      expect(user.lastName, 'Dupont');
      expect(user.activeContext?.role, 'player');
      expect(user.activeContext?.clubId, 'c1');
      expect(user.hasPlayerProfile, isTrue);
      expect(user.roles.coach, isEmpty);
      expect(user.roles.admin, isEmpty);
    });

    test('parse un utilisateur coach avec activeContext', () async {
      await firestore.collection('users').doc('u2').set({
        'email': 'marie@test.fr',
        'firstName': 'Marie',
        'lastName': 'Martin',
        'activeContext': {'role': 'coach', 'clubId': 'c2'},
        'roles': {
          'coach': [
            {'clubId': 'c2', 'teams': ['u11', 'u13']},
          ],
        },
      });

      final snap = await getDoc('users/u2');
      final user = UserModel.fromFirestore(snap);

      expect(user.uid, 'u2');
      expect(user.activeContext?.role, 'coach');
      expect(user.activeContext?.clubId, 'c2');
      expect(user.roles.coach.length, 1);
      expect(user.roles.coach.first.clubId, 'c2');
      expect(user.roles.coach.first.teams, ['u11', 'u13']);
      expect(user.coachClubIds, ['c2']);
    });

    test('parse un utilisateur admin', () async {
      await firestore.collection('users').doc('u3').set({
        'email': 'admin@test.fr',
        'activeContext': {'role': 'admin', 'clubId': 'c3'},
        'roles': {
          'admin': ['c3', 'c4'],
        },
      });

      final snap = await getDoc('users/u3');
      final user = UserModel.fromFirestore(snap);

      expect(user.uid, 'u3');
      expect(user.activeContext?.role, 'admin');
      expect(user.roles.admin, ['c3', 'c4']);
      expect(user.hasRoleInClub('admin', 'c3'), isTrue);
      expect(user.hasRoleInClub('admin', 'c4'), isTrue);
    });

    test('allClubIds agrège player, coach et admin', () async {
      await firestore.collection('users').doc('u4').set({
        'activeContext': {'role': 'coach', 'clubId': 'c1'},
        'roles': {
          'player': {'clubId': 'c1', 'teamIds': []},
          'coach': [
            {'clubId': 'c1', 'teams': []},
            {'clubId': 'c2', 'teams': []},
          ],
          'admin': ['c3'],
        },
      });

      final snap = await getDoc('users/u4');
      final user = UserModel.fromFirestore(snap);

      expect(user.allClubIds, containsAll(['c1', 'c2', 'c3']));
      expect(user.isMultiProfile, isTrue);
    });

    test('hasRoleInClub retourne false pour rôle inexistant', () async {
      await firestore.collection('users').doc('u5').set({
        'roles': {'player': {'clubId': 'c1', 'teamIds': []}},
      });

      final snap = await getDoc('users/u5');
      final user = UserModel.fromFirestore(snap);

      expect(user.hasRoleInClub('player', 'c1'), isTrue);
      expect(user.hasRoleInClub('player', 'c2'), isFalse);
      expect(user.hasRoleInClub('coach', 'c1'), isFalse);
    });
  });

  group('ActiveContext', () {
    test('isValid true quand role et clubId non vides', () {
      final ctx = ActiveContext(role: 'player', clubId: 'c1');
      expect(ctx.isValid, isTrue);
    });

    test('isValid false si role ou clubId manquant', () {
      expect(ActiveContext(role: null, clubId: 'c1').isValid, isFalse);
      expect(ActiveContext(role: 'player', clubId: null).isValid, isFalse);
      expect(ActiveContext(role: '', clubId: 'c1').isValid, isFalse);
    });
  });
}
