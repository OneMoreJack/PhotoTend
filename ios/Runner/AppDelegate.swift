import AVFoundation
import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let permissionsChannelName = "rephoto/mobile_permissions"
  private let mediaChannelName = "rephoto/mobile_media"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let permissionsChannel = FlutterMethodChannel(
        name: permissionsChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      permissionsChannel.setMethodCallHandler { call, result in
        switch call.method {
        case "requestMediaReadPermission":
          self.requestMediaReadPermission(result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      let mediaChannel = FlutterMethodChannel(
        name: mediaChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      mediaChannel.setMethodCallHandler { call, result in
        switch call.method {
        case "fetchAllMediaItems":
          result(self.fetchAllMediaItems())
        case "fetchAllIds":
          result(self.fetchAllMediaIds())
        case "permanentDelete":
          self.permanentDelete(call: call, result: result)
        case "getDeviceModel":
          result(nil)
        case "batchGetDeviceModels":
          result([String: String?]())
        case "fetchPreviewImageData":
          guard let args = call.arguments as? [String: Any],
                let pathOrUri = args["pathOrUri"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "pathOrUri missing", details: nil))
            return
          }
          self.fetchPreviewImageData(pathOrUri: pathOrUri, result: result)
        case "resolvePlayableMediaUri":
          guard let args = call.arguments as? [String: Any],
                let pathOrUri = args["pathOrUri"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "pathOrUri missing", details: nil))
            return
          }
          self.resolvePlayableMediaUri(pathOrUri: pathOrUri, result: result)
        case "openInGallery":
          guard let args = call.arguments as? [String: Any],
                let pathOrUri = args["pathOrUri"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "pathOrUri missing", details: nil))
            return
          }
          self.openInGallery(pathOrUri: pathOrUri, result: result)
        case "shareToTarget":
          guard let args = call.arguments as? [String: Any],
                let pathOrUri = args["pathOrUri"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "pathOrUri missing", details: nil))
            return
          }
          self.openInGallery(pathOrUri: pathOrUri, result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func requestMediaReadPermission(result: @escaping FlutterResult) {
    let handler: (PHAuthorizationStatus) -> Void = { status in
      DispatchQueue.main.async {
        switch status {
        case .authorized:
          result("granted")
        case .limited:
          result("limited")
        default:
          result("denied")
        }
      }
    }

    if #available(iOS 14, *) {
      PHPhotoLibrary.requestAuthorization(for: .readWrite, handler: handler)
    } else {
      PHPhotoLibrary.requestAuthorization(handler)
    }
  }

  private func fetchAllMediaIds() -> [String] {
    return fetchAllMediaItems().compactMap { item in
      item["id"] as? String
    }
  }

  private func fetchAllMediaItems() -> [[String: Any?]] {
    let assets = PHAsset.fetchAssets(with: nil)
    var items: [[String: Any?]] = []
    assets.enumerateObjects { asset, _, _ in
      let mediaType = asset.mediaType == .video ? "video" : "photo"
      let createdAtMillis = asset.creationDate.map { Int64($0.timeIntervalSince1970 * 1000.0) }
      let locationKey = self.buildLocationKey(asset: asset)
      let sizeBytes = self.fileSizeBytes(asset: asset)
      let livePhotoVideoUri = self.livePhotoVideoUri(asset: asset)
      items.append(
        [
          "id": asset.localIdentifier,
          "type": mediaType,
          "createdAtMillis": createdAtMillis,
          "locationKey": locationKey,
          "pathOrUri": "phasset://\(asset.localIdentifier)",
          "sizeBytes": sizeBytes,
          "size": sizeBytes,
          "livePhotoVideoUri": livePhotoVideoUri,
        ]
      )
    }
    return items
  }

  private func fileSizeBytes(asset: PHAsset) -> Int64? {
    let resources = PHAssetResource.assetResources(for: asset)
    var total: Int64 = 0
    var found = false
    for resource in resources {
      if let value = resource.value(forKey: "fileSize") as? Int64 {
        total += value
        found = true
      } else if let value = resource.value(forKey: "fileSize") as? Int {
        total += Int64(value)
        found = true
      }
    }
    return found ? total : nil
  }

  private func permanentDelete(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let ids = arguments["ids"] as? [String]
    else {
      result(nil)
      return
    }

    let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
    PHPhotoLibrary.shared().performChanges({
      PHAssetChangeRequest.deleteAssets(assets)
    }, completionHandler: { _, error in
      DispatchQueue.main.async {
        if let error = error {
          result(
            FlutterError(
              code: "delete_error",
              message: error.localizedDescription,
              details: nil
            )
          )
        } else {
          result(nil)
        }
      }
    })
  }

  private func openInGallery(pathOrUri: String, result: @escaping FlutterResult) {
    var activityItems: [Any] = []
    if pathOrUri.hasPrefix("phasset://") {
      let localId = String(pathOrUri.dropFirst("phasset://".count))
      let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)
      if let asset = assets.firstObject {
        activityItems.append(asset)
      }
    } else if let url = URL(string: pathOrUri) {
      activityItems.append(url)
    }
    guard !activityItems.isEmpty else {
      result(FlutterError(code: "NOT_FOUND", message: "Could not resolve asset", details: nil))
      return
    }
    DispatchQueue.main.async {
      let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
      self.window?.rootViewController?.present(vc, animated: true)
      result(nil)
    }
  }

  private func fetchPreviewImageData(pathOrUri: String, result: @escaping FlutterResult) {
    guard pathOrUri.hasPrefix("phasset://") else {
      result(nil)
      return
    }

    guard let asset = assetFor(pathOrUri: pathOrUri) else {
      result(nil)
      return
    }

    if asset.mediaType == .video {
      fetchVideoPreviewImageData(asset: asset, result: result)
      return
    }

    let options = PHImageRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.resizeMode = .fast
    options.isNetworkAccessAllowed = true
    options.isSynchronous = false

    let targetSize = CGSize(width: 1600, height: 1600)
    PHImageManager.default().requestImage(
      for: asset,
      targetSize: targetSize,
      contentMode: .aspectFit,
      options: options
    ) { image, _ in
      guard let image,
            let data = image.jpegData(compressionQuality: 0.9) else {
        result(nil)
        return
      }
      result(FlutterStandardTypedData(bytes: data))
    }
  }

  private func resolvePlayableMediaUri(pathOrUri: String, result: @escaping FlutterResult) {
    if pathOrUri.hasPrefix("phlive://") {
      guard let asset = assetForLivePhotoVideoUri(pathOrUri: pathOrUri) else {
        result(nil)
        return
      }
      exportLivePhotoPairedVideo(asset: asset, result: result)
      return
    }

    guard pathOrUri.hasPrefix("phasset://") else {
      result(pathOrUri)
      return
    }

    guard let asset = assetFor(pathOrUri: pathOrUri) else {
      result(nil)
      return
    }

    let options = PHVideoRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.isNetworkAccessAllowed = true
    PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
      if let urlAsset = avAsset as? AVURLAsset {
        result(urlAsset.url.absoluteString)
        return
      }

      guard let avAsset else {
        result(nil)
        return
      }

      self.exportVideoAssetToTemporaryFile(avAsset: avAsset, localId: asset.localIdentifier, result: result)
    }
  }

  private func assetFor(pathOrUri: String) -> PHAsset? {
    guard pathOrUri.hasPrefix("phasset://") else {
      return nil
    }
    let localId = String(pathOrUri.dropFirst("phasset://".count))
    let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)
    return assets.firstObject
  }

  private func assetForLivePhotoVideoUri(pathOrUri: String) -> PHAsset? {
    guard pathOrUri.hasPrefix("phlive://") else {
      return nil
    }
    let localId = String(pathOrUri.dropFirst("phlive://".count))
    let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)
    return assets.firstObject
  }

  private func livePhotoVideoUri(asset: PHAsset) -> String? {
    guard asset.mediaType == .image,
          asset.mediaSubtypes.contains(.photoLive) else {
      return nil
    }
    let resources = PHAssetResource.assetResources(for: asset)
    guard resources.contains(where: { $0.type == .pairedVideo }) else {
      return nil
    }
    return "phlive://\(asset.localIdentifier)"
  }

  private func exportLivePhotoPairedVideo(asset: PHAsset, result: @escaping FlutterResult) {
    let resources = PHAssetResource.assetResources(for: asset)
    guard let pairedVideo = resources.first(where: { $0.type == .pairedVideo }) else {
      result(nil)
      return
    }
    let sanitizedId = asset.localIdentifier.replacingOccurrences(of: "/", with: "_")
    let outputUrl = FileManager.default.temporaryDirectory
      .appendingPathComponent("rephoto_live_\(sanitizedId)_\(UUID().uuidString).mov")
    try? FileManager.default.removeItem(at: outputUrl)

    let options = PHAssetResourceRequestOptions()
    options.isNetworkAccessAllowed = true
    PHAssetResourceManager.default().writeData(for: pairedVideo, toFile: outputUrl, options: options) { error in
      if error != nil {
        result(nil)
      } else {
        result(outputUrl.absoluteString)
      }
    }
  }

  private func fetchVideoPreviewImageData(asset: PHAsset, result: @escaping FlutterResult) {
    let options = PHVideoRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.isNetworkAccessAllowed = true
    PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
      guard let avAsset else {
        result(nil)
        return
      }

      let generator = AVAssetImageGenerator(asset: avAsset)
      generator.appliesPreferredTrackTransform = true
      generator.maximumSize = CGSize(width: 1600, height: 1600)

      do {
        let cgImage = try generator.copyCGImage(at: CMTime(seconds: 0, preferredTimescale: 600), actualTime: nil)
        let image = UIImage(cgImage: cgImage)
        guard let data = image.jpegData(compressionQuality: 0.85) else {
          result(nil)
          return
        }
        result(FlutterStandardTypedData(bytes: data))
      } catch {
        result(nil)
      }
    }
  }

  private func exportVideoAssetToTemporaryFile(
    avAsset: AVAsset,
    localId: String,
    result: @escaping FlutterResult
  ) {
    guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetHighestQuality) else {
      result(nil)
      return
    }

    let sanitizedId = localId.replacingOccurrences(of: "/", with: "_")
    let outputUrl = FileManager.default.temporaryDirectory
      .appendingPathComponent("rephoto_\(sanitizedId)_\(UUID().uuidString).mp4")

    try? FileManager.default.removeItem(at: outputUrl)

    exportSession.outputURL = outputUrl
    exportSession.outputFileType = .mp4
    exportSession.shouldOptimizeForNetworkUse = false

    exportSession.exportAsynchronously {
      switch exportSession.status {
      case .completed:
        result(outputUrl.absoluteString)
      default:
        result(nil)
      }
    }
  }

  private func buildLocationKey(asset: PHAsset) -> String? {
    guard let location = asset.location else {
      return nil
    }
    let lat = String(format: "%.3f", location.coordinate.latitude)
    let lon = String(format: "%.3f", location.coordinate.longitude)
    return "geo/\(lat)/\(lon)"
  }
}
