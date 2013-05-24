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

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import <sys/types.h>
#import <sys/stat.h>
#import <unistd.h>
#import <CommonCrypto/CommonDigest.h>

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
#import "UIImageView+AFNetworking.h"

@interface AFImageCache : NSCache
- (UIImage *)cachedImageForRequest:(NSURLRequest *)request;
- (void)cacheImage:(UIImage *)image
        forRequest:(NSURLRequest *)request;
@end

#pragma mark -

static char kAFImageRequestOperationObjectKey;

@interface UIImageView (_AFNetworking)
@property (readwrite, nonatomic, strong, setter = af_setImageRequestOperation:) AFImageRequestOperation *af_imageRequestOperation;
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
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _af_imageRequestOperationQueue = [[NSOperationQueue alloc] init];
        [_af_imageRequestOperationQueue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];
    });

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
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];

    [self setImageWithURLRequest:request placeholderImage:placeholderImage success:nil failure:nil];
}

- (void)setImageWithURLRequest:(NSURLRequest *)urlRequest
              placeholderImage:(UIImage *)placeholderImage
                       success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image))success
                       failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error))failure
{
    [self cancelImageRequestOperation];

    UIImage *cachedImage = [[[self class] af_sharedImageCache] cachedImageForRequest:urlRequest];
    if (cachedImage) {
        if (success) {
            success(nil, nil, cachedImage);
        } else {
            self.image = cachedImage;
        }

        self.af_imageRequestOperation = nil;
    } else {
        self.image = placeholderImage;

        AFImageRequestOperation *requestOperation = [[AFImageRequestOperation alloc] initWithRequest:urlRequest];
        [requestOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
            if ([urlRequest isEqual:[self.af_imageRequestOperation request]]) {
                if (success) {
                    success(operation.request, operation.response, responseObject);
                } else if (responseObject) {
                    self.image = responseObject;
                }

                if (self.af_imageRequestOperation == operation) {
                    self.af_imageRequestOperation = nil;
                }
            }

            [[[self class] af_sharedImageCache] cacheImage:responseObject forRequest:urlRequest];
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            if ([urlRequest isEqual:[self.af_imageRequestOperation request]]) {
                if (failure) {
                    failure(operation.request, operation.response, error);
                }

                if (self.af_imageRequestOperation == operation) {
                    self.af_imageRequestOperation = nil;
                }
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


NSString * const kImagesCacheDirectory = @"images";
const time_t kAllowedDeltaTimeForLastAccessedTime = 7 * 24 * 3600; // a week
const int kCacheClearingFrequency = 1000; // one per a thousand of requests

@interface AFImageCache ()

- (UIImage *)cachedImageForUrl:(NSURL *)url;
- (NSString *)cachePathForImageUrl:(NSURL *)url;
- (NSString *)cachePathForImages;
- (NSString *)md5OfString:(NSString *)str;

@end;


@implementation AFImageCache

- (UIImage *)cachedImageForRequest:(NSURLRequest *)request
{
    switch ([request cachePolicy])
    {
        case NSURLRequestReloadIgnoringCacheData:
        case NSURLRequestReloadIgnoringLocalAndRemoteCacheData:
            return nil;
        default:
            break;
    }

	UIImage *ret = [self objectForKey:AFImageCacheKeyFromURLRequest(request)];
    if (nil == ret)
    {
        ret = [self cachedImageForUrl:request.URL];
    }
    return ret;
}

- (void)cacheImage:(UIImage *)image forRequest:(NSURLRequest *)request
{
    if (image && request)
    {
        [self setObject:image forKey:AFImageCacheKeyFromURLRequest(request)];
        [self cacheImage:image forUrl:request.URL];
    }
}

#pragma mark - Private function

- (void)cacheImage:(UIImage *)image forUrl:(NSURL *)url
{
    NSString *path = [self cachePathForImageUrl:url];
    if (NO == [[NSFileManager defaultManager] fileExistsAtPath:path])
    {
        NSData *imageData = UIImageJPEGRepresentation(image, 1.0);
        [imageData writeToFile:path atomically:YES];
    }
}

- (UIImage *)cachedImageForUrl:(NSURL *)url
{
    NSString *path = [self cachePathForImageUrl:url];
    if (YES == [[NSFileManager defaultManager] fileExistsAtPath:path])
    {
        return [UIImage imageWithContentsOfFile:path];
    }
    return nil;
}

- (NSString *)cachePathForImageUrl:(NSURL *)url
{
    NSString *cachePath = [self cachePathForImages];
    NSString *fileName = [url absoluteString];
    
    return [cachePath stringByAppendingPathComponent:[self md5OfString:fileName]];
}

- (NSString *)cachePathForImages
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:kImagesCacheDirectory];
    
    if (NO == [[NSFileManager defaultManager] fileExistsAtPath:cachePath])
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:cachePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    // cache clearing
    int rnd = rand() % kCacheClearingFrequency;
    if (0 == rnd)
    {
        NSArray *cachedImages = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:cachePath error:nil];
        
        for (NSString *image in cachedImages)
        {
            NSString *imageFullPath = [cachePath stringByAppendingPathComponent:image];
            
            struct stat output;
            stat([imageFullPath fileSystemRepresentation], &output);
            
            __darwin_time_t accessTime = output.st_atime;
            time_t unixTime = (time_t)[[NSDate date] timeIntervalSince1970];
            time_t delta = unixTime - accessTime;
            
            if ( delta > kAllowedDeltaTimeForLastAccessedTime)
            {
                [[NSFileManager defaultManager] removeItemAtPath:imageFullPath error:nil];
            }
        }
        
    }
    
    return cachePath;
}

- (NSString *)md5OfString:(NSString *)str
{
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

@end

#endif
