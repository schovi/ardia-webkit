#import "../ArdiaFavicons.h"
#import "Network.h"

namespace {
NSDictionary *Favicon(NSData *data) {
  if (!data.length || data.length > 2 * 1024 * 1024) return nil;
  NSImage *image = [[NSImage alloc] initWithData:data];
  if (!image || image.size.width <= 0 || image.size.height <= 0) return nil;
  NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nullptr pixelsWide:64 pixelsHigh:64 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
  NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
  if (!context) return nil;
  [NSGraphicsContext saveGraphicsState];
  NSGraphicsContext.currentContext = context;
  context.imageInterpolation = NSImageInterpolationHigh;
  [image drawInRect:NSMakeRect(0, 0, 64, 64)];
  [NSGraphicsContext restoreGraphicsState];
  NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
  if (!png) return nil;
  return @{@"uri": [@"data:image/png;base64," stringByAppendingString:[png base64EncodedStringWithOptions:0]], @"width": @64, @"height": @64};
}
}

@implementation ArdiaFavicons
+ (void)fetch:(NSString *)url profile:(NSString *)profile name:(NSString *)name completion:(void (^)(NSDictionary<NSString *, id> *_Nullable))completion {
  if ([url hasPrefix:@"data:image/"]) {
    NSRange comma = [url rangeOfString:@","];
    if (comma.location == NSNotFound || url.length > 3 * 1024 * 1024) return completion(nil);
    NSData *data = [[NSData alloc] initWithBase64EncodedString:[url substringFromIndex:comma.location + 1] options:0];
    return completion(Favicon(data));
  }
  WebKitFetch(url, 2 * 1024 * 1024, ^(NSData *body, NSHTTPURLResponse *response, NSError *error) {
    completion(response.statusCode == 200 && !error ? Favicon(body) : nil);
  });
}
@end
