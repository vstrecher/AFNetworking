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

#import <sys/types.h>
#import <sys/stat.h>
#import <unistd.h>
#import <objc/runtime.h>
#import <CommonCrypto/CommonDigest.h>

#if __IPHONE_OS_VERSION_MIN_REQUIRED
#import "UIImageView+AFNetworking.h"
#import "UIImage+Resize.h"
#import "UIView+FrameAccessor.h"


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

- (void)setImageWithURL:(NSURL *)url
       placeholderImage:(UIImage *)placeholderImage
               resizeTo:(CGSize)newSize
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];
//    [request setHTTPShouldHandleCookies:NO];
//    [request setHTTPShouldUsePipelining:YES];

    [self setImageWithURLRequest:request placeholderImage:placeholderImage success:nil failure:nil resizeTo:newSize];
}

- (void)setImageWithURL:(NSURL *)url
        placeholderView:(UIView *)placeholderView
               resizeTo:(CGSize)newSize
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30.0];
    [self setImageWithURLRequest:request placeholderImage:nil placeholderView:placeholderView success:nil failure:nil resizeTo:newSize];
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
    [self setImageWithURLRequest:urlRequest placeholderImage:placeholderImage placeholderView:nil success:success failure:failure resizeTo:newSize];
}

- (void)setImageWithURLRequest:(NSURLRequest *)urlRequest
              placeholderImage:(UIImage *)placeholderImage
               placeholderView:(UIView *)placeholderView
                       success:(void (^)(NSURLRequest *, NSHTTPURLResponse *, UIImage *))success
                       failure:(void (^)(NSURLRequest *, NSHTTPURLResponse *, NSError *))failure
                      resizeTo:(CGSize)newSize
{
    [self cancelImageRequestOperation];

    // removing placeholderView
    [[self viewWithTag:118] removeFromSuperview];

    // looking for not resized image in cache
    UIImage *cachedImage = [[[self class] af_sharedImageCache] cachedImageForRequest:urlRequest size:CGSizeZero];

    // looking for resized image in cache
    UIImage *resizedCachedImage = nil;
    if ( !CGSizeEqualToSize(newSize, CGSizeZero)) {
        resizedCachedImage = [[[self class] af_sharedImageCache] cachedImageForRequest:urlRequest size:newSize];
    }

    if ( resizedCachedImage ) {
        // if we have resized image to current size in cache - use it, nothing to download and cache
//        INFO(@"Found resized image: %@", urlRequest.URL);

        self.image = resizedCachedImage;
        self.af_imageRequestOperation = nil;

        if ( success ) {
            success(nil, nil, resizedCachedImage);
        }
    } else {
        // if there is no resized image to current size

        if (cachedImage) {
            // if there is original image
            // resize it and cache resized image, nothing to download
//            INFO(@"Found original image: %@", urlRequest.URL);

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

            [[[self class] af_sharedImageCache] cacheImage:imageToSet forRequest:urlRequest size:newSize];

        } else {
            // if we found nothing - download and cache both images (if newSize isn't ZeroSize)
//            INFO(@"Starting load for url: %@", urlRequest.URL);

            UIImageView *placeholderImageView = nil;
            if ( placeholderImage ) {
                self.image = nil;
                placeholderImageView = [[UIImageView alloc] initWithImage:placeholderImage];
                [placeholderImageView sizeToFit];
                [placeholderImageView setOrigin:CENTER_IN_PARENT(self, placeholderImageView.width, placeholderImageView.height)];
                [self addSubview:placeholderImageView];
                [placeholderImageView release];
            } else if ( placeholderView ) {
                self.image = nil;
                [placeholderView setOrigin:CENTER_IN_PARENT_SIZE(newSize, placeholderView.width, placeholderView.height)];
                [placeholderView setTag:118];
                [self addSubview:placeholderView];
            }

            AFImageRequestOperation *requestOperation = [[[AFImageRequestOperation alloc] initWithRequest:urlRequest] autorelease];
            [requestOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
//                INFO(@"Loading completed: %@", urlRequest.URL);
                NSInteger iPadVersion = [[[NSUserDefaults standardUserDefaults] objectForKey:@"ipad-version"] integerValue];

                if ( iPadVersion == 1 ) {
                    UIImage *responseImage = responseObject;
                    UIImage *smallerImage = [responseImage resizedImageWithContentMode:UIViewContentModeScaleAspectFit bounds:CGSizeMake(floorf(responseImage.size.width / 2.0), floorf(responseImage.size.height / 2.0)) interpolationQuality:kCGInterpolationMedium];
                    responseObject = smallerImage;
                }

                UIImage *imageToSet = responseObject;

                if ([[urlRequest URL] isEqual:[[self.af_imageRequestOperation request] URL]]) {
                    if ( !CGSizeEqualToSize(newSize, CGSizeZero) ) {
                        UIImage *smallerImage = [imageToSet resizedImageWithContentMode:UIViewContentModeScaleAspectFit bounds:newSize interpolationQuality:kCGInterpolationMedium];
                        imageToSet = smallerImage;
                    }

                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.image = imageToSet;
                        UIView *placeholderView = [self viewWithTag:118];
                        if ( placeholderView ) {
                            [UIView animateWithDuration:0.2
                                                  delay:0.0
                                                options:UIViewAnimationOptionCurveEaseIn
                                             animations:^{
                                                 [placeholderView setAlpha:0.0];
                                             } completion:^(BOOL completed) {
                                [placeholderView removeFromSuperview];
                            }];
                        }


                        if ( placeholderImageView ) {
                            [UIView animateWithDuration:0.3 animations:^{
                                [placeholderImageView setAlpha:0.0];
                            } completion:^(BOOL completed) {
                                [placeholderImageView removeFromSuperview];
                            }];
                        }
                    });

                    self.af_imageRequestOperation = nil;
                }

                if (success) {
                    success(operation.request, operation.response, imageToSet);
                }

                if ( ! CGSizeEqualToSize(newSize, CGSizeZero) ) {
                    [[[self class] af_sharedImageCache] cacheImage:responseObject forRequest:urlRequest size:CGSizeZero];
                }

                [[[self class] af_sharedImageCache] cacheImage:imageToSet forRequest:urlRequest size:newSize];


            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
//                INFO(@"Loading failed: %@", urlRequest.URL);
                if ([[urlRequest URL] isEqual:[[self.af_imageRequestOperation request] URL]]) {
                    [placeholderImageView removeFromSuperview];
                    [placeholderView removeFromSuperview];
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

static inline NSString * AFImageCacheKeyFromURLRequestAndSize(NSURLRequest *request, CGSize size) {
    return [[[request URL] absoluteString] stringByAppendingFormat:@"(%.0fx%.0f)", size.width, size.height];
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
    return [self cachedImageForRequest:request size:CGSizeZero];
}

- (UIImage *)cachedImageForRequest:(NSURLRequest *)request size:(CGSize)size {
    switch ([request cachePolicy]) {
        case NSURLRequestReloadIgnoringCacheData:
        case NSURLRequestReloadIgnoringLocalAndRemoteCacheData:
            return nil;
        default:
            break;
    }

    NSString *const path = [self cachePathForImageUrl:request.URL size:size];
    BOOL foundInCache = [self pathExists:path];
    if ( foundInCache ) {
        if ( ! [self objectForKey:AFImageCacheKeyFromURLRequestAndSize(request, size)] ) {
            NSData *imageData = [NSData dataWithContentsOfFile:path];
            [self setObject:[UIImage imageWithData:imageData] forKey:AFImageCacheKeyFromURLRequestAndSize(request, size)];
        }
    }

    return [self objectForKey:AFImageCacheKeyFromURLRequestAndSize(request, size)];
}

- (NSString*)cachePathForImageUrl:(NSURL*)url {
	return [self cachePathForImageUrl:url size:CGSizeZero];
}

- (NSString *)cachePathForImages {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:kImagesCacheDirectory];

    if ( ! [self pathExists:cachePath] ) {
        [[NSFileManager defaultManager] createDirectoryAtPath:cachePath withIntermediateDirectories:YES attributes:nil error:nil];
    }

    // cache clearing
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray *cachedImages = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:cachePath error:nil];

        for (NSString *image in cachedImages) {
            NSString *imageFullPath = [cachePath stringByAppendingPathComponent:image];

            struct stat output;
            int ret = stat([imageFullPath fileSystemRepresentation], &output);

            __darwin_time_t accessTime = output.st_atime;
            time_t unixTime = (time_t)[[NSDate date] timeIntervalSince1970];
            time_t delta = unixTime - accessTime;

            if ( delta > kAllowedDeltaTimeForLastAccessedTime) {
                [[NSFileManager defaultManager] removeItemAtPath:imageFullPath error:nil];
            }
        }

    });

    return cachePath;
}

- (NSString*)cachePathForImageUrl:(NSURL*)url size:(CGSize)size {
    NSString *cachePath = [self cachePathForImages];
    NSString *fileName;

    if ( CGSizeEqualToSize(size, CGSizeZero) ) {
        fileName = [url absoluteString];
    } else {
        fileName = [NSString stringWithFormat:@"%@(%.0fx%.0f)", [url absoluteString], size.width, size.height];
    }

    NSString* filePath = [cachePath stringByAppendingPathComponent:[self md5OfString:fileName]];

    return filePath;
}

- (void)cacheImage:(UIImage *)image
        forRequest:(NSURLRequest *)request
{
    [self cacheImage:image forRequest:request size:CGSizeZero];
}

- (void)cacheImage:(UIImage *)image
        forRequest:(NSURLRequest *)request
              size:(CGSize)size
{
    if (image && request) {
        NSString *const path = [self cachePathForImageUrl:request.URL size:size];
        BOOL foundInCache = [self pathExists:path];

        if ( ! foundInCache ) {
            NSData *imageData = UIImageJPEGRepresentation(image, 1.0);
            [imageData writeToFile:path atomically:YES];

            [self setObject:image forKey:AFImageCacheKeyFromURLRequestAndSize(request, size)];
        }
    }
}

@end

#endif
