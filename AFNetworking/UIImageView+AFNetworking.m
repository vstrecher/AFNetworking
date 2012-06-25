// UIImageView+AFNetworking.m
//
// Copyright (c) 2011 Gowalla (http://gowalla.com/)
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <objc/runtime.h>
#import <CommonCrypto/CommonDigest.h>

#if __IPHONE_OS_VERSION_MIN_REQUIRED
#import "UIImageView+AFNetworking.h"
#import "UIImage+Resize.h"

@interface AFImageCache : NSCache
- (UIImage *)cachedImageForRequest:(NSURLRequest *)request;
- (void)cacheImage:(UIImage *)image
        forRequest:(NSURLRequest *)request;
@end

#pragma mark -

static char kAFImageRequestOperationObjectKey;

@interface UIImageView (_AFNetworking)
@property (readwrite, nonatomic, retain, setter = af_setImageRequestOperation:) AFImageRequestOperation *af_imageRequestOperation;
@end

@implementation UIImageView (_AFNetworking)
@dynamic af_imageRequestOperation;
@end

#pragma mark -

@implementation UIImageView (AFNetworking)

- (AFHTTPRequestOperation *)af_imageRequestOperation {
    return (AFHTTPRequestOperation *)objc_getAssociatedObject(self, &kAFImageRequestOperationObjectKey);
}

- (void)af_setImageRequestOperation:(AFImageRequestOperation *)imageRequestOperation {
    objc_setAssociatedObject(self, &kAFImageRequestOperationObjectKey, imageRequestOperation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (NSOperationQueue *)af_sharedImageRequestOperationQueue {
    static NSOperationQueue *_af_imageRequestOperationQueue = nil;

    if (!_af_imageRequestOperationQueue) {
        _af_imageRequestOperationQueue = [[NSOperationQueue alloc] init];
        [_af_imageRequestOperationQueue setMaxConcurrentOperationCount:8];
    }

    return _af_imageRequestOperationQueue;
}

+ (AFImageCache *)af_sharedImageCache {
    static AFImageCache *_af_imageCache = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _af_imageCache = [[AFImageCache alloc] init];
    });

    return _af_imageCache;
}

#pragma mark -

- (void)setImageWithURL:(NSURL *)url {
    [self setImageWithURL:url placeholderImage:nil];
}

- (void)setImageWithURL:(NSURL *)url
       placeholderImage:(UIImage *)placeholderImage
{
    [self setImageWithURL:url placeholderImage:placeholderImage resizeTo:CGSizeZero];
}

- (void)setImageWithURL:(NSURL *)url placeholderImage:(UIImage *)placeholderImage resizeTo:(CGSize)newSize {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];
//    [request setHTTPShouldHandleCookies:NO];
//    [request setHTTPShouldUsePipelining:YES];

    [self setImageWithURLRequest:request placeholderImage:placeholderImage success:nil failure:nil resizeTo:newSize];
}

- (void)setImageWithURL:(NSURL *)url
       placeholderImage:(UIImage *)placeholderImage
                success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image))success
                failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error))failure
               resizeTo:(CGSize)newSize
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];
//    [request setHTTPShouldHandleCookies:NO];
//    [request setHTTPShouldUsePipelining:YES];

    [self setImageWithURLRequest:request placeholderImage:placeholderImage success:success failure:failure resizeTo:newSize];
}

- (void)setImageWithURLRequest:(NSURLRequest *)urlRequest
              placeholderImage:(UIImage *)placeholderImage
                       success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image))success
                       failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error))failure
{
    [self setImageWithURLRequest:urlRequest placeholderImage:placeholderImage success:success failure:failure resizeTo:CGSizeZero];
}

- (void)setImageWithURLRequest:(NSURLRequest *)urlRequest
              placeholderImage:(UIImage *)placeholderImage
                       success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image))success
                       failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error))failure
                      resizeTo:(CGSize)newSize
{
    [self cancelImageRequestOperation];

    UIImage *cachedImage = [[[self class] af_sharedImageCache] cachedImageForRequest:urlRequest];
    if (cachedImage) {
        UIImage *imageToSet = cachedImage;
        if ( !CGSizeEqualToSize(newSize, CGSizeZero) ) {
            UIImage *smallerImage = [imageToSet resizedImageWithContentMode:UIViewContentModeScaleAspectFit bounds:newSize interpolationQuality:kCGInterpolationMedium];
            imageToSet = smallerImage;
        }
        self.image = imageToSet;
        self.af_imageRequestOperation = nil;

        if (success) {
            success(nil, nil, imageToSet);
        }
    } else {
        UIViewContentMode oldContentMode = self.contentMode;
        self.contentMode = UIViewContentModeCenter;
        self.image = placeholderImage;

        AFImageRequestOperation *requestOperation = [[[AFImageRequestOperation alloc] initWithRequest:urlRequest] autorelease];
        [requestOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
            NSInteger iPadVersion = [[[NSUserDefaults standardUserDefaults] objectForKey:@"ipad-version"] integerValue];

            if ( iPadVersion == 1 ) {
                UIImage *responseImage = responseObject;
                UIImage *smallerImage = [responseImage resizedImageWithContentMode:UIViewContentModeScaleAspectFit bounds:CGSizeMake(floorf(responseImage.size.width / 2.0), floorf(responseImage.size.height / 2.0)) interpolationQuality:kCGInterpolationMedium];
                responseObject = smallerImage;
            }

            UIImage *imageToSet = responseObject;

            if ([[urlRequest URL] isEqual:[[self.af_imageRequestOperation request] URL]]) {
                self.contentMode = oldContentMode;
                if ( !CGSizeEqualToSize(newSize, CGSizeZero) ) {
                    UIImage *smallerImage = [imageToSet resizedImageWithContentMode:UIViewContentModeScaleAspectFit bounds:newSize interpolationQuality:kCGInterpolationMedium];
                    imageToSet = smallerImage;
                }

                self.image = imageToSet;
                self.af_imageRequestOperation = nil;
            }

            if (success) {
                success(operation.request, operation.response, imageToSet);
            }

            [[[self class] af_sharedImageCache] cacheImage:responseObject forRequest:urlRequest];


        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            if ([[urlRequest URL] isEqual:[[self.af_imageRequestOperation request] URL]]) {
                self.af_imageRequestOperation = nil;
            }

            if (failure) {
                failure(operation.request, operation.response, error);
            }

        }];

        self.af_imageRequestOperation = requestOperation;

        [[[self class] af_sharedImageRequestOperationQueue] addOperation:self.af_imageRequestOperation];
    }
}

- (void)cancelImageRequestOperation {
    [self.af_imageRequestOperation cancel];
    self.af_imageRequestOperation = nil;
}

@end

#pragma mark -

static inline NSString * AFImageCacheKeyFromURLRequest(NSURLRequest *request) {
    return [[request URL] absoluteString];
}

@implementation AFImageCache

- (NSString*)md5OfString:(NSString*)str {
	const char *cStr = [str UTF8String];
	unsigned char result[CC_MD5_DIGEST_LENGTH];
	CC_MD5( cStr, strlen(cStr), result ); // actually CC_MD5 is available for the deployment target (4.0), but not documented
	return [NSString stringWithFormat:
				@"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
				result[0], result[1], result[2], result[3],
				result[4], result[5], result[6], result[7],
				result[8], result[9], result[10], result[11],
				result[12], result[13], result[14], result[15]
			];
}

- (BOOL)pathExists:(NSString *)path {
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

- (UIImage *)cachedImageForRequest:(NSURLRequest *)request {
    switch ([request cachePolicy]) {
        case NSURLRequestReloadIgnoringCacheData:
        case NSURLRequestReloadIgnoringLocalAndRemoteCacheData:
            return nil;
        default:
            break;
    }

    NSString *const path = [self cachePathForImageUrl:request.URL];
    BOOL foundInCache = [self pathExists:path];
    if ( foundInCache ) {
        if ( ! [self objectForKey:AFImageCacheKeyFromURLRequest(request)] ) {
            NSData *imageData = [NSData dataWithContentsOfFile:path];
            [self setObject:[UIImage imageWithData:imageData] forKey:AFImageCacheKeyFromURLRequest(request)];
        }
    }

	return [self objectForKey:AFImageCacheKeyFromURLRequest(request)];
}

- (NSString*)cachePathForImageUrl:(NSURL*)url {
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	NSString *cachePath = [paths objectAtIndex:0];
	NSString* filePath = [cachePath stringByAppendingPathComponent:[self md5OfString:[url absoluteString]]];

	return filePath;
}

- (void)cacheImage:(UIImage *)image
        forRequest:(NSURLRequest *)request
{
    if (image && request) {
        NSString *const path = [self cachePathForImageUrl:request.URL];
        BOOL foundInCache = [self pathExists:path];

        if ( ! foundInCache ) {
            NSData *imageData = UIImageJPEGRepresentation(image, 1.0);
            [imageData writeToFile:[self cachePathForImageUrl:request.URL] atomically:YES];

            [self setObject:image forKey:AFImageCacheKeyFromURLRequest(request)];
        }
    }
}

@end

#endif
