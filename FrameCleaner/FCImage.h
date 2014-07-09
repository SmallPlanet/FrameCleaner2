//
//  FCImage.h
//  FrameCleaner
//
//  Created by Quinn McHenry on 7/7/14.
//  Copyright (c) 2014 Small Planet. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    PNG,
    LZ4,
    PVR_Photo,
    PVR_Gradient,
    PNG_Quant_256,
    PNG_Quant_128,
    PNG_Quant_64,
    SP1
} FCImageExportFormat;


@interface FCImage : NSObject {
    NSUInteger pixelsWide;
    NSUInteger pixelsHigh;
    NSUInteger samplesPerPixel;
    NSData *storePixelData;
    unsigned char sampleSet[kSampleSize+12];

    // for exporting
    NSData * pixels;
    unsigned short width;
    unsigned short height;
}

@property (nonatomic, retain) NSString *sourceFile;
@property (nonatomic, retain) NSString *destinationFile;
@property (nonatomic, assign) BOOL compareUsingMD5;
@property (nonatomic, retain) NSString *md5;
@property (nonatomic, assign) NSInteger index;

+ (void) writeMaskImageFromData:(NSData *)data size:(CGSize)size toPath:(NSString *)path;
- (id) initWithSource:(NSString *)sourcePath;
- (CGRect) trimmedFrameWithinRect:(CGRect)startingFrame;
- (CGRect) trimmedFrame;
- (NSData *) subtract:(FCImage*)other;
- (CGSize) size;
- (void) setSize:(CGSize)newSize;
- (void) setSamplesPerPixel:(NSUInteger)samples;
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
- (void) setStorePixelData:(NSData *)data;
- (NSData *) pixelData;

@end

extern NSInteger RunTask(NSString *launchPath, NSArray *arguments, NSString *workingDirectoryPath, NSDictionary *environment, NSData *stdinData, NSData **stdoutDataPtr, NSData **stderrDataPtr);
