//
//  UIImage+Extensions.h
//  JigsawPuz
//
//  Created by Dymov Eugene on 09.11.11.
//  Copyright (c) 2011 Eugene Valeyev. All rights reserved.
//



#import <Foundation/Foundation.h>

void RetinaAwareUIGraphicsBeginImageContext(CGSize size);

@interface UIImage (CS_Extensions)
- (UIImage *)imageAtRect:(CGRect)rect;
- (UIImage *)imageByScalingProportionallyToMinimumSize:(CGSize)targetSize;
- (UIImage *)imageByScalingProportionallyToSize:(CGSize)targetSize;
- (UIImage *)imageByScalingToSize:(CGSize)targetSize;
- (UIImage *)imageRotatedByRadians:(CGFloat)radians;
- (UIImage *)imageRotatedByDegrees:(CGFloat)degrees;
- (UIImage *)imageWithBlackAndWhiteEffect;
- (UIImage *)imageWithSepiaEffect;
- (UIImage *)imageWithBlurRadius:(int)radius;
- (UIImage *)imageWithFunkyStripesEffect;

- (UIImage *)imageWithDefaultOrientation;

- (UIImage *)imageWithCornerRadius:(CGFloat)radius;

- (UIImage *)trimmedImageWithColor:(UIColor*)trimUIColor tolerance:(int)tolerance;

- (int*)rgbaData;
+ (UIImage *)imageWithData:(int*)rgba width:(int)width height:(int)height;
+ (UIImage *)imageWithData:(int*)rgba fullWidth:(int)fullWidth fullHeight:(int)fullHeight offsetX:(int)offsetX offsetY:(int)offsetY width:(int)width height:(int)height;
+ (UIImage *)imageWithSize:(CGSize)size;

- (NSString *)md5;

@end;