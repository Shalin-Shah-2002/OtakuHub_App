class SearchAnimeRequest {
  final String? keyword;
  final int? page;

  SearchAnimeRequest({this.keyword, this.page});

  Map<String, dynamic> toQueryParams() {
    final Map<String, dynamic> params = {};

    if (keyword != null && keyword!.isNotEmpty) params['keyword'] = keyword;
    if (page != null) params['page'] = page.toString();

    return params;
  }
}
