/// Catégories d'équipe suggérées selon le sport du club.
List<String> teamCategoriesForSport(String sportName) {
  final sport = sportName.toLowerCase().trim().replaceAll('-', '');
  switch (sport) {
    case 'football':
      return [
        'U7',
        'U8',
        'U9',
        'U10',
        'U11',
        'U12',
        'U13',
        'U14',
        'U15',
        'U16',
        'U17',
        'U18',
        'U19',
        'Sénior',
        'Vétéran',
        'Féminines',
        'Loisir',
      ];
    case 'basketball':
      return [
        'U7',
        'U9',
        'U11',
        'U13',
        'U15',
        'U17',
        'U18',
        'U20',
        'Sénior',
        'Sénior +',
        'Loisir',
      ];
    case 'volleyball':
      return [
        'M7',
        'M9',
        'M11',
        'M13',
        'M15',
        'M18',
        'M21',
        'Sénior',
        'Loisir',
        'Soft',
      ];
    case 'handball':
      return ['-9', '-11', '-13', '-15', '-18', 'Sénior', 'Féminines', 'Loisir'];
    case 'rugby':
      return [
        'M6',
        'M8',
        'M10',
        'M12',
        'M14',
        'M16',
        'M19',
        'Sénior',
        'Vétéran (+35)',
        'Loisir',
      ];
    case 'tennis':
      return [
        'Galaxie Rouge',
        'Galaxie Orange',
        'Galaxie Vert',
        '11/12 ans',
        '13/14 ans',
        '15/16 ans',
        '17/18 ans',
        'Sénior',
        'Sénior +',
        'Loisir',
      ];
    case 'judo':
      return [
        'Éveil',
        'Mini-poussin',
        'Poussin',
        'Benjamin',
        'Minime',
        'Cadet',
        'Junior',
        'Sénior',
        'Vétéran',
      ];
    case 'natation':
      return [
        'Avenirs',
        'Benjamins',
        'Juniors 1',
        'Juniors 2',
        'Juniors 3',
        'Juniors 4',
        'Séniors',
        'Masters',
      ];
    default:
      return ['U13', 'U15', 'U17', 'Sénior', 'Loisir'];
  }
}
