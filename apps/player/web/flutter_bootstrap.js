{{flutter_js}}
{{flutter_build_config}}

// Updates use fingerprinted entrypoints instead of an offline app-shell cache.
const releaseAssetBase = "__NEURONOVA_ASSET_BASE__";
_flutter.loader.load({
  config: releaseAssetBase.startsWith("__") ? {} : { assetBase: releaseAssetBase }
});
