/// API online palsu untuk tes SearchService dan tes widget pencarian.
/// Tanpa jaringan: hasil dan error dikendalikan tes.
library;

import 'package:laras/extractor/extractor.dart';
import 'package:laras/features/search/search_service.dart';

const ExtractorException networkError = ExtractorException(
  ResolveFailureCause.emptyResponse,
  isNetworkError: true,
  detail: 'timeout (tes)',
);

const ExtractorException parseError = ExtractorException(
  ResolveFailureCause.parseFailed,
  detail: 'bentuk berubah (tes)',
);

class FakeOnlineApi implements OnlineSearchApi {
  FakeOnlineApi({
    this.results = const GroupedSearchResults(),
    this.suggestions = const <String>[],
    this.browsePage,
    this.searchError,
    this.suggestError,
    this.browseError,
    this.searchThrow,
    this.browseThrow,
  });

  GroupedSearchResults results;
  List<String> suggestions;
  BrowsePage? browsePage;
  ExtractorException? searchError;
  ExtractorException? suggestError;
  ExtractorException? browseError;

  /// Error BUKAN ExtractorException yang dilempar search/browse (R2-L1:
  /// mis. StateError dari database atau bug tak terduga di API).
  Object? searchThrow;
  Object? browseThrow;

  int searchCalls = 0;
  int suggestCalls = 0;
  int browseCalls = 0;
  String? lastSearchParams;
  String? lastBrowseId;

  @override
  Future<GroupedSearchResults> search(String query, {String? params}) async {
    searchCalls++;
    lastSearchParams = params;
    if (searchThrow != null) throw searchThrow!;
    if (searchError != null) throw searchError!;
    return results;
  }

  @override
  Future<BrowsePage> browse(String browseId, {String? params}) async {
    browseCalls++;
    lastBrowseId = browseId;
    if (browseThrow != null) throw browseThrow!;
    if (browseError != null) throw browseError!;
    return browsePage ?? const BrowsePage(title: '');
  }

  @override
  Future<List<String>> suggest(String input) async {
    suggestCalls++;
    if (suggestError != null) throw suggestError!;
    return suggestions;
  }
}
