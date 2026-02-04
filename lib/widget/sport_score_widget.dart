import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/viro_theme.dart';

/// Widget de scoreur adaptatif selon le sport du club
class SportScoreWidget extends StatefulWidget {
  final String? sport;
  final String clubId;

  const SportScoreWidget({
    super.key,
    required this.sport,
    required this.clubId,
  });

  @override
  State<SportScoreWidget> createState() => _SportScoreWidgetState();
}

class _SportScoreWidgetState extends State<SportScoreWidget> {
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  // États pour chaque type de scoreur
  int _team1Score = 0;
  int _team2Score = 0;
  int _team1Sets = 0;
  int _team2Sets = 0;
  int _team1Games = 0;
  int _team2Games = 0;
  String _team1TennisScore = '0';
  String _team2TennisScore = '0';
  int _team1JudoScore = 0;
  int _team2JudoScore = 0;
  final List<String> _actionHistory = [];

  // Noms des équipes
  String _team1Name = 'Équipe 1';
  String _team2Name = 'Équipe 2';

  // État de visibilité
  bool _isHidden = false;

  @override
  void initState() {
    super.initState();
    _loadScore();
  }

  Future<void> _loadScore() async {
    _prefs = await SharedPreferences.getInstance();
    final key = 'score_${widget.clubId}_${widget.sport ?? 'default'}';

    setState(() {
      _team1Score = _prefs.getInt('${key}_t1_score') ?? 0;
      _team2Score = _prefs.getInt('${key}_t2_score') ?? 0;
      _team1Sets = _prefs.getInt('${key}_t1_sets') ?? 0;
      _team2Sets = _prefs.getInt('${key}_t2_sets') ?? 0;
      _team1Games = _prefs.getInt('${key}_t1_games') ?? 0;
      _team2Games = _prefs.getInt('${key}_t2_games') ?? 0;
      _team1TennisScore = _prefs.getString('${key}_t1_tennis') ?? '0';
      _team2TennisScore = _prefs.getString('${key}_t2_tennis') ?? '0';
      _team1JudoScore = _prefs.getInt('${key}_t1_judo') ?? 0;
      _team2JudoScore = _prefs.getInt('${key}_t2_judo') ?? 0;
      _team1Name = _prefs.getString('${key}_t1_name') ?? 'Équipe 1';
      _team2Name = _prefs.getString('${key}_t2_name') ?? 'Équipe 2';
      _isHidden = _prefs.getBool('${key}_hidden') ?? false;
      _isInitialized = true;
    });
  }

  Future<void> _saveScore() async {
    final key = 'score_${widget.clubId}_${widget.sport ?? 'default'}';
    await _prefs.setInt('${key}_t1_score', _team1Score);
    await _prefs.setInt('${key}_t2_score', _team2Score);
    await _prefs.setInt('${key}_t1_sets', _team1Sets);
    await _prefs.setInt('${key}_t2_sets', _team2Sets);
    await _prefs.setInt('${key}_t1_games', _team1Games);
    await _prefs.setInt('${key}_t2_games', _team2Games);
    await _prefs.setString('${key}_t1_tennis', _team1TennisScore);
    await _prefs.setString('${key}_t2_tennis', _team2TennisScore);
    await _prefs.setInt('${key}_t1_judo', _team1JudoScore);
    await _prefs.setInt('${key}_t2_judo', _team2JudoScore);
    await _prefs.setString('${key}_t1_name', _team1Name);
    await _prefs.setString('${key}_t2_name', _team2Name);
    await _prefs.setBool('${key}_hidden', _isHidden);
  }

  void _toggleVisibility() {
    setState(() {
      _isHidden = !_isHidden;
      _saveScore();
    });
  }

  Future<void> _editTeamName(int teamNumber) async {
    final storedName = teamNumber == 1 ? _team1Name : _team2Name;
    // Déterminer le nom par défaut selon le sport
    final isJudo = widget.sport?.toLowerCase() == 'judo';
    final defaultName = isJudo
        ? (teamNumber == 1 ? 'Joueur/Équipe 1' : 'Joueur/Équipe 2')
        : (teamNumber == 1 ? 'Équipe 1' : 'Équipe 2');

    // Si le nom stocké est un nom par défaut, utiliser le nom par défaut du sport actuel
    final isDefaultName =
        storedName == 'Équipe 1' ||
        storedName == 'Équipe 2' ||
        storedName == 'Joueur/Équipe 1' ||
        storedName == 'Joueur/Équipe 2';
    final displayName = isDefaultName ? defaultName : storedName;

    final controller = TextEditingController(text: displayName);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Modifier le nom ${teamNumber == 1 ? "de l'équipe 1" : "de l'équipe 2"}',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nom de l\'équipe',
            border: OutlineInputBorder(),
          ),
          maxLength: 30,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        if (teamNumber == 1) {
          _team1Name = result;
        } else {
          _team2Name = result;
        }
        _saveScore();
      });
    }
  }

  Widget _buildEditableTeamName(
    String name,
    int teamNumber, {
    bool isJudo = false,
  }) {
    // Déterminer le nom par défaut selon le sport
    final defaultName = isJudo
        ? (teamNumber == 1 ? 'Joueur/Équipe 1' : 'Joueur/Équipe 2')
        : (teamNumber == 1 ? 'Équipe 1' : 'Équipe 2');

    // Si le nom stocké est un nom par défaut (Équipe X ou Joueur/Équipe X), utiliser le nom par défaut du sport actuel
    final isDefaultName =
        name == 'Équipe 1' ||
        name == 'Équipe 2' ||
        name == 'Joueur/Équipe 1' ||
        name == 'Joueur/Équipe 2';
    final displayName = isDefaultName ? defaultName : name;

    return GestureDetector(
      onTap: () => _editTeamName(teamNumber),
      child: Text(
        displayName,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _addToHistory(String action) {
    _actionHistory.add(action);
    if (_actionHistory.length > 50) {
      _actionHistory.removeAt(0);
    }
  }

  void _undoLastAction() {
    if (_actionHistory.isEmpty) return;

    final lastAction = _actionHistory.removeLast();
    final parts = lastAction.split('_');
    if (parts.length < 2) return;

    final type = parts[0];
    final team = parts[1];
    final value = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;

    setState(() {
      if (type == 'score') {
        if (team == '1') {
          _team1Score = (_team1Score - value).clamp(0, 999);
        } else {
          _team2Score = (_team2Score - value).clamp(0, 999);
        }
      } else if (type == 'set') {
        if (team == '1') {
          _team1Sets = (_team1Sets - 1).clamp(0, 99);
        } else {
          _team2Sets = (_team2Sets - 1).clamp(0, 99);
        }
      } else if (type == 'game') {
        if (team == '1') {
          _team1Games = (_team1Games - 1).clamp(0, 99);
        } else {
          _team2Games = (_team2Games - 1).clamp(0, 99);
        }
      } else if (type == 'tennis') {
        if (team == '1') {
          _team1TennisScore = '0';
        } else {
          _team2TennisScore = '0';
        }
      } else if (type == 'judo') {
        if (team == '1') {
          _team1JudoScore = (_team1JudoScore - value).clamp(0, 999);
        } else {
          _team2JudoScore = (_team2JudoScore - value).clamp(0, 999);
        }
      }
      _saveScore();
    });
  }

  void _resetScore() {
    setState(() {
      _team1Score = 0;
      _team2Score = 0;
      _team1Sets = 0;
      _team2Sets = 0;
      _team1Games = 0;
      _team2Games = 0;
      _team1TennisScore = '0';
      _team2TennisScore = '0';
      _team1JudoScore = 0;
      _team2JudoScore = 0;
      _actionHistory.clear();
      _saveScore();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const SizedBox.shrink();
    }

    final sport = widget.sport?.toLowerCase() ?? '';

    // Ne pas afficher pour Natation et Autre
    if (sport == 'natation' || sport == 'autre') {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Contenu principal
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(color: Colors.white),
              child: Column(
                children: [
                  // En-tête avec boutons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Scoreur',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              _isHidden
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              size: 16,
                            ),
                            onPressed: _toggleVisibility,
                            tooltip: _isHidden
                                ? 'Afficher le scoreur'
                                : 'Cacher le scoreur',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: Colors.grey,
                          ),
                          if (_actionHistory.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.undo, size: 16),
                              onPressed: _undoLastAction,
                              tooltip: 'Annuler dernière action',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              color: ViroColors.primary,
                            ),
                          ],
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 16),
                            onPressed: _resetScore,
                            tooltip: 'Réinitialiser',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (!_isHidden) ...[
                    const SizedBox(height: 8),
                    // Scoreur selon le sport
                    _buildScoreurForSport(sport),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreurForSport(String sport) {
    switch (sport) {
      case 'volleyball':
        return _buildVolleyballScoreur();
      case 'football':
        return _buildFootballScoreur();
      case 'tennis':
        return _buildTennisScoreur();
      case 'basketball':
        return _buildBasketballScoreur();
      case 'handball':
        return _buildHandballScoreur();
      case 'rugby':
        return _buildRugbyScoreur();
      case 'judo':
        return _buildJudoScoreur();
      default:
        return const SizedBox.shrink();
    }
  }

  // Scoreur Volley : Points et Sets
  Widget _buildVolleyballScoreur() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Column(
                children: [
                  _buildEditableTeamName(_team1Name, 1),
                  const SizedBox(height: 8),
                  Text(
                    '$_team1Score',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: ViroColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sets: $_team1Sets',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildScoreButton('+1', () {
                        setState(() {
                          _team1Score++;
                          _addToHistory('score_1_1');
                          _saveScore();
                        });
                      }),
                      const SizedBox(width: 8),
                      _buildScoreButton('Set', () {
                        setState(() {
                          _team1Sets++;
                          _addToHistory('set_1');
                          _saveScore();
                        });
                      }),
                    ],
                  ),
                ],
              ),
            ),
            const Text(
              'VS',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  _buildEditableTeamName(_team2Name, 2),
                  const SizedBox(height: 8),
                  Text(
                    '$_team2Score',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: ViroColors.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sets: $_team2Sets',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildScoreButton('+1', () {
                        setState(() {
                          _team2Score++;
                          _addToHistory('score_2_1');
                          _saveScore();
                        });
                      }, color: ViroColors.accent),
                      const SizedBox(width: 8),
                      _buildScoreButton('Set', () {
                        setState(() {
                          _team2Sets++;
                          _addToHistory('set_2');
                          _saveScore();
                        });
                      }, color: ViroColors.accent),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Scoreur Foot : Buts simples
  Widget _buildFootballScoreur() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: Column(
            children: [
              _buildEditableTeamName(_team1Name, 1),
              const SizedBox(height: 8),
              Text(
                '$_team1Score',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: ViroColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              _buildScoreButton('+1', () {
                setState(() {
                  _team1Score++;
                  _addToHistory('score_1_1');
                  _saveScore();
                });
              }),
            ],
          ),
        ),
        const Text(
          'VS',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        Expanded(
          child: Column(
            children: [
              _buildEditableTeamName(_team2Name, 2),
              const SizedBox(height: 8),
              Text(
                '$_team2Score',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: ViroColors.accent,
                ),
              ),
              const SizedBox(height: 12),
              _buildScoreButton('+1', () {
                setState(() {
                  _team2Score++;
                  _addToHistory('score_2_1');
                  _saveScore();
                });
              }, color: ViroColors.accent),
            ],
          ),
        ),
      ],
    );
  }

  // Scoreur Tennis : 15, 30, 40, Game, Sets
  Widget _buildTennisScoreur() {
    final nextScore1 = _getNextTennisScore(_team1TennisScore);
    final nextScore2 = _getNextTennisScore(_team2TennisScore);

    // Déterminer le texte du bouton en fonction de l'état des deux équipes
    final buttonText1 = _getTennisButtonText(
      _team1TennisScore,
      _team2TennisScore,
    );
    final buttonText2 = _getTennisButtonText(
      _team2TennisScore,
      _team1TennisScore,
    );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Column(
                children: [
                  _buildEditableTeamName(_team1Name, 1, isJudo: true),
                  const SizedBox(height: 8),
                  Text(
                    _team1TennisScore,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: ViroColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Games: $_team1Games | Sets: $_team1Sets',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      _buildScoreButton(buttonText1, () {
                        setState(() {
                          if (_team1TennisScore == '40' &&
                              _team2TennisScore == '40') {
                            _team1TennisScore = 'Av';
                            _addToHistory('tennis_1');
                          } else if (_team1TennisScore == 'Av') {
                            _team1TennisScore = '0';
                            _team2TennisScore = '0';
                            _team1Games++;
                            _addToHistory('game_1');
                          } else if (_team2TennisScore == 'Av') {
                            _team2TennisScore = '40';
                            _team1TennisScore = '40';
                            _addToHistory('tennis_1');
                          } else if (_team1TennisScore == '40' &&
                              _team2TennisScore != '40') {
                            _team1TennisScore = '0';
                            _team2TennisScore = '0';
                            _team1Games++;
                            _addToHistory('game_1');
                          } else {
                            _team1TennisScore = nextScore1;
                            _addToHistory('tennis_1');
                          }
                          _saveScore();
                        });
                      }),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildScoreButton('Game', () {
                            setState(() {
                              _team1Games++;
                              _team1TennisScore = '0';
                              _team2TennisScore = '0';
                              _addToHistory('game_1');
                              _saveScore();
                            });
                          }, isSmall: true),
                          const SizedBox(width: 8),
                          _buildScoreButton('Set', () {
                            setState(() {
                              _team1Sets++;
                              _team1Games = 0;
                              _team2Games = 0;
                              _addToHistory('set_1');
                              _saveScore();
                            });
                          }, isSmall: true),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Text(
              'VS',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  _buildEditableTeamName(_team2Name, 2, isJudo: true),
                  const SizedBox(height: 8),
                  Text(
                    _team2TennisScore,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: ViroColors.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Games: $_team2Games | Sets: $_team2Sets',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      _buildScoreButton(buttonText2, () {
                        setState(() {
                          if (_team2TennisScore == '40' &&
                              _team1TennisScore == '40') {
                            _team2TennisScore = 'Av';
                            _addToHistory('tennis_2');
                          } else if (_team2TennisScore == 'Av') {
                            _team2TennisScore = '0';
                            _team1TennisScore = '0';
                            _team2Games++;
                            _addToHistory('game_2');
                          } else if (_team1TennisScore == 'Av') {
                            _team1TennisScore = '40';
                            _team2TennisScore = '40';
                            _addToHistory('tennis_2');
                          } else if (_team2TennisScore == '40' &&
                              _team1TennisScore != '40') {
                            _team1TennisScore = '0';
                            _team2TennisScore = '0';
                            _team2Games++;
                            _addToHistory('game_2');
                          } else {
                            _team2TennisScore = nextScore2;
                            _addToHistory('tennis_2');
                          }
                          _saveScore();
                        });
                      }, color: ViroColors.accent),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildScoreButton(
                            'Game',
                            () {
                              setState(() {
                                _team2Games++;
                                _team1TennisScore = '0';
                                _team2TennisScore = '0';
                                _addToHistory('game_2');
                                _saveScore();
                              });
                            },
                            isSmall: true,
                            color: ViroColors.accent,
                          ),
                          const SizedBox(width: 8),
                          _buildScoreButton(
                            'Set',
                            () {
                              setState(() {
                                _team2Sets++;
                                _team1Games = 0;
                                _team2Games = 0;
                                _addToHistory('set_2');
                                _saveScore();
                              });
                            },
                            isSmall: true,
                            color: ViroColors.accent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getNextTennisScore(String current) {
    switch (current) {
      case '0':
        return '15';
      case '15':
        return '30';
      case '30':
        return '40';
      case '40':
        return 'Game';
      case 'Av':
        return 'Game';
      default:
        return '15';
    }
  }

  /// Détermine le texte du bouton pour le tennis en fonction de l'état des deux équipes
  String _getTennisButtonText(String currentScore, String opponentScore) {
    // Si l'équipe a l'avantage, le bouton doit afficher "Game"
    if (currentScore == 'Av') {
      return 'Game';
    }

    // Si l'équipe est à 40
    if (currentScore == '40') {
      // Si l'adversaire a aussi 40, on peut prendre l'avantage
      if (opponentScore == '40') {
        return 'Av';
      }
      // Si l'adversaire a l'avantage, on peut revenir à 40-40
      if (opponentScore == 'Av') {
        return '40-40';
      }
      // Sinon, on peut gagner le jeu directement
      return 'Game';
    }

    // Pour les autres scores (0, 15, 30), on utilise la progression normale
    return _getNextTennisScore(currentScore);
  }

  // Scoreur Basket : +2 ou +3
  Widget _buildBasketballScoreur() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: Column(
            children: [
              _buildEditableTeamName(_team1Name, 1),
              const SizedBox(height: 8),
              Text(
                '$_team1Score',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: ViroColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildScoreButton('+1', () {
                    setState(() {
                      _team1Score += 1;
                      _addToHistory('score_1_1');
                      _saveScore();
                    });
                  }, isSmall: true),
                  const SizedBox(width: 6),
                  _buildScoreButton('+2', () {
                    setState(() {
                      _team1Score += 2;
                      _addToHistory('score_1_2');
                      _saveScore();
                    });
                  }, isSmall: true),
                  const SizedBox(width: 6),
                  _buildScoreButton('+3', () {
                    setState(() {
                      _team1Score += 3;
                      _addToHistory('score_1_3');
                      _saveScore();
                    });
                  }, isSmall: true),
                ],
              ),
            ],
          ),
        ),
        const Text(
          'VS',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        Expanded(
          child: Column(
            children: [
              _buildEditableTeamName(_team2Name, 2),
              const SizedBox(height: 8),
              Text(
                '$_team2Score',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: ViroColors.accent,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildScoreButton(
                    '+1',
                    () {
                      setState(() {
                        _team2Score += 1;
                        _addToHistory('score_2_1');
                        _saveScore();
                      });
                    },
                    isSmall: true,
                    color: ViroColors.accent,
                  ),
                  const SizedBox(width: 6),
                  _buildScoreButton(
                    '+2',
                    () {
                      setState(() {
                        _team2Score += 2;
                        _addToHistory('score_2_2');
                        _saveScore();
                      });
                    },
                    isSmall: true,
                    color: ViroColors.accent,
                  ),
                  const SizedBox(width: 6),
                  _buildScoreButton(
                    '+3',
                    () {
                      setState(() {
                        _team2Score += 3;
                        _addToHistory('score_2_3');
                        _saveScore();
                      });
                    },
                    isSmall: true,
                    color: ViroColors.accent,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Scoreur Handball : comme le foot
  Widget _buildHandballScoreur() {
    return _buildFootballScoreur();
  }

  // Scoreur Rugby : +3, +5, Transformation +2
  Widget _buildRugbyScoreur() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: Column(
            children: [
              _buildEditableTeamName(_team1Name, 1),
              const SizedBox(height: 8),
              Text(
                '$_team1Score',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: ViroColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildScoreButton('+3', () {
                        setState(() {
                          _team1Score += 3;
                          _addToHistory('score_1_3');
                          _saveScore();
                        });
                      }, isSmall: true),
                      const SizedBox(width: 8),
                      _buildScoreButton('+5', () {
                        setState(() {
                          _team1Score += 5;
                          _addToHistory('score_1_5');
                          _saveScore();
                        });
                      }, isSmall: true),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildScoreButton('Transformation +2', () {
                    setState(() {
                      _team1Score += 2;
                      _addToHistory('score_1_2');
                      _saveScore();
                    });
                  }, isSmall: true),
                ],
              ),
            ],
          ),
        ),
        const Text(
          'VS',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        Expanded(
          child: Column(
            children: [
              _buildEditableTeamName(_team2Name, 2),
              const SizedBox(height: 8),
              Text(
                '$_team2Score',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: ViroColors.accent,
                ),
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildScoreButton(
                        '+3',
                        () {
                          setState(() {
                            _team2Score += 3;
                            _addToHistory('score_2_3');
                            _saveScore();
                          });
                        },
                        isSmall: true,
                        color: ViroColors.accent,
                      ),
                      const SizedBox(width: 8),
                      _buildScoreButton(
                        '+5',
                        () {
                          setState(() {
                            _team2Score += 5;
                            _addToHistory('score_2_5');
                            _saveScore();
                          });
                        },
                        isSmall: true,
                        color: ViroColors.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildScoreButton(
                    'Transformation +2',
                    () {
                      setState(() {
                        _team2Score += 2;
                        _addToHistory('score_2_2');
                        _saveScore();
                      });
                    },
                    isSmall: true,
                    color: ViroColors.accent,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Scoreur Judo : Points adaptés (Ippon, Waza-ari, Yuko)
  Widget _buildJudoScoreur() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: Column(
            children: [
              _buildEditableTeamName(_team1Name, 1, isJudo: true),
              const SizedBox(height: 8),
              Text(
                '$_team1JudoScore',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: ViroColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  _buildScoreButton('Ippon (+10)', () {
                    setState(() {
                      _team1JudoScore += 10;
                      _addToHistory('judo_1_10');
                      _saveScore();
                    });
                  }, isSmall: true),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildScoreButton('Waza-ari (+7)', () {
                        setState(() {
                          _team1JudoScore += 7;
                          _addToHistory('judo_1_7');
                          _saveScore();
                        });
                      }, isSmall: true),
                      const SizedBox(width: 8),
                      _buildScoreButton('Yuko (+5)', () {
                        setState(() {
                          _team1JudoScore += 5;
                          _addToHistory('judo_1_5');
                          _saveScore();
                        });
                      }, isSmall: true),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const Text(
          'VS',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        Expanded(
          child: Column(
            children: [
              _buildEditableTeamName(_team2Name, 2, isJudo: true),
              const SizedBox(height: 8),
              Text(
                '$_team2JudoScore',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: ViroColors.accent,
                ),
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  _buildScoreButton(
                    'Ippon (+10)',
                    () {
                      setState(() {
                        _team2JudoScore += 10;
                        _addToHistory('judo_2_10');
                        _saveScore();
                      });
                    },
                    isSmall: true,
                    color: ViroColors.accent,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildScoreButton(
                        'Waza-ari (+7)',
                        () {
                          setState(() {
                            _team2JudoScore += 7;
                            _addToHistory('judo_2_7');
                            _saveScore();
                          });
                        },
                        isSmall: true,
                        color: ViroColors.accent,
                      ),
                      const SizedBox(width: 8),
                      _buildScoreButton(
                        'Yuko (+5)',
                        () {
                          setState(() {
                            _team2JudoScore += 5;
                            _addToHistory('judo_2_5');
                            _saveScore();
                          });
                        },
                        isSmall: true,
                        color: ViroColors.accent,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScoreButton(
    String label,
    VoidCallback onPressed, {
    bool isSmall = false,
    Color? color,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? ViroColors.primary,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 12 : 20,
          vertical: isSmall ? 8 : 12,
        ),
        minimumSize: isSmall ? const Size(0, 36) : const Size(80, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: isSmall ? 12 : 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
