import Combine
import NetworkImage
import SwiftUI
import UIKit

/// A type that encapsulates the image loading behavior of a ``Markdown`` view for a given URL scheme.
///
/// To configure an image handler for a `Markdown` view, use the ``Markdown/setImageHandler(_:forURLScheme:)``
/// modifier. The following example configures an asset image handler for the `asset://` URL scheme.
///
/// ```swift
/// Markdown(
///   #"""
///   ![](asset:///Puppy)
///
///   ― Photo by André Spieker
///   """#
/// )
/// .setImageHandler(.assetImage(), forURLScheme: "asset")
/// ```
///
public struct MarkdownImageHandler {
  var imageAttachment: (URL) -> AnyPublisher<NSTextAttachment, Never>

  init(imageAttachment: @escaping (URL) -> AnyPublisher<NSTextAttachment, Never>) {
    self.imageAttachment = imageAttachment
  }
}

extension MarkdownImageHandler {
  /// A `MarkdownImageHandler` instance that loads images from the network.
  ///
  /// `Markdown` views use this image handler for the `http://` and `https://`
  /// schemes by default.
  public static let networkImage = MarkdownImageHandler { url in
    NetworkImageLoader.shared.image(for: url)
      .map { image in
        let attachment = ResizableImageAttachment()
          attachment.image = image.scalePreservingAspectRatio(targetSize: CGSize(width: 512, height: 512))
          attachment.image = image.with(UIEdgeInsets(top: 0, left: CGFloat(UIScreen.main.bounds.width) / 2, bottom: 0, right: CGFloat(UIScreen.main.bounds.width) / 2))
        return attachment
      }
      .replaceError(with: NSTextAttachment())
      .eraseToAnyPublisher()
  }

  /// A `MarkdownImageHandler` instance that loads images from resource files or asset catalogs.
  /// - Parameters:
  ///   - name: A closure that extracts the asset name from a given URL. If not specified, the image handler
  ///           uses the last path component of the URL as the name of the asset.
  ///   - bundle: The bundle to search for the image file or asset catalog. Specify `nil` to search the
  ///             app's main bundle.
  public static func assetImage(
    name: @escaping (URL) -> String = \.lastPathComponent,
    in bundle: Bundle? = nil
  ) -> MarkdownImageHandler {
    MarkdownImageHandler { url in
      let image: PlatformImage?
      #if os(macOS)
        if let bundle = bundle, bundle != .main {
          image = bundle.image(forResource: name(url))
        } else {
          image = NSImage(named: name(url))
        }
      #elseif os(iOS) || os(tvOS)
        image = UIImage(named: name(url), in: bundle, compatibleWith: nil)
      #endif
      let attachment = image.map { image -> NSTextAttachment in
        let result = ResizableImageAttachment()
        result.image = image
        return result
      }
      return Just(attachment ?? NSTextAttachment()).eraseToAnyPublisher()
    }
  }
}


extension UIImage {
    
    func with(_ insets: UIEdgeInsets) -> UIImage {
        let targetWidth = size.width + insets.left + insets.right
        let targetHeight = size.height + insets.top + insets.bottom
        let targetSize = CGSize(width: targetWidth, height: targetHeight)
        let targetOrigin = CGPoint(x: insets.left, y: insets.top)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: targetOrigin, size: size))
        }.withRenderingMode(renderingMode)
    }

}

extension UIImage {
    func scalePreservingAspectRatio(targetSize: CGSize) -> UIImage {
        // Determine the scale factor that preserves aspect ratio
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        
        let scaleFactor = min(widthRatio, heightRatio)
        
        // Compute the new image size that preserves aspect ratio
        let scaledImageSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )

        // Draw and return the resized UIImage
        let renderer = UIGraphicsImageRenderer(
            size: scaledImageSize
        )

        let scaledImage = renderer.image { _ in
            self.draw(in: CGRect(
                origin: .zero,
                size: scaledImageSize
            ))
        }
        
        return scaledImage
    }
}
