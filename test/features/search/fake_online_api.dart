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
  });

  GroupedSearchResults results;
  List<String> suggestions;
  BrowsePage? browsePage;
  ExtractorException? searchError;
  ExtractorException? suggestError;
  ExtractorException? browseError;

  int searchCalls = 0;
  int suggestCalls = 0;
  int browseCalls = 0;
  String? lastSearchParams;
  String? lastBrowseId;

  @override
  Future<GroupedSearchResults> search(String query, {String? params}) async {
    searchCalls++;
    lastSearchParams = params;
    if (searchError != null) throw searchError!;
    return results;
  }

  @override
  Future<BrowsePage> browse(String browseId, {String? params}) async {
    browseCalls++;
    lastBrowseId = browseId;
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
