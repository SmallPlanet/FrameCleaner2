//
//  PVRUtility.m
//  Planetscapes
//
//  Created by Rocco Bowling on 11/10/10.
//  Copyright 2010 Chimera Software. All rights reserved.
//

#import "PVRUtility.h"
#include "PVRTexLib.h"

using namespace pvrtexlib;

static NSLock * fileLock = NULL;

@implementation PVRUtility

#pragma mark -

+ (void) initialize
{
	fileLock = [[NSLock alloc] init];
}

+ (NSData *) DecompressPVRData:(NSData *)data
{
	PVRTRY
	{
		// get the utilities instance
		//PVRTextureUtilities *PVRU = PVRTextureUtilities::getPointer();
		PVRTextureUtilities PVRU = PVRTextureUtilities();
		
		// open and reads a pvr texture from the file location specified by strFilePath
		CPVRTexture sOriginalTexture((const uint8* const )[data bytes]);
		
		
		if(sOriginalTexture.getPixelType() == OGL_RGBA_4444 ||
		   sOriginalTexture.getPixelType() == OGL_RGBA_8888)
		{
			CPVRTextureData& uncompressedData = sOriginalTexture.getData();
			return [NSData dataWithBytes:uncompressedData.getData() length:uncompressedData.getDataSize()];
		}
		
		// declare an empty texture to decompress into
		CPVRTexture sDecompressedTexture;
		
		// decompress the compressed texture into this texture
		PVRU.DecompressPVR(sOriginalTexture, sDecompressedTexture);
		
		CPVRTextureData& uncompressedData = sDecompressedTexture.getData();
		
		return [NSData dataWithBytes:uncompressedData.getData() length:uncompressedData.getDataSize()];
		
	} PVRCATCH(myException) {
		// handle any exceptions here
		printf("Exception in example 1: %s \n",myException.what());
	}
	
	return NULL;
}

+ (NSData *) CompressDataLossy:(NSData *)data
						OfSize:(NSSize)size
                   AltTileSize:(int*)altTileSize
                 WithWeighting:(NSString *)weighting
                   WithSamples:(int)samplesPerPixel
{
	NSString * fileName = [NSString stringWithFormat:@"/tmp/tmp%0lx8", (long)data];
	NSString * pngName = [fileName stringByAppendingString:@".png"];
    NSString * pow2Name = [fileName stringByAppendingString:@".pow2"];
	NSString * pvrName = [fileName stringByAppendingString:@".pvr"];
	
	NSBitmapImageRep * bitmap_rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                pixelsWide:size.width
                pixelsHigh:size.height
             bitsPerSample:8
           samplesPerPixel:samplesPerPixel
                  hasAlpha:(samplesPerPixel == 4)
                  isPlanar:NO
            colorSpaceName:NSDeviceRGBColorSpace
              bitmapFormat:NSAlphaNonpremultipliedBitmapFormat
               bytesPerRow:size.width * samplesPerPixel
              bitsPerPixel:samplesPerPixel * 8];

	memcpy([bitmap_rep bitmapData], [data bytes], [data length]);
	
	[[bitmap_rep representationUsingType:NSPNGFileType
							  properties:[NSDictionary dictionary]] writeToFile:pngName
                                atomically:NO];
    
    // Convert that PNG to a power of two size...
    int pow2Width = 2048, pow2Height = 2048;
	while((size.width*2) < pow2Width)
	{
		pow2Width /= 2;
	}
	while((size.height*2) < pow2Height)
	{
		pow2Height /= 2;
	}
    if(pow2Width > pow2Height)
        pow2Height = pow2Width;
    if(pow2Height > pow2Width)
        pow2Width = pow2Height;
    	    
    RunTask(@"/usr/bin/sips",
            [NSArray arrayWithObjects:@"--resampleHeightWidth", [NSString stringWithFormat:@"%d", pow2Height], [NSString stringWithFormat:@"%d", pow2Width], @"--out", pow2Name, pngName, NULL],
            NULL, NULL, NULL, NULL, NULL);
    
    *altTileSize = pow2Height;
    
	// Convert to PVR
	NSString * launchPath = [NSString stringWithFormat:@"%@/texturetool", [[NSBundle mainBundle] resourcePath]];
	NSArray * arguments = [NSArray arrayWithObjects:
						   @"-e", @"PVRTC", @"--bits-per-pixel-2", weighting, @"--alpha-is-opacity", @"-f", @"PVR",
						   pow2Name, @"-o", pvrName, 
						   NULL];
	
	RunTask(launchPath, arguments, NULL, NULL, NULL, NULL, NULL);
	
//	[bitmap_rep release];
	
	NSData * compressedData = [NSData dataWithContentsOfFile:pvrName];
	
	[[NSFileManager defaultManager] removeItemAtPath:pngName error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:pow2Name error:NULL];
	[[NSFileManager defaultManager] removeItemAtPath:pvrName error:NULL];
	
	return compressedData;
}

@end
