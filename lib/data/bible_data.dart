import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BibleBook {
  final int id;
  final String abbrev;
  final String name;
  final String testament;
  final List<List<String>> chapters;

  const BibleBook({
    required this.id,
    required this.abbrev,
    required this.name,
    required this.testament,
    required this.chapters,
  });

  int get chapterCount => chapters.length;

  List<String> chapter(int number) {
    if (number < 1 || number > chapters.length) return const [];
    return chapters[number - 1];
  }

  factory BibleBook.fromJson(Map<String, dynamic> json) {
    final rawChapters = json['chapters'] as List<dynamic>;
    return BibleBook(
      id: json['id'] as int,
      abbrev: json['abbrev'] as String,
      name: json['name'] as String,
      testament: json['testament'] as String,
      chapters: rawChapters
          .map((c) => (c as List<dynamic>).map((v) => v as String).toList())
          .toList(),
    );
  }
}

class BibleVersion {
  final String id;
  final String name;
  final String shortName;
  final String license;
  final List<BibleBook> books;

  const BibleVersion({
    required this.id,
    required this.name,
    required this.shortName,
    required this.license,
    required this.books,
  });

  factory BibleVersion.fromJson(Map<String, dynamic> json) {
    return BibleVersion(
      id: json['id'] as String,
      name: json['name'] as String,
      shortName: json['shortName'] as String,
      license: json['license'] as String? ?? '',
      books: (json['books'] as List<dynamic>)
          .map((b) => BibleBook.fromJson(b as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// External versions opened via YouVersion (not bundled).
class ExternalBibleVersion {
  final String name;
  final String shortName;
  final String youVersionId;

  const ExternalBibleVersion({
    required this.name,
    required this.shortName,
    required this.youVersionId,
  });
}

const externalBibleVersions = <ExternalBibleVersion>[
  ExternalBibleVersion(
    name: 'Reina-Valera 1960',
    shortName: 'RVR1960',
    youVersionId: '149',
  ),
  ExternalBibleVersion(
    name: 'Nueva Versión Internacional',
    shortName: 'NVI',
    youVersionId: '128',
  ),
  ExternalBibleVersion(
    name: 'Traducción en Lenguaje Actual',
    shortName: 'TLA',
    youVersionId: '176',
  ),
  ExternalBibleVersion(
    name: 'Dios Habla Hoy',
    shortName: 'DHH',
    youVersionId: '118',
  ),
  ExternalBibleVersion(
    name: 'Palabra de Dios para Todos',
    shortName: 'PDT',
    youVersionId: '103',
  ),
  ExternalBibleVersion(
    name: 'La Biblia de las Américas',
    shortName: 'LBLA',
    youVersionId: '1985',
  ),
];

/// USFM book codes for YouVersion deep links (Protestant order).
const youVersionBookCodes = <String>[
  'GEN', 'EXO', 'LEV', 'NUM', 'DEU', 'JOS', 'JDG', 'RUT',
  '1SA', '2SA', '1KI', '2KI', '1CH', '2CH', 'EZR', 'NEH',
  'EST', 'JOB', 'PSA', 'PRO', 'ECC', 'SNG', 'ISA', 'JER',
  'LAM', 'EZK', 'DAN', 'HOS', 'JOL', 'AMO', 'OBA', 'JON',
  'MIC', 'NAM', 'HAB', 'ZEP', 'HAG', 'ZEC', 'MAL',
  'MAT', 'MRK', 'LUK', 'JHN', 'ACT', 'ROM', '1CO', '2CO',
  'GAL', 'EPH', 'PHP', 'COL', '1TH', '2TH', '1TI', '2TI',
  'TIT', 'PHM', 'HEB', 'JAS', '1PE', '2PE', '1JN', '2JN',
  '3JN', 'JUD', 'REV',
];

class BibleService {
  BibleService._();
  static final BibleService instance = BibleService._();

  BibleVersion? _version;
  Future<BibleVersion>? _loading;

  BibleVersion? get cached => _version;

  Future<BibleVersion> load() {
    if (_version != null) return Future.value(_version);
    return _loading ??= _load();
  }

  Future<BibleVersion> _load() async {
    final raw = await rootBundle.loadString('assets/bible/rvr1909.json');
    // jsonDecode en worker; el modelo se arma en el isolate UI.
    final decoded = await compute(_decodeBibleMap, raw);
    _version = BibleVersion.fromJson(decoded);
    _loading = null;
    return _version!;
  }
}

Map<String, dynamic> _decodeBibleMap(String raw) =>
    jsonDecode(raw) as Map<String, dynamic>;
