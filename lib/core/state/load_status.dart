/// Where a screen's server data stands. One shared enum, so every loaded
/// screen and its loading/error UI speak the same states.
enum LoadStatus { loading, ready, failure }
