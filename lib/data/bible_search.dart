import '../data/bible_data.dart';

class BibleSearchHit {
  final int bookIndex;
  final String bookName;
  final int chapter;
  final int verse;
  final String text;

  const BibleSearchHit({
    required this.bookIndex,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.text,
  });
}

/// Búsqueda simple de texto en la Biblia cargada (RVR1909).
class BibleSearch {
  static List<BibleSearchHit> query(
    BibleVersion bible,
    String raw, {
    int limit = 80,
  }) {
    final q = raw.trim().toLowerCase();
    if (q.length < 2) return const [];
    final hits = <BibleSearchHit>[];
    for (var bi = 0; bi < bible.books.length; bi++) {
      final book = bible.books[bi];
      for (var c = 0; c < book.chapters.length; c++) {
        final verses = book.chapters[c];
        for (var v = 0; v < verses.length; v++) {
          final text = verses[v];
          if (text.toLowerCase().contains(q)) {
            hits.add(BibleSearchHit(
              bookIndex: bi,
              bookName: book.name,
              chapter: c + 1,
              verse: v + 1,
              text: text,
            ));
            if (hits.length >= limit) return hits;
          }
        }
      }
    }
    return hits;
  }
}
