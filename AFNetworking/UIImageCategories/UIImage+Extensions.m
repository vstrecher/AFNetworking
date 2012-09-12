//
//  UIImage+Extensions.m
//  JigsawPuz
//
//  Created by Dymov Eugene on 09.11.11.
//  Copyright (c) 2011 Eugene Valeyev. All rights reserved.
//

#import "UIImage+Extensions.h"
#import "Defines.h"
#import <CommonCrypto/CommonDigest.h>

#define GET_R(color) ((color & 0x000000FF))
#define GET_G(color) ((color & 0x0000FF00) >> 8)
#define GET_B(color) ((color & 0x00FF0000) >> 16)
#define GET_A(color) ((color & 0xFF000000) >> 24)
#define COLOR_FROM_ARGB(a,r,g,b) ((a << 24) | r | (g << 8) | (b << 16))
#define CLIP(value, min, max) \
    do { \
        if (value < min) value = min; \
        if (value > max) value = max; \
    } while (0)

CGFloat DegreesToRadians(CGFloat degrees);
CGFloat RadiansToDegrees(CGFloat radians);

CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};
CGFloat RadiansToDegrees(CGFloat radians) {return radians * 180/M_PI;};

void RetinaAwareUIGraphicsBeginImageContext(CGSize size) {
    static CGFloat scale = -1.0;
    if (scale<0.0) {
        UIScreen *screen = [UIScreen mainScreen];
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 4.0) {
            scale = [screen scale];
        }
        else {
            scale = 0.0;    // mean use old api
        }
    }
    if (scale>0.0) {
        UIGraphicsBeginImageContextWithOptions(size, NO, scale);
    }
    else {
        UIGraphicsBeginImageContext(size);
    }
}


@implementation UIImage (CS_Extensions)


-(UIImage *)imageAtRect:(CGRect)rect
{

    CGImageRef imageRef = CGImageCreateWithImageInRect([self CGImage], rect);
    UIImage* subImage = [UIImage imageWithCGImage: imageRef scale:self.scale orientation:self.imageOrientation];
    CGImageRelease(imageRef);

    return subImage;

}

- (UIImage *)imageByScalingProportionallyToMinimumSize:(CGSize)targetSize {

    UIImage *sourceImage = self;
    UIImage *newImage = nil;

    CGSize imageSize = sourceImage.size;
    CGFloat width = imageSize.width;
    CGFloat height = imageSize.height;

    CGFloat targetWidth = targetSize.width;
    CGFloat targetHeight = targetSize.height;

    CGFloat scaleFactor = 0.0;
    CGFloat scaledWidth = targetWidth;
    CGFloat scaledHeight = targetHeight;

    CGPoint thumbnailPoint = CGPointMake(0.0,0.0);

    if (CGSizeEqualToSize(imageSize, targetSize) == NO) {

        CGFloat widthFactor = targetWidth / width;
        CGFloat heightFactor = targetHeight / height;

        if (widthFactor > heightFactor)
            scaleFactor = widthFactor;
        else
            scaleFactor = heightFactor;

        scaledWidth  = width * scaleFactor;
        scaledHeight = height * scaleFactor;

        // center the image

        if (widthFactor > heightFactor) {
            thumbnailPoint.y = (targetHeight - scaledHeight) * 0.5;
        } else if (widthFactor < heightFactor) {
            thumbnailPoint.x = (targetWidth - scaledWidth) * 0.5;
        }
    }


    // this is actually the interesting part:

	RetinaAwareUIGraphicsBeginImageContext(targetSize);

    CGRect thumbnailRect = CGRectZero;
    thumbnailRect.origin = thumbnailPoint;
    thumbnailRect.size.width  = scaledWidth;
    thumbnailRect.size.height = scaledHeight;

    [sourceImage drawInRect:thumbnailRect];

    newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if(newImage == nil) NSLog(@"could not scale image");


    return newImage ;
}


- (UIImage *)imageByScalingProportionallyToSize:(CGSize)targetSize {

    UIImage *sourceImage = self;
    UIImage *newImage = nil;

    CGSize imageSize = sourceImage.size;
    CGFloat width = imageSize.width;
    CGFloat height = imageSize.height;

    CGFloat targetWidth = targetSize.width;
    CGFloat targetHeight = targetSize.height;

    CGFloat scaleFactor = 0.0;
    CGFloat scaledWidth = targetWidth;
    CGFloat scaledHeight = targetHeight;

    CGPoint thumbnailPoint = CGPointMake(0.0,0.0);

    if (CGSizeEqualToSize(imageSize, targetSize) == NO) {

        CGFloat widthFactor = targetWidth / width;
        CGFloat heightFactor = targetHeight / height;

        if (widthFactor < heightFactor)
            scaleFactor = widthFactor;
        else
            scaleFactor = heightFactor;

        scaledWidth  = width * scaleFactor;
        scaledHeight = height * scaleFactor;

        // center the image

        if (widthFactor < heightFactor) {
            thumbnailPoint.y = (targetHeight - scaledHeight) * 0.5;
        } else if (widthFactor > heightFactor) {
            thumbnailPoint.x = (targetWidth - scaledWidth) * 0.5;
        }
    }


    // this is actually the interesting part:

	RetinaAwareUIGraphicsBeginImageContext(targetSize);

    CGRect thumbnailRect = CGRectZero;
    thumbnailRect.origin = thumbnailPoint;
    thumbnailRect.size.width  = scaledWidth;
    thumbnailRect.size.height = scaledHeight;

    [sourceImage drawInRect:thumbnailRect];

    newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if(newImage == nil) NSLog(@"could not scale image");


    return newImage ;
}


- (UIImage *)imageByScalingToSize:(CGSize)targetSize {

    UIImage *sourceImage = self;
    UIImage *newImage = nil;

    //   CGSize imageSize = sourceImage.size;
    //   CGFloat width = imageSize.width;
    //   CGFloat height = imageSize.height;

    CGFloat targetWidth = targetSize.width;
    CGFloat targetHeight = targetSize.height;

    //   CGFloat scaleFactor = 0.0;
    CGFloat scaledWidth = targetWidth;
    CGFloat scaledHeight = targetHeight;

    CGPoint thumbnailPoint = CGPointMake(0.0,0.0);

    // this is actually the interesting part:

	RetinaAwareUIGraphicsBeginImageContext(targetSize);

    CGRect thumbnailRect = CGRectZero;
    thumbnailRect.origin = thumbnailPoint;
    thumbnailRect.size.width  = scaledWidth;
    thumbnailRect.size.height = scaledHeight;

    [sourceImage drawInRect:thumbnailRect];

    newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if(newImage == nil) NSLog(@"could not scale image");


    return newImage ;
}


- (UIImage *)imageRotatedByRadians:(CGFloat)radians
{
    return [self imageRotatedByDegrees:RadiansToDegrees(radians)];
}

- (UIImage *)imageRotatedByDegrees:(CGFloat)degrees
{
    // calculate the size of the rotated view's containing box for our drawing space
    UIView *rotatedViewBox = [[UIView alloc] initWithFrame:CGRectMake(0,0,self.size.width, self.size.height)];
    CGAffineTransform t = CGAffineTransformMakeRotation(DegreesToRadians(degrees));
    rotatedViewBox.transform = t;
    CGSize rotatedSize = rotatedViewBox.frame.size;
    [rotatedViewBox release];

    // Create the bitmap context
	RetinaAwareUIGraphicsBeginImageContext(rotatedSize);
    CGContextRef bitmap = UIGraphicsGetCurrentContext();

    // Move the origin to the middle of the image so we will rotate and scale around the center.
    CGContextTranslateCTM(bitmap, rotatedSize.width/2, rotatedSize.height/2);

    //   // Rotate the image context
    CGContextRotateCTM(bitmap, DegreesToRadians(degrees));

    // Now, draw the rotated/scaled image into the context
    CGContextScaleCTM(bitmap, 1.0, -1.0);
    CGContextDrawImage(bitmap, CGRectMake(-self.size.width / 2, -self.size.height / 2, self.size.width, self.size.height), [self CGImage]);

    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;

}

- (UIImage *)imageWithDefaultOrientation {
	UIImage* sourceImage = self; 
	int targetWidth = (int)(self.size.width * self.scale);
	int targetHeight = (int)(self.size.height * self.scale);

	if (sourceImage.imageOrientation == UIImageOrientationLeft || sourceImage.imageOrientation == UIImageOrientationRight) {
		targetWidth = (int)(self.size.height * self.scale);
		targetHeight = (int)(self.size.width * self.scale);
	}
	
	CGImageRef imageRef = [sourceImage CGImage];
	CGBitmapInfo bitmapInfo = kCGImageAlphaNoneSkipLast;//CGImageGetBitmapInfo(imageRef);
	CGColorSpaceRef colorSpaceInfo = CGColorSpaceCreateDeviceRGB(); //CGImageGetColorSpace(imageRef);
	size_t bitsPerComponent = 8; //CGImageGetBitsPerComponent(imageRef);
	size_t bytesPerRow = 4 * targetWidth; //CGImageGetBytesPerRow(imageRef);
	
	if (bitmapInfo == kCGImageAlphaNone) {
		bitmapInfo = kCGImageAlphaNoneSkipLast;
	}
	
	CGContextRef bitmap;
	
	if (sourceImage.imageOrientation == UIImageOrientationUp || sourceImage.imageOrientation == UIImageOrientationDown) {
		bitmap = CGBitmapContextCreate(NULL, targetWidth, targetHeight, bitsPerComponent, bytesPerRow, colorSpaceInfo, bitmapInfo);
	} else {
		bitmap = CGBitmapContextCreate(NULL, targetHeight, targetWidth, bitsPerComponent, bytesPerRow, colorSpaceInfo, bitmapInfo);
	}
	
	if (sourceImage.imageOrientation == UIImageOrientationLeft) {
		CGContextRotateCTM (bitmap, DegreesToRadians(90));
		CGContextTranslateCTM (bitmap, 0, -targetHeight);
		
	} else if (sourceImage.imageOrientation == UIImageOrientationRight) {
		CGContextRotateCTM (bitmap, DegreesToRadians(-90));
		CGContextTranslateCTM (bitmap, -targetWidth, 0);
		
	} else if (sourceImage.imageOrientation == UIImageOrientationUp) {
		// NOTHING
	} else if (sourceImage.imageOrientation == UIImageOrientationDown) {
		CGContextTranslateCTM (bitmap, targetWidth, targetHeight);
		CGContextRotateCTM (bitmap, DegreesToRadians(-180));
	}
	
	CGContextDrawImage(bitmap, CGRectMake(0, 0, targetWidth, targetHeight), imageRef);
	CGImageRef ref = CGBitmapContextCreateImage(bitmap);
	UIImage* newImage = [UIImage imageWithCGImage:ref scale:self.scale orientation:UIImageOrientationUp];
	
	CGContextRelease(bitmap);
	CGImageRelease(ref);
	
	return newImage;
}

- (UIImage *)imageWithBlackAndWhiteEffect {
    UIImage *newImage = nil;
	
    UIImage *anImage = self;

    if (anImage) {
        CGColorSpaceRef colorSapce = CGColorSpaceCreateDeviceGray();
        CGContextRef context = CGBitmapContextCreate(nil, (size_t) (anImage.size.width * anImage.scale), (size_t) (anImage.size.height * anImage.scale), 8, (size_t) (anImage.size.width * anImage.scale), colorSapce, kCGImageAlphaNone);
        CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
        CGContextSetShouldAntialias(context, NO);
        CGContextDrawImage(context, CGRectMake(0, 0, anImage.size.width * anImage.scale, anImage.size.height * anImage.scale), [anImage CGImage]);

        CGImageRef bwImage = CGBitmapContextCreateImage(context);
        CGContextRelease(context);
        CGColorSpaceRelease(colorSapce);

        UIImage *resultImage = [UIImage imageWithCGImage:bwImage scale:self.scale orientation:UIImageOrientationUp];
	    CGImageRelease(bwImage);

	    RetinaAwareUIGraphicsBeginImageContext(anImage.size);
        [resultImage drawInRect:CGRectMake(0.0, 0.0, anImage.size.width, anImage.size.height)];
        newImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }

    return newImage;

}

- (UIImage *)imageWithSepiaEffect {
    UIImage *currentImage = self;

    CGImageRef originalImage = [currentImage CGImage];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmapContext = CGBitmapContextCreate(NULL,
            CGImageGetWidth(originalImage),
            CGImageGetHeight(originalImage),
            8,
            CGImageGetWidth(originalImage)*4,
            colorSpace,
            kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    CGContextDrawImage(bitmapContext, CGRectMake(0, 0, CGBitmapContextGetWidth(bitmapContext), CGBitmapContextGetHeight(bitmapContext)), originalImage);
    UInt8 *data = CGBitmapContextGetData(bitmapContext);
    int numComponents = 4;
    int bytesInContext = CGBitmapContextGetHeight(bitmapContext) * CGBitmapContextGetBytesPerRow(bitmapContext);

    int redIn, greenIn, blueIn, redOut, greenOut, blueOut;

    for (int i = 0; i < bytesInContext; i += numComponents) {

        redIn = data[i];
        greenIn = data[i+1];
        blueIn = data[i+2];

        redOut = (int) ((int)(redIn * .393) + (greenIn *.769) + (blueIn * .189));
        greenOut = (int) ((int)(redIn * .349) + (greenIn *.686) + (blueIn * .168));
        blueOut = (int) ((int)(redIn * .272) + (greenIn *.534) + (blueIn * .131));

        if (redOut>255) redOut = 255;
        if (blueOut>255) blueOut = 255;
        if (greenOut>255) greenOut = 255;

        data[i] = (UInt8) (redOut);
        data[i+1] = (UInt8) (greenOut);
        data[i+2] = (UInt8) (blueOut);
    }

    CGImageRef outImage = CGBitmapContextCreateImage(bitmapContext);
    UIImage *uiImage = [UIImage imageWithCGImage:outImage scale:self.scale orientation:self.imageOrientation];
    CGImageRelease(outImage);
	CGContextRelease(bitmapContext);
    return uiImage;
}


- (UIImage *)imageWithBlurRadius:(int)radius
{
	int *data = [self rgbaData];
	int width = self.size.width * self.scale;
	int height = self.size.height * self.scale;

	int pixelIndex, k;
	int r, g, b;
	int originalColor;
	int factor, sum;
	int bufferLength = width*height;

    int kernelSize = 1+radius*2;
    int kernel[kernelSize];
    for (int i = 0; i<radius; i++) {
		kernel[i] = kernel[kernelSize-i-1] = i*i*i+1;
    }
    kernel[radius] = radius*radius;

	for (int x = 0; x < width; x++) {
		for (int y = 0; y < height; y++) {
			sum = 0;
			pixelIndex = y*width + x;

			CLIP(pixelIndex, radius, bufferLength - 1 - radius);

			originalColor = data[pixelIndex];
			r = GET_R(originalColor);
			g = GET_G(originalColor);
			b = GET_B(originalColor);

			for (k = -radius; k<radius; k++) {
				originalColor = data[pixelIndex + k];

				factor = kernel[k+radius];
				r += GET_R(originalColor)*factor;
				g += GET_G(originalColor)*factor;
				b += GET_B(originalColor)*factor;
				sum += factor;
			}

			data[pixelIndex] = COLOR_FROM_ARGB(
				255,
				(r + (sum>>1))/sum,
				(g + (sum>>1))/sum,
				(b + (sum>>1))/sum
			);
		}
	}

	UIImage *result = [UIImage imageWithData:data width:width height:height];

	free(data);

	return result;
}

- (UIImage *)imageWithFunkyStripesEffect
{
	int *data = [self rgbaData];
	int width = self.size.width * self.scale;
	int height = self.size.height * self.scale;

	int r, g, b;
	int originalColor;

	for (int y = 0; y < height; y++) {
		r = g = b = 0;
		for (int x = 0; x < width; x++) {
			originalColor = data[y*width + x];
			r += GET_R(originalColor);
			g += GET_G(originalColor);
			b += GET_B(originalColor);
		}
		
		for (int x = 0; x < width; x++) {
			data[y*width + x] = COLOR_FROM_ARGB(255, r/width, g/width, b/width);
		}
	}

	UIImage *result = [UIImage imageWithData:data width:width height:height];

	free(data);

	return result;
}

- (UIImage *)imageWithCornerRadius:(CGFloat)radius {

	// Begin a new image that will be the new image with the rounded corners
	// (here with the size of an UIImageView)
	RetinaAwareUIGraphicsBeginImageContext(self.size);

	// Add a clip before drawing anything, in the shape of an rounded rect
	[[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, self.size.width, self.size.height)
	                            cornerRadius:radius] addClip];
	// Draw your image
	[self drawInRect:CGRectMake(0, 0, self.size.width, self.size.height)];

	// Get the image, here setting the UIImageView image
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();

	// Lets forget about that we were drawing
	UIGraphicsEndImageContext();

	return image;
}

- (BOOL) color:(int)colorA equalsColor:(int)colorB withTolerance:(int)tolerance
{
	int aR = GET_R(colorA);
	int aG = GET_G(colorA);
	int aB = GET_B(colorA);

	int bR = GET_R(colorB);
	int bG = GET_G(colorB);
	int bB = GET_B(colorB);

	return (abs(aR - bR) < tolerance
		 && abs(aG - bG) < tolerance
		 && abs(aB - bB) < tolerance);
}


- (UIImage *)trimmedImageWithColor:(UIColor*)trimUIColor tolerance:(int)tolerance
{
	int *data = [self rgbaData];
	int width = (int)(self.size.width * self.scale);
	int height = (int)(self.size.height * self.scale);

	uint trimColor;
	if (!trimUIColor) {
		uint topLeftColor = (uint)data[0];
		uint trimColorR = GET_R(topLeftColor);
		uint trimColorG = GET_G(topLeftColor);
		uint trimColorB = GET_B(topLeftColor);
		trimColor = trimColorR | (trimColorG << 8) | (trimColorB << 16) | (255 << 24);
	} else {
		uint trimColorR = (uint)(CGColorGetComponents(trimUIColor.CGColor)[0]*255.0);
		uint trimColorG = (uint)(CGColorGetComponents(trimUIColor.CGColor)[1]*255.0);
		uint trimColorB = (uint)(CGColorGetComponents(trimUIColor.CGColor)[2]*255.0);
		trimColor = trimColorR | (trimColorG << 8) | (trimColorB << 16) | (255 << 24);
	}

	int minX = 0;
	int maxX = width - 1;
	int minY = 0;
	int maxY = height - 1;

	for (int x = 0; x < width; x++) {
		if (![self color:data[0*width + x] equalsColor:trimColor withTolerance:tolerance]) {
			minX = x;
			break;
		}
		if (![self color:data[(height-1)*width + x] equalsColor:trimColor withTolerance:tolerance]) {
			minX = x;
			break;
		}
	}
	for (int x = width-1; x >= 0; x--) {
		if (![self color:data[0*width + x] equalsColor:trimColor withTolerance:tolerance]) {
			maxX = x;
			break;
		}
		if (![self color:data[(height-1)*width + x] equalsColor:trimColor withTolerance:tolerance]) {
			maxX = x;
			break;
		}
	}
	for (int y = 0; y < height; y++) {
		if (![self color:data[y*width + 0] equalsColor:trimColor withTolerance:tolerance]) {
			minY = y;
			break;
		}
		if (![self color:data[y*width + width - 1] equalsColor:trimColor withTolerance:tolerance]) {
			minY = y;
			break;
		}
	}
	for (int y = height-1; y >= 0; y--) {
		if (![self color:data[y*width + 0] equalsColor:trimColor withTolerance:tolerance]) {
			maxY = y;
			break;
		}
		if (![self color:data[y*width + width - 1] equalsColor:trimColor withTolerance:tolerance]) {
			maxY = y;
			break;
		}
	}

	int newWidth = maxX - minX + 1;
	int newHeight = maxY - minY + 1;
	int *newData = malloc(newWidth*newHeight*4);

	for (int y = 0; y < newHeight; y++) {
		for (int x = 0; x < newWidth; x++) {
			newData[y*newWidth + x] = data[(y + minY)*width + (x + minX)];
		}
	}

	UIImage *result = [UIImage imageWithData:newData width:newWidth height:newHeight];

	free(data);
	free(newData);

	return result;
}


#pragma pixel methods

/**
 * returns pointer to array of ARGB pixels. This data should be freed when not used anymore
 */
- (int*) rgbaData
{
	CGImageRef imageRef = [self CGImage];
	int width = CGImageGetWidth(imageRef);
	int height = CGImageGetHeight(imageRef);

	int numPixels = width*height;
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	int *rgbaData = calloc(numPixels, sizeof(int));
	int bytesPerPixel = 4;
	int bytesPerRow = bytesPerPixel * width;
	int bitsPerComponent = 8;
	CGContextRef context = CGBitmapContextCreate(rgbaData, width, height,
												 bitsPerComponent, bytesPerRow, colorSpace,
												 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);

	CGColorSpaceRelease(colorSpace);
	CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
	CGContextRelease(context);

	return rgbaData;
}

+ (UIImage *) imageWithData:(int*)rgba width:(int)width height:(int)height
{
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef bitmapContext = CGBitmapContextCreate(
									rgba,
									width,
									height,
									8,       // bitsPerComponent
									4*width, // bytesPerRow
									colorSpace,
									kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);

	CGColorSpaceRelease(colorSpace);

	CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
	
	UIImage *image = [UIImage imageWithCGImage:cgImage scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp];
	CGContextRelease(bitmapContext);
	CGImageRelease(cgImage);

	return image;
}

+ (UIImage *)imageWithData:(int*)rgba fullWidth:(int)fullWidth fullHeight:(int)fullHeight offsetX:(int)offsetX offsetY:(int)offsetY width:(int)width height:(int)height
{
	int numPixels = width*height;
	int *croppedData = calloc(numPixels, sizeof(int));

	for (int x=0; x<width; x++) {
		for (int y=0; y<height; y++) {
			croppedData[y*width + x] = rgba[(y + offsetY)*fullWidth + (x + offsetX)];
		}
	}
	
	UIImage *image = [UIImage imageWithData:croppedData width:width height:height];

	free(croppedData);

	return image;
}

#pragma hash

+ (UIImage *)imageWithSize:(CGSize)size {

	int* rgba = calloc(size.width*size.height, sizeof(int));

	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef bitmapContext = CGBitmapContextCreate(
									rgba,
									size.width,
									size.height,
									8,       // bitsPerComponent
									4*size.width, // bytesPerRow
									colorSpace,
									kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);

	CFRelease(colorSpace);
	free(rgba);

	CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
	
	UIImage *image = [UIImage imageWithCGImage:cgImage];
	CGContextRelease(bitmapContext);
	CGImageRelease(cgImage);

	return image;
}

- (NSString *)md5
{
	unsigned char result[16];
	NSData *imageData = [NSData dataWithData:UIImagePNGRepresentation(self)];
	CC_MD5(imageData, [imageData length], result);
	NSString *imageHash = [NSString stringWithFormat:
	                                           @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
	                                           result[0], result[1], result[2], result[3],
	                                           result[4], result[5], result[6], result[7],
	                                           result[8], result[9], result[10], result[11],
	                                           result[12], result[13], result[14], result[15]
	                                           ];
	return imageHash;
}

@end;
