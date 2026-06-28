import 'package:dio/dio.dart';

import 'api_client.dart';
import 'models.dart';

bool _ok(Response r) => r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300;

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Future<void> register(String email, String password) async {
    final res = await _api.dio.post('/auth/register',
        data: {'email': email, 'password': password});
    if (!_ok(res)) throw ApiException.fromResponse(res);
    await _api.saveToken(res.data['access_token'] as String);
  }

  Future<void> login(String email, String password) async {
    final res = await _api.dio
        .post('/auth/login', data: {'email': email, 'password': password});
    if (!_ok(res)) throw ApiException.fromResponse(res);
    await _api.saveToken(res.data['access_token'] as String);
  }

  Future<bool> hasValidSession() async {
    if (await _api.readToken() == null) return false;
    final res = await _api.dio.get('/auth/me');
    return _ok(res);
  }

  Future<void> logout() => _api.clearToken();
}

class ItemFilters {
  final String? q;
  final String? kind;
  final String? format;
  final String? condition;
  final int? platformId;
  final String? source;
  final bool? onLoan;
  const ItemFilters(
      {this.q, this.kind, this.format, this.condition, this.platformId, this.source, this.onLoan});

  Map<String, dynamic> toQuery() => {
        if (q != null && q!.isNotEmpty) 'q': q,
        if (kind != null) 'kind': kind,
        if (format != null) 'format': format,
        if (condition != null) 'condition': condition,
        if (platformId != null) 'platform_id': platformId,
        if (source != null) 'source': source,
        if (onLoan != null) 'on_loan': onLoan,
      };
}

class ItemsRepository {
  ItemsRepository(this._api);
  final ApiClient _api;

  Future<List<Item>> list(ItemFilters filters) async {
    final res = await _api.dio.get('/items', queryParameters: filters.toQuery());
    if (!_ok(res)) throw ApiException.fromResponse(res);
    return (res.data['items'] as List)
        .map((e) => Item.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Item> get(int id) async {
    final res = await _api.dio.get('/items/$id');
    if (!_ok(res)) throw ApiException.fromResponse(res);
    return Item.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Item> create(Map<String, dynamic> body) async {
    final res = await _api.dio.post('/items', data: body);
    if (!_ok(res)) throw ApiException.fromResponse(res);
    return Item.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Item> update(int id, Map<String, dynamic> body) async {
    final res = await _api.dio.patch('/items/$id', data: body);
    if (!_ok(res)) throw ApiException.fromResponse(res);
    return Item.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    final res = await _api.dio.delete('/items/$id');
    if (!_ok(res)) throw ApiException.fromResponse(res);
  }

  Future<List<Platform>> platforms() async {
    final res = await _api.dio.get('/platforms');
    if (!_ok(res)) throw ApiException.fromResponse(res);
    return (res.data as List)
        .map((e) => Platform.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Photo> uploadPhoto(int itemId, List<int> bytes, String filename, String contentType) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes,
          filename: filename, contentType: DioMediaType.parse(contentType)),
    });
    final res = await _api.dio.post('/items/$itemId/photos', data: form);
    if (!_ok(res)) throw ApiException.fromResponse(res);
    return Photo.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deletePhoto(int itemId, int photoId) async {
    final res = await _api.dio.delete('/items/$itemId/photos/$photoId');
    if (!_ok(res)) throw ApiException.fromResponse(res);
  }

  Future<Loan> lend(int itemId, Map<String, dynamic> body) async {
    final res = await _api.dio.post('/items/$itemId/loans', data: body);
    if (!_ok(res)) throw ApiException.fromResponse(res);
    return Loan.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Loan> returnLoan(int loanId, String returnedOn) async {
    final res = await _api.dio
        .post('/loans/$loanId/return', data: {'returned_on': returnedOn});
    if (!_ok(res)) throw ApiException.fromResponse(res);
    return Loan.fromJson(res.data as Map<String, dynamic>);
  }
}

class ScanRepository {
  ScanRepository(this._api);
  final ApiClient _api;

  Future<List<GameCandidate>> scan(String barcode) async {
    final res = await _api.dio.post('/scan', data: {'barcode': barcode});
    if (!_ok(res)) throw ApiException.fromResponse(res);
    return (res.data['candidates'] as List)
        .map((e) => GameCandidate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<GameCandidate>> search(String query) async {
    final res = await _api.dio
        .get('/metadata/search', queryParameters: {'q': query});
    if (!_ok(res)) throw ApiException.fromResponse(res);
    return (res.data['candidates'] as List)
        .map((e) => GameCandidate.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class ImportsRepository {
  ImportsRepository(this._api);
  final ApiClient _api;

  Future<ImportResult> steam(String steamId) async {
    final res = await _api.dio
        .post('/imports/steam', data: {'steam_id': steamId, 'save_connection': true});
    if (!_ok(res)) throw ApiException.fromResponse(res);
    return ImportResult.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ImportResult> csv({
    required String csvText,
    required String titleColumn,
    String? platformColumn,
    String? appIdColumn,
    String source = 'csv',
    String defaultFormat = 'digital',
  }) async {
    final res = await _api.dio.post('/imports/csv', data: {
      'csv_text': csvText,
      'mapping': {
        'title': titleColumn,
        if (platformColumn != null && platformColumn.isNotEmpty) 'platform': platformColumn,
        if (appIdColumn != null && appIdColumn.isNotEmpty) 'store_app_id': appIdColumn,
      },
      'source': source,
      'default_format': defaultFormat,
    });
    if (!_ok(res)) throw ApiException.fromResponse(res);
    return ImportResult.fromJson(res.data as Map<String, dynamic>);
  }
}
