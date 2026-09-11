import 'package:flutter/material.dart';
import '../data/vida_verse_bank.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_body.dart';

// ─────────────── Memorama ───────────────

class MemoramaScreen extends StatefulWidget {
  const MemoramaScreen({super.key});

  @override
  State<MemoramaScreen> createState() => _MemoramaScreenState();
}

class _MemoramaScreenState extends State<MemoramaScreen> {
  static const _pairCount = 6;
  late List<_MemCard> _cards;
  int? _first;
  int? _second;
  int _matches = 0;
  bool _lock = false;
  final Set<String> _recentIds = {};

  @override
  void initState() {
    super.initState();
    _deal();
  }

  void _deal() {
    final fresh = vidaVerseBank.where((v) => !_recentIds.contains(v.id)).toList()
      ..shuffle();
    final fallback = List<VidaBankVerse>.from(vidaVerseBank)..shuffle();
    final pick = <VidaBankVerse>[];
    for (final v in [...fresh, ...fallback]) {
      if (pick.any((e) => e.id == v.id)) continue;
      pick.add(v);
      if (pick.length >= _pairCount) break;
    }
    _recentIds
      ..clear()
      ..addAll(pick.map((e) => e.id));

    final cards = <_MemCard>[];
    for (final v in pick) {
      cards.add(_MemCard(id: v.id, label: v.reference, pairId: v.id));
      final short = v.text.length > 42 ? '${v.text.substring(0, 42)}…' : v.text;
      cards.add(_MemCard(id: '${v.id}_t', label: short, pairId: v.id));
    }
    cards.shuffle();
    setState(() {
      _cards = cards;
      _first = null;
      _second = null;
      _matches = 0;
      _lock = false;
    });
  }

  Future<void> _tap(int i) async {
    if (_lock || _cards[i].matched || _cards[i].flipped) return;
    setState(() => _cards[i].flipped = true);
    if (_first == null) {
      _first = i;
      return;
    }
    _second = i;
    _lock = true;
    final first = _first!;
    final second = _second!;
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    if (_first != first || _second != second || first >= _cards.length || second >= _cards.length) {
      _first = null;
      _second = null;
      _lock = false;
      return;
    }
    final a = _cards[first];
    final b = _cards[second];
    if (a.pairId == b.pairId) {
      setState(() {
        a.matched = true;
        b.matched = true;
        _matches++;
      });
    } else {
      setState(() {
        a.flipped = false;
        b.flipped = false;
      });
    }
    _first = null;
    _second = null;
    _lock = false;
    if (_matches >= _pairCount && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¡Completaste el memorama!'),
          content: const Text('¿Otra partida con versículos nuevos?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _deal();
              },
              child: const Text('Otra partida'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memorama'),
        actions: [
          IconButton(onPressed: _deal, icon: Icon(Icons.refresh_rounded)),
        ],
      ),
      body: ResponsiveBody(
        maxWidth: 900,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final cols = w >= 860 ? 6 : w >= 560 ? 4 : 3;
            final aspect = w >= 560 ? 1.05 : 1.1;
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: aspect,
              ),
              itemCount: _cards.length,
              itemBuilder: (_, i) {
                final c = _cards[i];
                final show = c.flipped || c.matched;
                return GestureDetector(
                  onTap: () => _tap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: c.matched
                          ? AppColors.emerald200
                          : show
                              ? AppColors.emerald50
                              : AppColors.emerald600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        show ? c.label : '?',
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'DM Sans',
                          fontSize: show ? 11 : 22,
                          fontWeight: FontWeight.w600,
                          color: show ? AppColors.emerald900 : Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _MemCard {
  final String id;
  final String label;
  final String pairId;
  bool flipped = false;
  bool matched = false;
  _MemCard({
    required this.id,
    required this.label,
    required this.pairId,
  });
}

// ─────────────── Ordena el versículo ───────────────

class OrdenaVersiculoScreen extends StatefulWidget {
  const OrdenaVersiculoScreen({super.key});

  @override
  State<OrdenaVersiculoScreen> createState() => _OrdenaVersiculoScreenState();
}

class _OrdenaVersiculoScreenState extends State<OrdenaVersiculoScreen> {
  late VidaBankVerse _verse;
  late List<String> _correct;
  late List<String> _pool;
  final List<String> _built = [];
  final List<String> _recentIds = [];

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  List<String> _wordsOf(VidaBankVerse v) {
    return v.text
        .replaceAll(RegExp(r'[.,;:¿?¡!]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(10)
        .toList();
  }

  void _newRound() {
    final candidates = vidaVerseBank.where((v) {
      if (_recentIds.contains(v.id)) return false;
      return _wordsOf(v).length >= 5;
    }).toList()
      ..shuffle();
    final fallback = List<VidaBankVerse>.from(vidaVerseBank)..shuffle();
    final v = candidates.isNotEmpty ? candidates.first : fallback.first;
    final words = _wordsOf(v);
    _recentIds.add(v.id);
    while (_recentIds.length > 8) {
      _recentIds.removeAt(0);
    }
    setState(() {
      _verse = v;
      _correct = words;
      _pool = List<String>.from(words)..shuffle();
      _built.clear();
    });
  }

  void _check() {
    final ok = _built.join(' ') == _correct.join(' ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? '¡Correcto! ${_verse.reference}'
            : 'Casi… inténtalo de nuevo'),
      ),
    );
    if (ok) {
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (mounted) _newRound();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ordena el versículo'),
        actions: [
          IconButton(onPressed: _newRound, icon: Icon(Icons.refresh_rounded)),
        ],
      ),
      body: ResponsiveBody(
        maxWidth: 640,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _verse.reference,
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w700,
                  color: AppColors.emerald700,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 88),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.emerald50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.emerald200),
                  ),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < _built.length; i++)
                        ActionChip(
                          label: Text(_built[i]),
                          onPressed: () => setState(() {
                            _pool.add(_built.removeAt(i));
                          }),
                        ),
                      if (_built.isEmpty)
                        Text(
                          'Toca las palabras en orden',
                          style: TextStyle(color: AppColors.emerald500),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < _pool.length; i++)
                    ActionChip(
                      label: Text(_pool[i]),
                      onPressed: () => setState(() {
                        _built.add(_pool.removeAt(i));
                      }),
                    ),
                ],
              ),
              const Spacer(),
              FilledButton(
                onPressed: _built.length == _correct.length ? _check : null,
                child: const Text('Comprobar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────── Verdadero / Falso ───────────────

class VerdaderoFalsoScreen extends StatefulWidget {
  const VerdaderoFalsoScreen({super.key});

  @override
  State<VerdaderoFalsoScreen> createState() => _VerdaderoFalsoScreenState();
}

class _VerdaderoFalsoScreenState extends State<VerdaderoFalsoScreen> {
  static const _roundSize = 10;

  static final _pool = <({String q, bool answer, String tip})>[
    (
      q: 'Jesús nació en Belén.',
      answer: true,
      tip: 'Mateo 2 y Lucas 2 lo confirman.',
    ),
    (
      q: 'Moisés construyó el arca de Noé.',
      answer: false,
      tip: 'Fue Noé quien construyó el arca (Génesis 6).',
    ),
    (
      q: 'David venció a Goliat.',
      answer: true,
      tip: '1 Samuel 17 narra esa victoria.',
    ),
    (
      q: 'Pedro negó a Jesús tres veces.',
      answer: true,
      tip: 'Así lo cuentan los evangelios.',
    ),
    (
      q: 'El libro de Hechos está en el Antiguo Testamento.',
      answer: false,
      tip: 'Hechos está en el Nuevo Testamento.',
    ),
    (
      q: 'Pablo escribió la carta a los Romanos.',
      answer: true,
      tip: 'Romanos es una epístola paulina.',
    ),
    (
      q: 'Sansón era juez de Israel.',
      answer: true,
      tip: 'Su historia está en Jueces 13–16.',
    ),
    (
      q: 'María Magdalena era la madre de Jesús.',
      answer: false,
      tip: 'La madre de Jesús es María; Magdalena fue discípula.',
    ),
    (
      q: 'El fruto del Espíritu incluye el amor y la paz.',
      answer: true,
      tip: 'Gálatas 5:22–23.',
    ),
    (
      q: 'Jonás fue tragado por un gran pez.',
      answer: true,
      tip: 'Jonás 1:17.',
    ),
    (
      q: 'Hay cinco evangelios en la Biblia.',
      answer: false,
      tip: 'Hay cuatro: Mateo, Marcos, Lucas y Juan.',
    ),
    (
      q: 'El Salmo 23 dice: “Jehová es mi pastor”.',
      answer: true,
      tip: 'Es uno de los salmos más conocidos.',
    ),
    (
      q: 'Abraham fue el hermano de Moisés.',
      answer: false,
      tip: 'El hermano de Moisés fue Aarón.',
    ),
    (
      q: 'Jesús multiplicó panes y peces.',
      answer: true,
      tip: 'Milagro narrado en los evangelios.',
    ),
    (
      q: 'El libro de Apocalipsis abre la Biblia.',
      answer: false,
      tip: 'La Biblia comienza con Génesis; Apocalipsis la cierra.',
    ),
    (
      q: 'Noé construyó el arca por mandato de Dios.',
      answer: true,
      tip: 'Génesis 6–7.',
    ),
    (
      q: 'Saúl fue el primer rey de Israel.',
      answer: true,
      tip: '1 Samuel 10.',
    ),
    (
      q: 'Salomón escribió el libro de Hechos.',
      answer: false,
      tip: 'Hechos lo escribió Lucas.',
    ),
    (
      q: 'Daniel fue echado al foso de los leones.',
      answer: true,
      tip: 'Daniel 6.',
    ),
    (
      q: 'Jesús caminó sobre el agua.',
      answer: true,
      tip: 'Mateo 14 y otros evangelios.',
    ),
    (
      q: 'Judas Iscariote traicionó a Jesús.',
      answer: true,
      tip: 'Los evangelios lo narran claramente.',
    ),
    (
      q: 'El maná cayó del cielo en el desierto.',
      answer: true,
      tip: 'Éxodo 16.',
    ),
    (
      q: 'Ester fue reina en Egipto.',
      answer: false,
      tip: 'Ester fue reina en Persia.',
    ),
    (
      q: 'Juan el Bautista bautizó a Jesús.',
      answer: true,
      tip: 'Mateo 3.',
    ),
    (
      q: 'José, hijo de Jacob, fue vendido por sus hermanos.',
      answer: true,
      tip: 'Génesis 37.',
    ),
    (
      q: 'El templo de Salomón estaba en Nazaret.',
      answer: false,
      tip: 'Estaba en Jerusalén.',
    ),
    (
      q: 'Lázaro fue resucitado por Jesús.',
      answer: true,
      tip: 'Juan 11.',
    ),
    (
      q: 'Pablo se llamaba antes Saulo.',
      answer: true,
      tip: 'Hechos 9 / 13.',
    ),
    (
      q: 'El Mar Rojo se abrió para que pasara Israel.',
      answer: true,
      tip: 'Éxodo 14.',
    ),
    (
      q: 'Hay diez evangelios en la Biblia.',
      answer: false,
      tip: 'Solo hay cuatro evangelios.',
    ),
    (
      q: 'Rut fue nuera de Noemí.',
      answer: true,
      tip: 'Libro de Rut.',
    ),
    (
      q: 'Elías enfrentó a los profetas de Baal en el Carmelo.',
      answer: true,
      tip: '1 Reyes 18.',
    ),
    (
      q: 'Job perdió todo y aún bendijo a Dios.',
      answer: true,
      tip: 'Job 1.',
    ),
    (
      q: 'Nehemías reconstruyó los muros de Jerusalén.',
      answer: true,
      tip: 'Libro de Nehemías.',
    ),
    (
      q: 'Pilato lavó sus manos ante la muchedumbre.',
      answer: true,
      tip: 'Mateo 27.',
    ),
    (
      q: 'Génesis es el último libro de la Biblia.',
      answer: false,
      tip: 'Génesis es el primero; Apocalipsis el último.',
    ),
    (
      q: 'Jesús dio el Sermón del Monte.',
      answer: true,
      tip: 'Mateo 5–7.',
    ),
    (
      q: 'Tomás dudó de la resurrección de Jesús.',
      answer: true,
      tip: 'Juan 20.',
    ),
    (
      q: 'Caín mató a Abel.',
      answer: true,
      tip: 'Génesis 4.',
    ),
    (
      q: 'Moisés recibió la ley en el monte Sinaí.',
      answer: true,
      tip: 'Éxodo 19–20.',
    ),
    (
      q: 'El fruto del Espíritu incluye el orgullo.',
      answer: false,
      tip: 'Gálatas 5 lista amor, gozo, paz… no orgullo.',
    ),
    (
      q: 'Esteban fue el primer mártir cristiano.',
      answer: true,
      tip: 'Hechos 7.',
    ),
    (
      q: 'Belén significa “casa de pan”.',
      answer: true,
      tip: 'Así se traduce tradicionalmente el nombre.',
    ),
    (
      q: 'Herodes ordenó matar a los niños de Belén.',
      answer: true,
      tip: 'Mateo 2.',
    ),
    (
      q: 'Lucas era médico según la tradición bíblica.',
      answer: true,
      tip: 'Colosenses 4:14 lo llama “el médico amado”.',
    ),
    (
      q: 'Sansón perdió su fuerza al cortarse el cabello.',
      answer: true,
      tip: 'Jueces 16.',
    ),
    (
      q: 'El Arca de la Alianza contenía las tablas de la ley.',
      answer: true,
      tip: 'Hebreos 9 / Éxodo.',
    ),
    (
      q: 'Jesús nació en Roma.',
      answer: false,
      tip: 'Nació en Belén de Judea.',
    ),
    (
      q: 'Pentecostés fue cuando el Espíritu Santo descendió.',
      answer: true,
      tip: 'Hechos 2.',
    ),
    (
      q: 'Abraham ofreció a Isaac en el monte.',
      answer: true,
      tip: 'Génesis 22 (Dios lo detuvo).',
    ),
    (
      q: 'Proverbios enseña que el temor de Jehová es el principio de la sabiduría.',
      answer: true,
      tip: 'Proverbios 1:7 / 9:10.',
    ),
    (
      q: 'Jesús dijo: “Yo soy el camino, la verdad y la vida”.',
      answer: true,
      tip: 'Juan 14:6.',
    ),
    (
      q: 'El libro de Judas está en el Antiguo Testamento.',
      answer: false,
      tip: 'Judas está en el Nuevo Testamento.',
    ),
    (
      q: 'José interpretó sueños en Egipto.',
      answer: true,
      tip: 'Génesis 40–41.',
    ),
    (
      q: 'María y Marta eran hermanas de Lázaro.',
      answer: true,
      tip: 'Juan 11.',
    ),
  ];

  late List<({String q, bool answer, String tip})> _queue;
  int _score = 0;
  int _i = 0;
  bool? _picked;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _startRound();
  }

  void _startRound() {
    final pool = List.of(_pool)..shuffle();
    _queue = pool.take(_roundSize).toList();
    _i = 0;
    _score = 0;
    _picked = null;
    _busy = false;
  }

  Future<void> _answer(bool value) async {
    if (_busy || _picked != null) return;
    setState(() {
      _busy = true;
      _picked = value;
    });
    final ok = value == _queue[_i].answer;
    if (ok) _score++;

    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;

    if (_i < _queue.length - 1) {
      setState(() {
        _i++;
        _picked = null;
        _busy = false;
      });
    } else {
      setState(() => _busy = false);
      _showEnd();
    }
  }

  void _showEnd() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resultado'),
        content: Text(
          'Acertaste $_score de ${_queue.length}.\n'
          '${_score >= (_queue.length * 0.7).ceil() ? '¡Muy bien!' : 'Sigue practicando.'}',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(_startRound);
            },
            child: const Text('Otra partida'),
          ),
        ],
      ),
    );
  }

  Color _btnColor(bool isTrue) {
    if (_picked == null) return AppColors.emerald100;
    final correct = _queue[_i].answer;
    if (isTrue == correct) return AppColors.emerald300;
    if (_picked == isTrue) return Colors.red.shade200;
    return AppColors.emerald50;
  }

  @override
  Widget build(BuildContext context) {
    final q = _queue[_i];
    final revealed = _picked != null;
    final ok = _picked == q.answer;

    return Scaffold(
      appBar: AppBar(
        title: Text('Verdadero / Falso  (${_i + 1}/${_queue.length})'),
      ),
      body: ResponsiveBody(
        maxWidth: 640,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: (_i + (revealed ? 1 : 0)) / _queue.length,
                color: AppColors.emerald600,
                backgroundColor: AppColors.emerald100,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Aciertos: $_score',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w600,
                    color: AppColors.emerald700,
                  ),
                ),
              ),
              const Spacer(),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.emerald50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.emerald200),
                  ),
                  child: Text(
                    q.q,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cormorant Garamond',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.emerald900,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
              if (revealed) ...[
                const SizedBox(height: 14),
                Text(
                  ok ? '¡Correcto!' : 'Incorrecto',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: ok ? AppColors.emerald700 : Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  q.tip,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 13,
                    color: AppColors.emerald600,
                  ),
                ),
              ],
              const Spacer(),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            backgroundColor: _btnColor(false),
                            foregroundColor: AppColors.emerald900,
                            minimumSize: const Size.fromHeight(54),
                          ),
                          onPressed: revealed ? null : () => _answer(false),
                          child: const Text('Falso'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            backgroundColor: _btnColor(true),
                            foregroundColor: AppColors.emerald900,
                            minimumSize: const Size.fromHeight(54),
                          ),
                          onPressed: revealed ? null : () => _answer(true),
                          child: const Text('Verdadero'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────── Trivia por categorías ───────────────

class TriviaCategoriasScreen extends StatefulWidget {
  const TriviaCategoriasScreen({super.key});

  @override
  State<TriviaCategoriasScreen> createState() => _TriviaCategoriasScreenState();
}

class _TriviaQ {
  final String category;
  final String question;
  final List<String> options;
  final int correct;
  const _TriviaQ(this.category, this.question, this.options, this.correct);
}

class _TriviaCategoriasScreenState extends State<TriviaCategoriasScreen> {
  static const _roundSize = 10;
  bool _busy = false;

  static const _all = <_TriviaQ>[
    // —— Personajes ——
    _TriviaQ('Personajes', '¿Quién interpretó sueños en Egipto?',
        ['José', 'Moisés', 'Daniel', 'Samuel'], 0),
    _TriviaQ('Personajes', '¿Quién fue tragado por un gran pez?',
        ['Pedro', 'Jonás', 'Elías', 'Job'], 1),
    _TriviaQ('Personajes', '¿Quién venció a Goliat?',
        ['Saúl', 'Jonatán', 'David', 'Sansón'], 2),
    _TriviaQ('Personajes', '¿Quién negó a Jesús tres veces?',
        ['Juan', 'Pedro', 'Tomás', 'Andrés'], 1),
    _TriviaQ('Personajes', '¿Quién construyó el arca?',
        ['Noé', 'Moisés', 'Abraham', 'Nehemías'], 0),
    _TriviaQ('Personajes', '¿Quién fue vendido por sus hermanos?',
        ['Benjamín', 'José', 'Isaac', 'Jacob'], 1),
    _TriviaQ('Personajes', '¿Quién recibió los Diez Mandamientos?',
        ['Aarón', 'Josué', 'Moisés', 'Caleb'], 2),
    _TriviaQ('Personajes', '¿Quién mató a Abel?',
        ['Set', 'Caín', 'Lamec', 'Enoc'], 1),
    _TriviaQ('Personajes', '¿Quién fue el padre de Isaac?',
        ['Abraham', 'Jacob', 'Noé', 'Lot'], 0),
    _TriviaQ('Personajes', '¿Quién bautizó a Jesús?',
        ['Pedro', 'Juan el Bautista', 'Pablo', 'Santiago'], 1),
    _TriviaQ('Personajes', '¿Quién traicionó a Jesús?',
        ['Judas Iscariote', 'Pilato', 'Herodes', 'Caifás'], 0),
    _TriviaQ('Personajes', '¿Quién fue el rey más sabio de Israel?',
        ['David', 'Saúl', 'Salomón', 'Josías'], 2),
    _TriviaQ('Personajes', '¿Quién escribió muchas cartas del Nuevo Testamento?',
        ['Pedro', 'Pablo', 'Lucas', 'Marcos'], 1),
    _TriviaQ('Personajes', '¿Quién derribó los muros de Jericó con trompetas?',
        ['Josué', 'Gedeón', 'Sansón', 'Débora'], 0),
    _TriviaQ('Personajes', '¿Quién fue la madre de Jesús?',
        ['Marta', 'María', 'Isabel', 'Ana'], 1),
    _TriviaQ('Personajes', '¿Quién sobrevivió en el foso de los leones?',
        ['Daniel', 'Ezequiel', 'Jeremías', 'Eliseo'], 0),
    _TriviaQ('Personajes', '¿Quién fue el hermano de Moisés?',
        ['Aarón', 'José', 'Caleb', 'Hur'], 0),
    _TriviaQ('Personajes', '¿Quién caminó sobre el agua con Jesús?',
        ['Juan', 'Pedro', 'Andrés', 'Felipe'], 1),
    _TriviaQ('Personajes', '¿Quién fue el primer rey de Israel?',
        ['David', 'Salomón', 'Saúl', 'Roboam'], 2),
    _TriviaQ('Personajes', '¿Quién fue la esposa de Abraham?',
        ['Rebeca', 'Raquel', 'Sara', 'Lea'], 2),

    // —— Libros ——
    _TriviaQ('Libros', '¿Cuántos evangelios hay?',
        ['2', '3', '4', '5'], 2),
    _TriviaQ('Libros', '¿Cuál es el primer libro de la Biblia?',
        ['Éxodo', 'Génesis', 'Levítico', 'Mateo'], 1),
    _TriviaQ('Libros', '¿Cuál es el último libro de la Biblia?',
        ['Judas', 'Hebreos', 'Apocalipsis', 'Malaquías'], 2),
    _TriviaQ('Libros', '¿En qué libro está el relato de la creación?',
        ['Éxodo', 'Génesis', 'Job', 'Salmos'], 1),
    _TriviaQ('Libros', '¿Qué libro narra la salida de Egipto?',
        ['Génesis', 'Números', 'Éxodo', 'Deuteronomio'], 2),
    _TriviaQ('Libros', '¿Hechos de los Apóstoles está en…?',
        ['Antiguo Testamento', 'Nuevo Testamento', 'Apócrifos', 'Salmos'], 1),
    _TriviaQ('Libros', '¿Quién escribió el Evangelio de Lucas?',
        ['Lucas', 'Pablo', 'Pedro', 'Juan'], 0),
    _TriviaQ('Libros', '¿Cuál es el libro de cantos y oraciones?',
        ['Proverbios', 'Salmos', 'Eclesiastés', 'Cantares'], 1),
    _TriviaQ('Libros', '¿En qué libro está “Jehová es mi pastor”?',
        ['Salmos', 'Proverbios', 'Isaías', 'Job'], 0),
    _TriviaQ('Libros', '¿Cuántos libros tiene aproximadamente el Nuevo Testamento?',
        ['12', '27', '39', '66'], 1),
    _TriviaQ('Libros', '¿Qué libro cuenta la historia de Rut?',
        ['Rut', 'Ester', 'Judit', 'Nehemías'], 0),
    _TriviaQ('Libros', '¿Qué libro habla de una reina judía en Persia?',
        ['Rut', 'Ester', 'Daniel', 'Esdras'], 1),
    _TriviaQ('Libros', '¿Romanos es una carta escrita por…?',
        ['Pedro', 'Santiago', 'Pablo', 'Juan'], 2),
    _TriviaQ('Libros', '¿Qué libro describe visiones del fin de los tiempos?',
        ['Apocalipsis', 'Hechos', 'Hebreos', 'Tito'], 0),
    _TriviaQ('Libros', '¿Proverbios se asocia sobre todo con…?',
        ['Salomón', 'David', 'Moisés', 'Isaías'], 0),
    _TriviaQ('Libros', '¿Cuál NO es un evangelio?',
        ['Marcos', 'Hechos', 'Juan', 'Mateo'], 1),
    _TriviaQ('Libros', '¿En qué libro está el Sermón del Monte?',
        ['Mateo', 'Hechos', 'Romanos', 'Apocalipsis'], 0),
    _TriviaQ('Libros', '¿Qué libro sigue a Génesis?',
        ['Levítico', 'Éxodo', 'Números', 'Josué'], 1),
    _TriviaQ('Libros', '¿Job trata principalmente sobre…?',
        ['Sabiduría y sufrimiento', 'Leyes', 'Guerras', 'Genealogías'], 0),
    _TriviaQ('Libros', '¿Quién escribió muchos salmos?',
        ['David', 'Noé', 'José', 'Sansón'], 0),

    // —— Milagros ——
    _TriviaQ('Milagros', '¿Qué multiplicó Jesús?',
        ['Peces y panes', 'Aceite', 'Maná', 'Uvas'], 0),
    _TriviaQ('Milagros', 'Jesús calmó…',
        ['Un incendio', 'Una tormenta', 'Un terremoto', 'Una plaga'], 1),
    _TriviaQ('Milagros', '¿Qué convirtió Jesús en Caná?',
        ['Agua en vino', 'Piedras en pan', 'Arena en oro', 'Aceite en miel'], 0),
    _TriviaQ('Milagros', '¿A quién resucitó Jesús después de cuatro días?',
        ['Jairo', 'Lázaro', 'Tabita', 'Elías'], 1),
    _TriviaQ('Milagros', '¿Qué mar cruzó Israel en seco?',
        ['Mar Muerto', 'Mar Rojo', 'Mar de Galilea', 'Mediterráneo'], 1),
    _TriviaQ('Milagros', '¿Qué cayó del cielo para alimentar a Israel?',
        ['Maná', 'Trigo', 'Aceitunas', 'Dátiles'], 0),
    _TriviaQ('Milagros', '¿Quién sanó a Naamán de lepra?',
        ['Elías', 'Eliseo', 'Isaías', 'Jeremías'], 1),
    _TriviaQ('Milagros', '¿Qué hizo Jesús al ciego de nacimiento?',
        ['Lo ignoró', 'Lo sanó', 'Lo reprendió', 'Lo envió a Roma'], 1),
    _TriviaQ('Milagros', '¿Sansón derribó un templo con…?',
        ['Espada', 'Su fuerza', 'Fuego', 'Un ejército'], 1),
    _TriviaQ('Milagros', '¿Elías hizo bajar fuego del cielo en el monte…?',
        ['Sinaí', 'Carmel', 'Tabor', 'Hermón'], 1),
    _TriviaQ('Milagros', '¿Pedro sanó a un cojo en el nombre de…?',
        ['Moisés', 'Jesús', 'Abraham', 'David'], 1),
    _TriviaQ('Milagros', '¿Qué animal habló a Balaam?',
        ['Un caballo', 'Una mula', 'Un camello', 'Una oveja'], 1),
    _TriviaQ('Milagros', '¿Jesús caminó sobre…?',
        ['El fuego', 'El agua', 'Las nubes', 'La arena'], 1),
    _TriviaQ('Milagros', '¿Qué plaga NO fue de Egipto?',
        ['Ranas', 'Langostas', 'Nieve eterna', 'Tinieblas'], 2),
    _TriviaQ('Milagros', '¿Jesús sanó a diez…?',
        ['Ciegos', 'Cojos', 'Leprosos', 'Sordos'], 2),
    _TriviaQ('Milagros', '¿Daniel salió ileso de…?',
        ['Un horno', 'Un foso de leones', 'Un naufragio', 'Una cárcel'], 1),
    _TriviaQ('Milagros', '¿Qué abrió el Jordán para que pasara Israel?',
        ['Moisés', 'Josué', 'Aarón', 'Gedeón'], 1),
    _TriviaQ('Milagros', '¿Jesús resucitó a la hija de…?',
        ['Jairo', 'Nicodemo', 'Zaqueo', 'Lázaro'], 0),
    _TriviaQ('Milagros', '¿El aceite de la viuda no se acabó por obra de…?',
        ['Elías', 'Eliseo', 'Samuel', 'Natán'], 0),
    _TriviaQ('Milagros', '¿Pablo sobrevivió a la mordedura de…?',
        ['Un león', 'Una serpiente', 'Un escorpión', 'Un perro'], 1),

    // —— Enseñanzas ——
    _TriviaQ('Enseñanzas', 'El fruto del Espíritu NO incluye…',
        ['Amor', 'Orgullo', 'Paz', 'Gozo'], 1),
    _TriviaQ('Enseñanzas', '“Jehová es mi pastor” está en…',
        ['Salmo 23', 'Salmo 1', 'Proverbios 3', 'Isaías 40'], 0),
    _TriviaQ('Enseñanzas', '¿Cuál es el mayor mandamiento según Jesús?',
        ['Dar diezmos', 'Amar a Dios', 'Guardar el sábado', 'Ayunar'], 1),
    _TriviaQ('Enseñanzas', '“Porque de tal manera amó Dios al mundo…” está en…',
        ['Juan 3:16', 'Mateo 5:1', 'Romanos 8:28', 'Salmo 23'], 0),
    _TriviaQ('Enseñanzas', 'La fe sin obras está…',
        ['Completa', 'Muerta', 'Perfecta', 'Opcional'], 1),
    _TriviaQ('Enseñanzas', '¿Cuántas bienaventuranzas hay en Mateo 5?',
        ['3', '7', '9', '12'], 2),
    _TriviaQ('Enseñanzas', '“El Señor es mi luz y mi salvación” está en…',
        ['Salmo 27', 'Salmo 100', 'Proverbios 1', 'Isaías 53'], 0),
    _TriviaQ('Enseñanzas', 'Jesús dijo: “Yo soy el camino, la verdad y…”',
        ['La paz', 'La vida', 'La luz', 'El pan'], 1),
    _TriviaQ('Enseñanzas', '¿Qué dice Proverbios sobre el temor de Jehová?',
        ['Es inútil', 'Es el principio de la sabiduría', 'Es opcional', 'Es miedo'], 1),
    _TriviaQ('Enseñanzas', '“Todo lo puedo en Cristo…” continúa…',
        ['que me fortalece', 'si tengo dinero', 'si soy famoso', 'si ayuno'], 0),
    _TriviaQ('Enseñanzas', 'El amor es… según 1 Corintios 13',
        ['Paciente', 'Orgulloso', 'Envidioso', 'Rudo'], 0),
    _TriviaQ('Enseñanzas', '¿Quién debe ser el primero según Jesús?',
        ['El más rico', 'El siervo de todos', 'El más fuerte', 'El más sabio'], 1),
    _TriviaQ('Enseñanzas', '“Venid a mí todos los que estáis…',
        ['alegres', 'trabajados y cargados', 'ricos', 'perfectos'], 1),
    _TriviaQ('Enseñanzas', 'La armadura de Dios incluye el yelmo de…',
        ['La salvación', 'El oro', 'La fama', 'La fuerza'], 0),
    _TriviaQ('Enseñanzas', '“Sed santos, porque yo soy santo” enseña…',
        ['Orgullo', 'Santidad', 'Riqueza', 'Guerra'], 1),
    _TriviaQ('Enseñanzas', 'Jesús enseñó a orar con…',
        ['El Padre Nuestro', 'Un himno romano', 'Un salmo solo', 'Silencio eterno'], 0),
    _TriviaQ('Enseñanzas', '“No os afanéis por el día de mañana” enseña…',
        ['Pereza', 'Confianza en Dios', 'Ahorro extremo', 'Miedo'], 1),
    _TriviaQ('Enseñanzas', 'El buen samaritano enseña…',
        ['Amor al prójimo', 'Odios tribales', 'Riqueza', 'Venganza'], 0),
    _TriviaQ('Enseñanzas', '“La verdad os hará…',
        ['libres', 'ricos', 'famosos', 'fuertes'], 0),
    _TriviaQ('Enseñanzas', 'Dar el otro… significa…',
        ['mejilla / no devolver mal', 'ojo / venganza', 'brazo / pelear', 'paso / huir'], 0),

    // —— Lugares ——
    _TriviaQ('Lugares', '¿Dónde nació Jesús?',
        ['Nazaret', 'Belén', 'Jerusalén', 'Capernaum'], 1),
    _TriviaQ('Lugares', '¿Dónde creció Jesús gran parte de su vida?',
        ['Belén', 'Nazaret', 'Roma', 'Egipto'], 1),
    _TriviaQ('Lugares', '¿En qué monte recibió Moisés la ley?',
        ['Carmel', 'Sinaí', 'Tabor', 'Olivos'], 1),
    _TriviaQ('Lugares', '¿Dónde fue crucificado Jesús?',
        ['Getsemaní', 'El Gólgota', 'Betania', 'Jericó'], 1),
    _TriviaQ('Lugares', '¿Qué ciudad cayó al sonar las trompetas?',
        ['Jericó', 'Nínive', 'Sodoma', 'Tiro'], 0),
    _TriviaQ('Lugares', '¿Dónde oró Jesús antes de ser arrestado?',
        ['Getsemaní', 'El templo', 'Caná', 'Betel'], 0),
    _TriviaQ('Lugares', '¿A qué país fue José llevado como esclavo?',
        ['Babilonia', 'Egipto', 'Asiria', 'Persia'], 1),
    _TriviaQ('Lugares', '¿Dónde predicó Jonás?',
        ['Nínive', 'Tiro', 'Sidón', 'Damasco'], 0),
    _TriviaQ('Lugares', '¿Qué río cruzó Israel para entrar a Canaán?',
        ['Nilo', 'Jordán', 'Éufrates', 'Tigris'], 1),
    _TriviaQ('Lugares', '¿Dónde estaba el arca de Noé cuando se posó?',
        ['Sinaí', 'Ararat', 'Carmel', 'Hermón'], 1),
    _TriviaQ('Lugares', '¿En qué ciudad Pablo estuvo preso y escribió cartas?',
        ['Roma', 'Atenas', 'Corinto', 'Éfeso'], 0),
    _TriviaQ('Lugares', '¿Dónde se edificó el templo de Salomón?',
        ['Samaria', 'Jerusalén', 'Belén', 'Hebrón'], 1),
    _TriviaQ('Lugares', '¿Qué mar se abre en el Éxodo?',
        ['Mar Rojo', 'Mar Muerto', 'Galilea', 'Negro'], 0),
    _TriviaQ('Lugares', '¿Dónde Jesús dio el Sermón del Monte?',
        ['En un monte', 'En el templo', 'En el desierto', 'En un barco'], 0),
    _TriviaQ('Lugares', '¿A qué ciudad huyó Lot?',
        ['Sodoma', 'Zoár', 'Nínive', 'Ur'], 1),

    // —— Historia ——
    _TriviaQ('Historia', '¿Cuántos días llovió en el diluvio?',
        ['7', '20', '40', '100'], 2),
    _TriviaQ('Historia', '¿Cuántos días estuvo Jesús en el desierto?',
        ['7', '12', '40', '70'], 2),
    _TriviaQ('Historia', '¿Quién liberó a Israel de Egipto?',
        ['Josué', 'Moisés', 'Aarón', 'Caleb'], 1),
    _TriviaQ('Historia', '¿Cuántos años anduvo Israel en el desierto?',
        ['10', '20', '40', '70'], 2),
    _TriviaQ('Historia', '¿Quién ungió a David como rey?',
        ['Natán', 'Samuel', 'Elías', 'Gad'], 1),
    _TriviaQ('Historia', '¿Qué imperio destruyó Jerusalén en tiempos de Daniel?',
        ['Roma', 'Babilonia', 'Grecia', 'Egipto'], 1),
    _TriviaQ('Historia', '¿Quién reconstruyó los muros de Jerusalén?',
        ['Esdras', 'Nehemías', 'Zorobabel', 'Malaquías'], 1),
    _TriviaQ('Historia', '¿En qué fiesta fue derramado el Espíritu en Hechos 2?',
        ['Pascua', 'Pentecostés', 'Tabernáculos', 'Purim'], 1),
    _TriviaQ('Historia', '¿Quién fue el juez que derrotó a Madián con 300 hombres?',
        ['Sansón', 'Gedeón', 'Débora', 'Jefté'], 1),
    _TriviaQ('Historia', '¿Cuántas plagas cayeron sobre Egipto?',
        ['7', '10', '12', '40'], 1),
    _TriviaQ('Historia', '¿Quién interpretó la escritura en la pared?',
        ['Daniel', 'José', 'Ezequiel', 'Isaías'], 0),
    _TriviaQ('Historia', '¿Qué rey ordenó matar a los niños de Belén?',
        ['Herodes', 'Pilato', 'César', 'Nabucodonosor'], 0),
    _TriviaQ('Historia', '¿Quién fue el primer mártir cristiano en Hechos?',
        ['Esteban', 'Santiago', 'Pedro', 'Pablo'], 0),
    _TriviaQ('Historia', '¿Abraham casi ofrece a quién en el monte?',
        ['Ismael', 'Isaac', 'Jacob', 'Lot'], 1),
    _TriviaQ('Historia', '¿Cuántos discípulos principales eligió Jesús?',
        ['7', '10', '12', '70'], 2),
  ];

  String? _category;
  late List<_TriviaQ> _qs;
  int _i = 0;
  int _score = 0;

  static const _mixLabel = 'Mezcla';

  void _pick(String cat) {
    setState(() {
      _busy = false;
      _category = cat;
      final pool = cat == _mixLabel
          ? (List.of(_all)..shuffle())
          : (_all.where((q) => q.category == cat).toList()..shuffle());
      final selected = pool.take(_roundSize);
      _qs = selected.map(_withShuffledOptions).toList();
      _i = 0;
      _score = 0;
    });
  }

  static _TriviaQ _withShuffledOptions(_TriviaQ q) {
    final opts = List<String>.from(q.options);
    final correctText = opts[q.correct];
    opts.shuffle();
    return _TriviaQ(q.category, q.question, opts, opts.indexOf(correctText));
  }

  void _answer(int opt) {
    if (_busy) return;
    _busy = true;
    if (opt == _qs[_i].correct) _score++;
    if (_i < _qs.length - 1) {
      setState(() {
        _i++;
        _busy = false;
      });
    } else {
      final cat = _category!;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Fin'),
          content: Text('Puntuación: $_score / ${_qs.length}'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _pick(cat);
              },
              child: const Text('Otra partida'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _category = null;
                  _busy = false;
                });
              },
              child: const Text('Categorías'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_category == null) {
      final cats = _all.map((e) => e.category).toSet().toList()..shuffle();
      return Scaffold(
        appBar: AppBar(title: const Text('Trivia por categorías')),
        body: ResponsiveBody(
          maxWidth: 560,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: AppColors.emerald50,
                child: ListTile(
                  leading:
                      Icon(Icons.shuffle_rounded, color: AppColors.emerald700),
                  title: const Text(_mixLabel),
                  subtitle: const Text('10 preguntas de todas las categorías'),
                  trailing: Icon(Icons.chevron_right_rounded),
                  onTap: () => _pick(_mixLabel),
                ),
              ),
              const SizedBox(height: 8),
              for (final c in cats)
                Card(
                  child: ListTile(
                    title: Text(c),
                    trailing: Icon(Icons.chevron_right_rounded),
                    onTap: () => _pick(c),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final q = _qs[_i];
    return Scaffold(
      appBar: AppBar(title: Text('$_category · ${_i + 1}/${_qs.length}')),
      body: ResponsiveBody(
        maxWidth: 640,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                q.question,
                style: TextStyle(
                  fontFamily: 'Cormorant Garamond',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.emerald900,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < q.options.length; i++) ...[
                        FilledButton.tonal(
                          onPressed: () => _answer(i),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(q.options[i]),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────── Camino del discípulo ───────────────

class CaminoDiscipuloScreen extends StatefulWidget {
  const CaminoDiscipuloScreen({super.key});

  @override
  State<CaminoDiscipuloScreen> createState() => _CaminoDiscipuloScreenState();
}

class _Choice {
  final String label;
  final int faithDelta;
  final int heartDelta;
  const _Choice(this.label, {this.faithDelta = 0, this.heartDelta = 0});
}

class _Scene {
  final String text;
  final List<_Choice> choices;
  const _Scene(this.text, this.choices);
}

class _CaminoDiscipuloScreenState extends State<CaminoDiscipuloScreen> {
  static const _pathLength = 5;

  int _step = 0;
  int _heart = 3;
  int _faith = 0;
  late List<_Scene> _path;
  late List<_Choice> _shuffled;

  /// Banco amplio: cada partida toma [_pathLength] escenas al azar.
  static const _pool = <_Scene>[
    _Scene(
      'Un amigo se burla de tu fe. ¿Qué haces?',
      [
        _Choice('Responder con mansedumbre', faithDelta: 1),
        _Choice('Ignorarlo y alejarte en silencio'),
        _Choice('Responder con ira', heartDelta: -1),
      ],
    ),
    _Scene(
      'Tienes poco tiempo hoy. ¿Qué priorizas?',
      [
        _Choice('Orar aunque sea un minuto', faithDelta: 1),
        _Choice('Posponerlo “para mañana”'),
        _Choice('Ignorar a Dios del todo', heartDelta: -1),
      ],
    ),
    _Scene(
      'Alguien te ofende. ¿Qué eliges?',
      [
        _Choice('Perdonar como fuiste perdonado', faithDelta: 1),
        _Choice('Evitarlo sin hablar del tema'),
        _Choice('Guardar rencor', heartDelta: -1),
      ],
    ),
    _Scene(
      'Ves a alguien necesitado. ¿Qué haces?',
      [
        _Choice('Ayudar en lo que puedas', faithDelta: 1),
        _Choice('Orar por esa persona y seguir'),
        _Choice('Seguir de largo sin compasión', heartDelta: -1),
      ],
    ),
    _Scene(
      'Sientes tentación. ¿Qué haces?',
      [
        _Choice('Huir y pedir fuerza a Dios', faithDelta: 1),
        _Choice('Distraerte con otra actividad'),
        _Choice('Ceder “solo esta vez”', heartDelta: -1),
      ],
    ),
    _Scene(
      'Te invitan a mentir “solo un poco” en el trabajo. ¿Qué haces?',
      [
        _Choice('Decir la verdad con respeto', faithDelta: 1),
        _Choice('Quedarte callado y no participar'),
        _Choice('Mentir para quedar bien', heartDelta: -1),
      ],
    ),
    _Scene(
      'Es domingo y tienes sueño. ¿Qué eliges?',
      [
        _Choice('Ir a la congregación', faithDelta: 1),
        _Choice('Quedarte y orar en casa'),
        _Choice('Ignorar a Dios todo el día', heartDelta: -1),
      ],
    ),
    _Scene(
      'Alguien habla mal de un hermano. ¿Qué haces?',
      [
        _Choice('Cortar el chisme con gracia', faithDelta: 1),
        _Choice('Cambiar de tema sin confrontar'),
        _Choice('Unirte al chisme', heartDelta: -1),
      ],
    ),
    _Scene(
      'Tienes dinero extra este mes. ¿Qué priorizas?',
      [
        _Choice('Dar con alegría a quien lo necesita', faithDelta: 1),
        _Choice('Ahorrarlo sin pensar en nadie'),
        _Choice('Gastarlo solo en caprichos', heartDelta: -1),
      ],
    ),
    _Scene(
      'Un compañero pregunta por qué crees. ¿Qué haces?',
      [
        _Choice('Compartir tu testimonio con humildad', faithDelta: 1),
        _Choice('Responder breve y cambiar de tema'),
        _Choice('Avergonzarte y negar tu fe', heartDelta: -1),
      ],
    ),
    _Scene(
      'Estás enojado con tu familia. ¿Qué eliges?',
      [
        _Choice('Hablar con calma y buscar paz', faithDelta: 1),
        _Choice('Tomarte un tiempo en silencio'),
        _Choice('Estallar y herir con palabras', heartDelta: -1),
      ],
    ),
    _Scene(
      'Ves contenido que te aleja de Dios. ¿Qué haces?',
      [
        _Choice('Cerrarlo y fijar la mente en Cristo', faithDelta: 1),
        _Choice('Seguir un rato “sin pensarlo”'),
        _Choice('Sumergirte en ello', heartDelta: -1),
      ],
    ),
    _Scene(
      'Un hermano está triste. ¿Qué haces?',
      [
        _Choice('Escucharlo y orar con él', faithDelta: 1),
        _Choice('Enviarle un mensaje corto'),
        _Choice('Ignorarlo porque “no es tu problema”', heartDelta: -1),
      ],
    ),
    _Scene(
      'Te cuesta leer la Biblia hoy. ¿Qué eliges?',
      [
        _Choice('Leer aunque sea un versículo', faithDelta: 1),
        _Choice('Escuchar un audio bíblico'),
        _Choice('Dejarlo por completo', heartDelta: -1),
      ],
    ),
    _Scene(
      'Alguien te pide perdón. ¿Qué haces?',
      [
        _Choice('Perdonar de corazón', faithDelta: 1),
        _Choice('Aceptarlo, pero con distancia'),
        _Choice('Rechazarlo y exigir venganza', heartDelta: -1),
      ],
    ),
    _Scene(
      'Ganas un juego o un examen. ¿Qué eliges?',
      [
        _Choice('Dar gracias a Dios con humildad', faithDelta: 1),
        _Choice('Celebrar en silencio'),
        _Choice('Jactarte y menospreciar a otros', heartDelta: -1),
      ],
    ),
    _Scene(
      'Te sientes solo esta noche. ¿Qué haces?',
      [
        _Choice('Orar y recordar que Dios está contigo', faithDelta: 1),
        _Choice('Hablar con un amigo de confianza'),
        _Choice('Buscar consuelo en lo que te daña', heartDelta: -1),
      ],
    ),
    _Scene(
      'Puedes copiar en un examen sin que te vean. ¿Qué haces?',
      [
        _Choice('Ser íntegro aunque cueste', faithDelta: 1),
        _Choice('No copiar, pero preocuparte en silencio'),
        _Choice('Copiar “solo esta vez”', heartDelta: -1),
      ],
    ),
    _Scene(
      'Hay una persona nueva en la iglesia. ¿Qué haces?',
      [
        _Choice('Saludarla y hacerla sentir bienvenida', faithDelta: 1),
        _Choice('Sonreírle desde lejos'),
        _Choice('Ignorarla por completo', heartDelta: -1),
      ],
    ),
    _Scene(
      'Te acusan de algo que no hiciste. ¿Qué eliges?',
      [
        _Choice('Explicar con paz y confiar en Dios', faithDelta: 1),
        _Choice('Quedarte callado y esperar'),
        _Choice('Responder con insultos', heartDelta: -1),
      ],
    ),
    _Scene(
      'Tu plan de oración se rompió esta semana. ¿Qué haces?',
      [
        _Choice('Retomar hoy sin culparte', faithDelta: 1),
        _Choice('Prometerte “empezar el lunes”'),
        _Choice('Abandonar la oración', heartDelta: -1),
      ],
    ),
    _Scene(
      'Alguien necesita que le prestes tiempo, no dinero. ¿Qué haces?',
      [
        _Choice('Escucharlo con paciencia', faithDelta: 1),
        _Choice('Decirle que luego hablan'),
        _Choice('Rechazarlo con dureza', heartDelta: -1),
      ],
    ),
    _Scene(
      'Te ofrecen un atajo fácil pero injusto. ¿Qué eliges?',
      [
        _Choice('Rechazarlo y hacer lo correcto', faithDelta: 1),
        _Choice('Dudar, pero no aceptar'),
        _Choice('Tomarlo sin pensarlo', heartDelta: -1),
      ],
    ),
    _Scene(
      'En redes ves odio y pelea. ¿Qué haces?',
      [
        _Choice('No alimentar el fuego y orar', faithDelta: 1),
        _Choice('Salir de la discusión'),
        _Choice('Entrar a pelear con palabras', heartDelta: -1),
      ],
    ),
    _Scene(
      'Un amigo cae en pecado. ¿Qué haces?',
      [
        _Choice('Restaurarlo con mansedumbre', faithDelta: 1),
        _Choice('Orar por él en privado'),
        _Choice('Exponerlo y humillarlo', heartDelta: -1),
      ],
    ),
    _Scene(
      'Te sientes orgulloso de tu servicio. ¿Qué eliges?',
      [
        _Choice('Dar la gloria a Dios', faithDelta: 1),
        _Choice('Seguir sirviendo en silencio'),
        _Choice('Buscar aplausos de la gente', heartDelta: -1),
      ],
    ),
    _Scene(
      'Es tarde y estás agotado. ¿Qué priorizas?',
      [
        _Choice('Descansar y encomendar el día a Dios', faithDelta: 1),
        _Choice('Quedarte viendo pantallas sin límite'),
        _Choice('Quejarte y dormir con amargura', heartDelta: -1),
      ],
    ),
    _Scene(
      'Alguien te pide consejo espiritual. ¿Qué haces?',
      [
        _Choice('Señalar a Cristo y a la Escritura', faithDelta: 1),
        _Choice('Escuchar y admitir que no sabes todo'),
        _Choice('Hablar como si fueras la autoridad absoluta', heartDelta: -1),
      ],
    ),
    _Scene(
      'Te equivocas frente a otros. ¿Qué eliges?',
      [
        _Choice('Pedir perdón y corregirlo', faithDelta: 1),
        _Choice('Aceptarlo en silencio'),
        _Choice('Culpar a otros', heartDelta: -1),
      ],
    ),
    _Scene(
      'Hay una oportunidad de servir que nadie quiere. ¿Qué haces?',
      [
        _Choice('Ofrecerte con humildad', faithDelta: 1),
        _Choice('Ayudar si te lo piden'),
        _Choice('Evitarlo porque “no te toca”', heartDelta: -1),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startNewPath();
  }

  void _startNewPath() {
    final pool = List<_Scene>.from(_pool)..shuffle();
    _path = pool.take(_pathLength).toList();
    _step = 0;
    _heart = 3;
    _faith = 0;
    _reshuffleChoices();
  }

  void _reshuffleChoices() {
    _shuffled = List<_Choice>.from(_path[_step].choices)..shuffle();
  }

  void _choose(_Choice c) {
    var shouldEndWin = false;
    var shouldEndLose = false;
    setState(() {
      _faith += c.faithDelta;
      _heart += c.heartDelta;
      if (_heart <= 0) {
        shouldEndLose = true;
        return;
      }
      if (_step >= _path.length - 1) {
        shouldEndWin = true;
        return;
      }
      _step++;
      _reshuffleChoices();
    });
    if (shouldEndLose || shouldEndWin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _end(shouldEndWin);
      });
    }
  }

  void _end(bool won) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(won ? '¡Bien hecho!' : 'Ánimo, discípulo'),
        content: Text(
          won
              ? 'Terminaste el camino con $_faith decisiones sabias.'
              : 'Tropezaste, pero la gracia te levanta. Fe: $_faith',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(_startNewPath);
            },
            child: const Text('Reintentar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _path[_step];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camino del discípulo'),
      ),
      body: ResponsiveBody(
        maxWidth: 640,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    '❤️ × $_heart',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.emerald800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Fe: $_faith',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.emerald800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_step + 1) / _path.length,
                color: AppColors.emerald600,
                backgroundColor: AppColors.emerald100,
              ),
              const Spacer(),
              Text(
                s.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cormorant Garamond',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.emerald900,
                ),
              ),
              const Spacer(),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final c in _shuffled) ...[
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.emerald100,
                            foregroundColor: AppColors.emerald900,
                            minimumSize: const Size.fromHeight(52),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onPressed: () => _choose(c),
                          child: Text(c.label, textAlign: TextAlign.center),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────── ¿Quién lo dijo? ───────────────

class QuienLoDijoScreen extends StatefulWidget {
  const QuienLoDijoScreen({super.key});

  @override
  State<QuienLoDijoScreen> createState() => _QuienLoDijoScreenState();
}

class _QuienQ {
  final String quote;
  final String reference;
  final List<String> options;
  final int correct;
  const _QuienQ(this.quote, this.reference, this.options, this.correct);
}

class _QuienLoDijoScreenState extends State<QuienLoDijoScreen> {
  static const _roundSize = 10;

  static final _pool = <_QuienQ>[
    const _QuienQ(
      '“Yo soy el camino, y la verdad, y la vida.”',
      'Juan 14:6',
      ['Pedro', 'Jesús', 'Pablo', 'Moisés'],
      1,
    ),
    const _QuienQ(
      '“Jehová es mi pastor; nada me faltará.”',
      'Salmo 23:1',
      ['Salomón', 'David', 'Isaías', 'Job'],
      1,
    ),
    const _QuienQ(
      '“Todo lo puedo en Cristo que me fortalece.”',
      'Filipenses 4:13',
      ['Pablo', 'Pedro', 'Juan', 'Santiago'],
      0,
    ),
    const _QuienQ(
      '“En el principio creó Dios los cielos y la tierra.”',
      'Génesis 1:1',
      ['Escritura (Moisés)', 'David', 'Elías', 'Daniel'],
      0,
    ),
    const _QuienQ(
      '“Antes que Abraham fuese, yo soy.”',
      'Juan 8:58',
      ['Juan el Bautista', 'Jesús', 'Nicodemo', 'Felipe'],
      1,
    ),
    const _QuienQ(
      '“Arrepentíos, porque el reino de los cielos se ha acercado.”',
      'Mateo 3:2',
      ['Jesús', 'Juan el Bautista', 'Pedro', 'Andrés'],
      1,
    ),
    const _QuienQ(
      '“Aun si él me matare, en él esperaré.”',
      'Job 13:15',
      ['Job', 'José', 'Daniel', 'Habacuc'],
      0,
    ),
    const _QuienQ(
      '“He aquí la sierva del Señor; hágase conmigo conforme a tu palabra.”',
      'Lucas 1:38',
      ['Isabel', 'María', 'Ana', 'Marta'],
      1,
    ),
    const _QuienQ(
      '“¿Quién eres, Señor? … ¿Qué quieres que yo haga?”',
      'Hechos 9:5-6',
      ['Pedro', 'Saulo (Pablo)', 'Esteban', 'Ananías'],
      1,
    ),
    const _QuienQ(
      '“Escogeos hoy a quién sirváis… pero yo y mi casa serviremos a Jehová.”',
      'Josué 24:15',
      ['Josué', 'Caleb', 'Gedeón', 'Samuel'],
      0,
    ),
    const _QuienQ(
      '“El Señor me ha ungido… a predicar buenas nuevas a los abatidos.”',
      'Isaías 61:1',
      ['Jeremías', 'Isaías', 'Ezequiel', 'Malaquías'],
      1,
    ),
    const _QuienQ(
      '“Señor, ¿a quién iremos? Tú tienes palabras de vida eterna.”',
      'Juan 6:68',
      ['Tomás', 'Pedro', 'Juan', 'Andrés'],
      1,
    ),
    const _QuienQ(
      '“He peleado la buena batalla, he acabado la carrera, he guardado la fe.”',
      '2 Timoteo 4:7',
      ['Pablo', 'Pedro', 'Timoteo', 'Tito'],
      0,
    ),
    const _QuienQ(
      '“He aquí el Cordero de Dios, que quita el pecado del mundo.”',
      'Juan 1:29',
      ['Pedro', 'Juan el Bautista', 'Andrés', 'Felipe'],
      1,
    ),
    const _QuienQ(
      '“Si Jehová no edificare la casa, en vano trabajan los que la edifican.”',
      'Salmo 127:1',
      ['David', 'Salomón', 'Asaf', 'Moisés'],
      1,
    ),
  ];

  late List<_QuienQ> _qs;
  int _i = 0;
  int _score = 0;
  bool _busy = false;
  int? _picked;

  @override
  void initState() {
    super.initState();
    _deal();
  }

  void _deal() {
    final pool = List<_QuienQ>.from(_pool)..shuffle();
    setState(() {
      _qs = pool.take(_roundSize).map((q) {
        final opts = List<String>.from(q.options);
        final correctText = opts[q.correct];
        opts.shuffle();
        return _QuienQ(q.quote, q.reference, opts, opts.indexOf(correctText));
      }).toList();
      _i = 0;
      _score = 0;
      _busy = false;
      _picked = null;
    });
  }

  Future<void> _answer(int opt) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _picked = opt;
    });
    final ok = opt == _qs[_i].correct;
    if (ok) _score++;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    if (_i < _qs.length - 1) {
      setState(() {
        _i++;
        _busy = false;
        _picked = null;
      });
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Fin de la ronda'),
          content: Text('Aciertos: $_score / ${_qs.length}'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _deal();
              },
              child: const Text('Otra ronda'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Salir'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _qs[_i];
    return Scaffold(
      appBar: AppBar(
        title: Text('¿Quién lo dijo?  (${_i + 1}/${_qs.length})'),
      ),
      body: ResponsiveBody(
        maxWidth: 640,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: (_i + 1) / _qs.length,
                color: AppColors.emerald600,
                backgroundColor: AppColors.emerald100,
              ),
              const SizedBox(height: 8),
              Text(
                'Puntos: $_score',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w600,
                  color: AppColors.emerald700,
                ),
              ),
              const Spacer(),
              Text(
                q.quote,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cormorant Garamond',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  color: AppColors.emerald900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                q.reference,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 13,
                  color: AppColors.emerald600,
                ),
              ),
              const Spacer(),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < q.options.length; i++) ...[
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            backgroundColor: _picked == null
                                ? AppColors.emerald100
                                : (i == q.correct
                                    ? AppColors.emerald200
                                    : (_picked == i
                                        ? const Color(0xFFFFE4E6)
                                        : AppColors.emerald50)),
                            foregroundColor: AppColors.emerald900,
                            minimumSize: const Size.fromHeight(52),
                          ),
                          onPressed: _busy ? null : () => _answer(i),
                          child:
                              Text(q.options[i], textAlign: TextAlign.center),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
