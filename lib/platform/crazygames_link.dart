/// Accepts [raw] as a share link only when it is an `https` URL on a
/// CrazyGames host (crazygames.com and its country domains or subdomains)
/// without port or user info, so a copied result never points off-portal
/// (adr-share-link-per-flavor). Imported only by the CrazyGames adapter.
String? crazyGamesLinkOrNull(String? raw) {
  if (raw == null) return null;
  final uri = Uri.tryParse(raw.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.hasPort ||
      uri.userInfo.isNotEmpty ||
      uri.host.isEmpty) {
    return null;
  }
  final host = uri.host.toLowerCase();
  final ok = RegExp(
    r'^([a-z0-9-]+\.)*crazygames\.(com|[a-z]{2}|co\.[a-z]{2}|com\.[a-z]{2})$',
  ).hasMatch(host);
  return ok ? uri.toString() : null;
}
