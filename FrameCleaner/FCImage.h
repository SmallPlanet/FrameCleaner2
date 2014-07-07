//
//  FCImage.h
//  FrameCleaner
//
//  Created by Quinn McHenry on 7/7/14.
//  Copyright (c) 2014 Small Planet. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FCImage : NSObject {
    NSInteger pixelsWide;
    NSInteger pixelsHigh;
    NSInteger samplesPerPixel;
    NSData *storePixelData;
    unsigned char sampleSet[kSampleSize+12];
}

@property (nonatomic, retain) NSString *sourceFile;
@property (nonatomic, retain) NSString *destinationFile;
@property (nonatomic, retain) NSString *md5;
@property (nonatomic, assign) NSInteger index;

- (NSData *) subtract:(FCImage*)other;
- (CGSize) size;
+ (void) dumpData:(NSData*)data size:(CGSize)size;
- (BOOL) compare:(FCImage*)other pixelsWithMin:(CGPoint)min andMax:(CGPoint)max;

- (void) exportLZ4To:(NSString *)exportPath withQueue:(NSOperationQueue *)queue;
- (void) exportPNGTo:(NSString *)exportPath withQueue:(NSOperationQueue *)queue;
- (void) exportPNGQuantTo:(NSString *)exportPath withQueue:(NSOperationQueue *)queue
            withTableSize:(int)tableSize;
- (void) exportPVRGradientTo:(NSString *)exportPath withQueue:(NSOperationQueue *)queue;
- (void) exportPVRPhotoTo:(NSString *)exportPath withQueue:(NSOperationQueue *)queue;
- (void) exportSP1To:(NSString *)exportPath withQueue:(NSOperationQueue *)queue
       withTableSize:(int)tableSize;


@end
