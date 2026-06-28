/// Plain data models mirroring the backend's Pydantic schemas.

class Platform {
  final int id;
  final String name;
  final int? igdbPlatformId;

  Platform({required this.id, required this.name, this.igdbPlatformId});

  factory Platform.fromJson(Map<String, dynamic> j) => Platform(
        id: j['id'] as int,
        name: j['name'] as String,
        igdbPlatformId: j['igdb_platform_id'] as int?,
      );
}

class Photo {
  final int id;
  final String url;
  final bool isPrimary;

  Photo({required this.id, required this.url, required this.isPrimary});

  factory Photo.fromJson(Map<String, dynamic> j) => Photo(
        id: j['id'] as int,
        url: j['url'] as String,
        isPrimary: j['is_primary'] as bool? ?? false,
      );
}

class Loan {
  final int id;
  final int itemId;
  final String borrowerName;
  final String loanedOn;
  final String? dueOn;
  final String? returnedOn;
  final String? notes;

  Loan({
    required this.id,
    required this.itemId,
    required this.borrowerName,
    required this.loanedOn,
    this.dueOn,
    this.returnedOn,
    this.notes,
  });

  bool get isOpen => returnedOn == null;

  factory Loan.fromJson(Map<String, dynamic> j) => Loan(
        id: j['id'] as int,
        itemId: j['item_id'] as int,
        borrowerName: j['borrower_name'] as String,
        loanedOn: j['loaned_on'] as String,
        dueOn: j['due_on'] as String?,
        returnedOn: j['returned_on'] as String?,
        notes: j['notes'] as String?,
      );
}

class Item {
  final int id;
  final String kind; // game | hardware | accessory
  final String format; // physical | digital | retro
  final String title;
  final int? platformId;
  final Platform? platform;
  final String? barcode;
  final String? condition;
  final String? conditionNotes;
  final int? igdbId;
  final String? coverUrl;
  final String? summary;
  final String? releaseDate;
  final List<String>? genres;
  final String? acquiredDate;
  final String? pricePaid;
  final String? storageLocation;
  final String? notes;
  final String source;
  final List<Photo> photos;
  final List<Loan> loans;

  Item({
    required this.id,
    required this.kind,
    required this.format,
    required this.title,
    this.platformId,
    this.platform,
    this.barcode,
    this.condition,
    this.conditionNotes,
    this.igdbId,
    this.coverUrl,
    this.summary,
    this.releaseDate,
    this.genres,
    this.acquiredDate,
    this.pricePaid,
    this.storageLocation,
    this.notes,
    required this.source,
    this.photos = const [],
    this.loans = const [],
  });

  bool get isOnLoan => loans.any((l) => l.isOpen);
  Loan? get openLoan {
    for (final l in loans) {
      if (l.isOpen) return l;
    }
    return null;
  }

  factory Item.fromJson(Map<String, dynamic> j) => Item(
        id: j['id'] as int,
        kind: j['kind'] as String? ?? 'game',
        format: j['format'] as String? ?? 'physical',
        title: j['title'] as String,
        platformId: j['platform_id'] as int?,
        platform: j['platform'] != null
            ? Platform.fromJson(j['platform'] as Map<String, dynamic>)
            : null,
        barcode: j['barcode'] as String?,
        condition: j['condition'] as String?,
        conditionNotes: j['condition_notes'] as String?,
        igdbId: j['igdb_id'] as int?,
        coverUrl: j['cover_url'] as String?,
        summary: j['summary'] as String?,
        releaseDate: j['release_date'] as String?,
        genres: (j['genres'] as List?)?.map((e) => e.toString()).toList(),
        acquiredDate: j['acquired_date'] as String?,
        pricePaid: j['price_paid']?.toString(),
        storageLocation: j['storage_location'] as String?,
        notes: j['notes'] as String?,
        source: j['source'] as String? ?? 'manual',
        photos: (j['photos'] as List? ?? [])
            .map((e) => Photo.fromJson(e as Map<String, dynamic>))
            .toList(),
        loans: (j['loans'] as List? ?? [])
            .map((e) => Loan.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// A candidate returned by /scan or /metadata/search, shown for confirmation.
class GameCandidate {
  final String title;
  final int? igdbId;
  final String? platformName;
  final int? platformId;
  final String? coverUrl;
  final String? summary;
  final String? releaseDate;
  final List<String>? genres;
  final String source;
  final double confidence;

  GameCandidate({
    required this.title,
    this.igdbId,
    this.platformName,
    this.platformId,
    this.coverUrl,
    this.summary,
    this.releaseDate,
    this.genres,
    required this.source,
    this.confidence = 0.0,
  });

  factory GameCandidate.fromJson(Map<String, dynamic> j) => GameCandidate(
        title: j['title'] as String,
        igdbId: j['igdb_id'] as int?,
        platformName: j['platform_name'] as String?,
        platformId: j['platform_id'] as int?,
        coverUrl: j['cover_url'] as String?,
        summary: j['summary'] as String?,
        releaseDate: j['release_date'] as String?,
        genres: (j['genres'] as List?)?.map((e) => e.toString()).toList(),
        source: j['source'] as String? ?? 'igdb',
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0,
      );
}

class ImportResult {
  final String provider;
  final int fetched;
  final int created;
  final int skippedDuplicates;
  final List<String> unmatched;

  ImportResult({
    required this.provider,
    required this.fetched,
    required this.created,
    required this.skippedDuplicates,
    required this.unmatched,
  });

  factory ImportResult.fromJson(Map<String, dynamic> j) => ImportResult(
        provider: j['provider'] as String,
        fetched: j['fetched'] as int,
        created: j['created'] as int,
        skippedDuplicates: j['skipped_duplicates'] as int,
        unmatched:
            (j['unmatched'] as List? ?? []).map((e) => e.toString()).toList(),
      );
}
