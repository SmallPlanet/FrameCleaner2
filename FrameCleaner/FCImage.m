//
//  FCImage.m
//  FrameCleaner
//
//  Created by Quinn McHenry on 7/7/14.
//  Copyright (c) 2014 Small Planet. All rights reserved.
//

#import "FCImage.h"
#import "PVRUtility.h"

@implementation FCImage

#define SKIPPIX 4
+ (void) dumpData:(NSData*)data size:(CGSize)size
{
    unsigned char * ptr = (unsigned char*)[data bytes];
    for (int i=0;i<size.height;i+=SKIPPIX)
    {
        for (int j=0;j<size.width;j+=SKIPPIX)
        {
            printf("%s", (*ptr+*(ptr+1)+*(ptr+2) > 0 ? "*" : " "));
            ptr+=3*SKIPPIX;
        }
        int increment = 3*size.width*(SKIPPIX-1);
        ptr+=increment;
        printf("\n");
    }
    printf("\n");
}

- (id) initWithSource:(NSString *)sourcePath
{
    self = [super init];
    if(self)
    {
        self.sourceFile = sourcePath;
        
        NSData * stdoutData = NULL;
        
        RunTask(@"/sbin/md5",
                [NSArray arrayWithObjects:@"-q", sourcePath, NULL],
                NULL, NULL, NULL, &stdoutData, NULL);
        
        self.md5 = [[[NSString alloc] initWithData:stdoutData encoding:NSUTF8StringEncoding] autorelease];
        
    }
    
    return self;
}


- (void) cropPixelsWithMin:(CGPoint)min andMax:(CGPoint)max {
    
}

#pragma mark - Exporters

- (void) exportLZ4To:(NSString *)exportPath withQueue:(NSOperationQueue *)queue
{
    // We want to prepend the width and height to the pixel data, unsigned shorts for each
    unsigned short width = 0;
    unsigned short height = 0;
    NSData * pixels = NULL;
    
    if(gShouldTrimImages)
    {
        width = globalMax.x-globalMin.x;
        height = globalMax.y-globalMin.y;
        pixels = [self croppedPixelsWithMin:globalMin
                                     andMax:globalMax];
    }
    else
    {
        pixels = [self pixelData];
        width = pixelsWide;
        height = pixelsHigh;
    }
    
    [queue addOperationWithBlock:^{
        NSString * ePath = [exportPath stringByAppendingPathExtension:@"lz4"];
        
        @autoreleasepool {
            NSMutableData * data = [NSMutableData data];
            
            [data appendBytes:&width length:2];
            [data appendBytes:&height length:2];
            [data appendData:pixels];
            
            [[data lz4Deflate] writeToFile:ePath atomically:NO];
        }
    }];
}

- (void) exportPNGTo:(NSString *)exportPath withQueue:(NSOperationQueue *)queue
{
    // We want to prepend the width and height to the pixel data, unsigned shorts for each
    unsigned short width = 0;
    unsigned short height = 0;
    NSData * pixels = NULL;
    
    if(gShouldTrimImages)
    {
        width = globalMax.x-globalMin.x;
        height = globalMax.y-globalMin.y;
        pixels = [self croppedPixelsWithMin:globalMin
                                     andMax:globalMax];
    }
    else
    {
        pixels = [self pixelData];
        width = pixelsWide;
        height = pixelsHigh;
    }
    
    [queue addOperationWithBlock:^{
        NSString * ePath = [exportPath stringByAppendingPathExtension:@"png"];
        
        @autoreleasepool {
            
            unsigned char * bufferPtr = (unsigned char *)[pixels bytes];
            BOOL hasAlpha = ((width * height * 4) == [pixels length]);
            int samples = hasAlpha ? 4 : 3;
            
            NSBitmapImageRep * bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:&bufferPtr
                            pixelsWide:width
                            pixelsHigh:height
                         bitsPerSample:8
                       samplesPerPixel:samples
                              hasAlpha:hasAlpha
                              isPlanar:NO
                        colorSpaceName:NSDeviceRGBColorSpace
                          bitmapFormat:NSAlphaNonpremultipliedBitmapFormat
                           bytesPerRow:width*samples
                          bitsPerPixel:8*samples];

            NSData * pngData = [bitmap representationUsingType:NSPNGFileType properties:[NSDictionary dictionary]];
            
            [bitmap release];
            
            NSString * tempPath = [ePath stringByAppendingPathExtension:@"orig"];
            
            [pngData writeToFile:tempPath atomically:NO];
            
            // Run through PNG crush...
            NSString * launchPath = [NSString stringWithFormat:@"%@/pngcrush", [[NSBundle mainBundle] resourcePath]];
            NSArray * arguments = [NSArray arrayWithObjects:
                                   @"-q", @"-iphone", @"-f", @"0",
                                   tempPath, ePath,
                                   NULL];
            
            RunTask(launchPath, arguments, NULL, NULL, NULL, NULL, NULL);
            
            [[NSFileManager defaultManager] removeItemAtPath:tempPath error:NULL];
            
        }
    }];
}

- (void) exportPNGQuantTo:(NSString *)exportPath
                withQueue:(NSOperationQueue *)queue
            withTableSize:(int)tableSize
{
    // We want to prepend the width and height to the pixel data, unsigned shorts for each
    unsigned short width = 0;
    unsigned short height = 0;
    NSData * pixels = NULL;
    
    if(gShouldTrimImages)
    {
        width = globalMax.x-globalMin.x;
        height = globalMax.y-globalMin.y;
        pixels = [self croppedPixelsWithMin:globalMin
                                     andMax:globalMax];
    }
    else
    {
        pixels = [self pixelData];
        width = pixelsWide;
        height = pixelsHigh;
    }
    
    [queue addOperationWithBlock:^{
        NSString * ePath = [exportPath stringByAppendingPathExtension:@"png"];
        
        @autoreleasepool {
            
            unsigned char * bufferPtr = (unsigned char *)[pixels bytes];
            BOOL hasAlpha = ((width * height * 4) == [pixels length]);
            int samples = hasAlpha ? 4 : 3;
            
            NSBitmapImageRep * bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:&bufferPtr
                            pixelsWide:width
                            pixelsHigh:height
                         bitsPerSample:8
                       samplesPerPixel:samples
                              hasAlpha:hasAlpha
                              isPlanar:NO
                        colorSpaceName:NSDeviceRGBColorSpace
                          bitmapFormat:NSAlphaNonpremultipliedBitmapFormat
                           bytesPerRow:width*samples
                          bitsPerPixel:8*samples];
            
            NSData * pngData = [bitmap representationUsingType:NSPNGFileType properties:[NSDictionary dictionary]];
            
            [bitmap release];
            
            [pngData writeToFile:ePath atomically:NO];
            
            // Run through PNG crush...
            NSString * launchPath = [NSString stringWithFormat:@"%@/pngnq", [[NSBundle mainBundle] resourcePath]];
            NSArray * arguments = [NSArray arrayWithObjects:
                                   @"-s", @"1", @"-n", [NSString stringWithFormat:@"%d", tableSize],
                                   ePath, NULL];
            
            RunTask(launchPath, arguments, NULL, NULL, NULL, NULL, NULL);
            
            
            [[NSFileManager defaultManager] removeItemAtPath:ePath error:NULL];
            
            NSString * exportedPath = [NSString stringWithFormat:@"%@-nq8.png", [ePath stringByDeletingPathExtension]];
            [[NSFileManager defaultManager] moveItemAtPath:exportedPath toPath:ePath error:NULL];
            
        }
    }];
}

- (void) exportPVRGradientTo:(NSString *)exportPath withQueue:(NSOperationQueue *)queue
{
    // We want to prepend the width and height to the pixel data, unsigned shorts for each
    unsigned short width = 0;
    unsigned short height = 0;
    NSData * pixels = NULL;
    
    if(gShouldTrimImages)
    {
        width = globalMax.x-globalMin.x;
        height = globalMax.y-globalMin.y;
        pixels = [self croppedPixelsWithMin:globalMin
                                     andMax:globalMax];
    }
    else
    {
        pixels = [self pixelData];
        width = pixelsWide;
        height = pixelsHigh;
    }
    
    [queue addOperationWithBlock:^{
        NSString * ePath = [exportPath stringByAppendingPathExtension:@"pvr"];
        
        @autoreleasepool {
            int altSize;
            NSData * pvrData = [PVRUtility CompressDataLossy:pixels
                                                      OfSize:NSMakeSize(width, height)
                                                 AltTileSize:&altSize
                                               WithWeighting:@"--channel-weighting-linear"
                                                 WithSamples:samplesPerPixel];
            
            [pvrData writeToFile:ePath atomically:NO];
        }
    }];
}

- (void) exportPVRPhotoTo:(NSString *)exportPath withQueue:(NSOperationQueue *)queue
{
    // We want to prepend the width and height to the pixel data, unsigned shorts for each
    unsigned short width = 0;
    unsigned short height = 0;
    NSData * pixels = NULL;
    
    if(gShouldTrimImages)
    {
        width = globalMax.x-globalMin.x;
        height = globalMax.y-globalMin.y;
        pixels = [self croppedPixelsWithMin:globalMin
                                     andMax:globalMax];
    }
    else
    {
        pixels = [self pixelData];
        width = pixelsWide;
        height = pixelsHigh;
    }
    
    [queue addOperationWithBlock:^{
        NSString * ePath = [exportPath stringByAppendingPathExtension:@"pvr"];
        
        @autoreleasepool {
            int altSize;
            NSData * pvrData = [PVRUtility CompressDataLossy:pixels
                                                      OfSize:NSMakeSize(width, height)
                                                 AltTileSize:&altSize
                                               WithWeighting:@"--channel-weighting-perceptual"
                                                 WithSamples:samplesPerPixel];
            
            [pvrData writeToFile:ePath atomically:NO];
        }
    }];
}

- (void) exportSP1To:(NSString *)exportPath
           withQueue:(NSOperationQueue *)queue
       withTableSize:(int)tableSize
{
    // SP1: a format which uses paletted image coloring (1 byte pixels) and is rendered with
    // a custom fragment shader with the color palette embedded it in (so the in memory
    // texture is still the 1 byte per pixel format). This allows for super-fast loading
    // (no decompression required) and fast rendering
    //
    // To do this, we run pngnq on our source image, read in the quantized image, extract
    // the color palette and 1 byte image array from that, and output the image.sp1 and
    // image.fsh
    unsigned short width = 0;
    unsigned short height = 0;
    NSData * pixels = NULL;
    
    if(gShouldTrimImages)
    {
        width = globalMax.x-globalMin.x;
        height = globalMax.y-globalMin.y;
        pixels = [self croppedPixelsWithMin:globalMin
                                     andMax:globalMax];
    }
    else
    {
        pixels = [self pixelData];
        width = pixelsWide;
        height = pixelsHigh;
    }
    
    [queue addOperationWithBlock:^{
        NSString * ePath = [exportPath stringByAppendingPathExtension:@"png"];
        
        @autoreleasepool {
            
            unsigned char * bufferPtr = (unsigned char *)[pixels bytes];
            BOOL hasAlpha = ((width * height * 4) == [pixels length]);
            int samples = hasAlpha ? 4 : 3;
            
            NSBitmapImageRep * bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:&bufferPtr
                            pixelsWide:width
                            pixelsHigh:height
                         bitsPerSample:8
                       samplesPerPixel:samples
                              hasAlpha:hasAlpha
                              isPlanar:NO
                        colorSpaceName:NSDeviceRGBColorSpace
                          bitmapFormat:NSAlphaNonpremultipliedBitmapFormat
                           bytesPerRow:width*samples
                          bitsPerPixel:8*samples];

            NSData * pngData = [bitmap representationUsingType:NSPNGFileType properties:[NSDictionary dictionary]];
            
            [bitmap release];
            
            NSString * tempPath = [ePath stringByAppendingPathExtension:@"orig"];
            
            [pngData writeToFile:tempPath atomically:NO];
            
            // Run through PNG crush...
            NSString * launchPath = [NSString stringWithFormat:@"%@/pngnq", [[NSBundle mainBundle] resourcePath]];
            NSArray * arguments = [NSArray arrayWithObjects:
                                   @"-s", @"1", @"-n", [NSString stringWithFormat:@"%d", tableSize],
                                   tempPath, ePath, NULL];
            
            RunTask(launchPath, arguments, NULL, NULL, NULL, NULL, NULL);
            
            [[NSFileManager defaultManager] removeItemAtPath:tempPath error:NULL];
            
            
            // The file we want to process is at ePath; get a source RGBA bytes from the file.
            
            
        }
    }];
}

#pragma mark -

- (unsigned char *) sampleSet
{
    return sampleSet;
}

- (BOOL) compare:(FCImage*)other
{
    if([md5 isEqualToString:[other md5]])
    {
        return YES;
    }
    
    if(gCompareUsingMD5)
    {
        return NO;
    }
    
    @autoreleasepool {
        
        NSData * pixelDataA = [self pixelData];
        
        // quick sample check; is they are not the same return NO
        if(SHOULD_SAMPLE())
        {
            unsigned char * ptr1 = [self sampleSet];
            unsigned char * ptr2 = [other sampleSet];
            
            for(int i = 0; i < kSampleSize; i++)
            {
                if(abs(ptr1[i] - ptr2[i]) > 20)
                    return NO;
            }
        }
        
        NSData * pixelDataB = [other pixelData];
        
        if([pixelDataA length] != [pixelDataB length])
            return NO;
        
        // run through all pixels and look for equivalence
        const unsigned char * ptrA = (const unsigned char *)[pixelDataA bytes];
        const unsigned char * ptrB = (const unsigned char *)[pixelDataB bytes];
        NSUInteger length = [pixelDataA length];
        
        for(NSUInteger i = 0; i < length; i++)
        {
            if(abs(*ptrA - *ptrB) > 20)
                return NO;
            ptrA++;
            ptrB++;
        }
        
        return YES;
    }
    
    return NO;
}

- (BOOL) compare:(FCImage*)other pixelsWithMin:(CGPoint)min andMax:(CGPoint)max
{
    if([md5 isEqualToString:[other md5]])
    {
        return YES;
    }
    
    int newWidth = max.x-min.x;
    int newHeight = max.y-min.y;
    
    const unsigned char * basePtr = (const unsigned char *)[[self pixelData] bytes];
    const unsigned char * basePtr2 = (const unsigned char *)[[other pixelData] bytes];
    const unsigned char * ptr;
    const unsigned char * ptr2;
    
    for(int y = min.y; y < min.y+newHeight; y++)
    {
        for(int x = min.x; x < min.x+newWidth; x++)
        {
            ptr = basePtr + (y * pixelsWide * samplesPerPixel) + (x * samplesPerPixel);
            ptr2 = basePtr2 + (y * pixelsWide * samplesPerPixel) + (x * samplesPerPixel);
            for (int i = 0; i < samplesPerPixel; i++)
            {
                if(abs(ptr[i] - ptr2[i]) > 20) return NO;
            }
        }
    }
    
    return YES;
}

- (NSData *) subtract:(FCImage*)other
{
    NSData * pixelData1 = [self pixelData];
    NSData * pixelData2 = [other pixelData];
    unsigned char * ptr1 = (unsigned char*)[pixelData1 bytes];
    unsigned char * ptr2 = (unsigned char*)[pixelData2 bytes];
    
    unsigned char * newBasePtr = (unsigned char *)malloc([pixelData1 length]);
    unsigned char * newPtr = newBasePtr;
    
    for(int i=0; i<[pixelData1 length]; i++)
    {
        *newPtr = abs(*ptr1 - *ptr2);
        ptr1++;
        ptr2++;
        newPtr++;
    }
    
    return [NSData dataWithBytesNoCopy:newBasePtr length:[pixelData1 length] freeWhenDone:true];
}

- (NSData *) croppedPixelsWithMin:(CGPoint)min
                           andMax:(CGPoint)max
{
    // Nab the pixel data, crop it, save it as a png, store the new image path
    NSData * pixelDataA = [self pixelData];
    
    // new pixel data
    int newWidth = max.x-min.x;
    int newHeight = max.y-min.y;
    
    unsigned char * newBasePtr = (unsigned char *)malloc(newWidth*newHeight*4);
    unsigned char * newPtr;
    
    const unsigned char * basePtr = (const unsigned char *)[pixelDataA bytes];
    const unsigned char * ptr;
    
    for(int y = min.y; y < min.y+newHeight; y++)
    {
        for(int x = min.x; x < min.x+newWidth; x++)
        {
            ptr = basePtr + (y * pixelsWide * samplesPerPixel) + (x * samplesPerPixel);
            newPtr = newBasePtr + ((y-(int)min.y) * newWidth * samplesPerPixel) + ((x-(int)min.x) * samplesPerPixel);
            
            newPtr[0] = ptr[0];
            newPtr[1] = ptr[1];
            newPtr[2] = ptr[2];
            newPtr[3] = ptr[3];
        }
    }
    
    return [NSData dataWithBytesNoCopy:newBasePtr length:(newWidth*newHeight*samplesPerPixel) freeWhenDone:YES];
}

- (void) trimmedValuesWithMin:(CGPoint*)min
                       andMax:(CGPoint*)max
{
    @autoreleasepool
    {
        NSData * pixelDataA = [self pixelData];
        const unsigned char * basePtr = (const unsigned char *)[pixelDataA bytes];
        const unsigned char * ptr;
        min->x = 9999999999;
        min->y = 9999999999;
        max->x = 0;
        max->y = 0;
        
        // Find the minimum y
        for(int y = 0; y < pixelsHigh; y++)
        {
            for(int x = 0; x < pixelsWide; x++)
            {
                ptr = basePtr + (y * pixelsWide * samplesPerPixel) + (x * samplesPerPixel);
                
                if(ptr[3] != 0)
                {
                    min->y = y;
                    y = pixelsHigh;
                    break;
                }
            }
        }
        
        // Find the maximum y
        for(int y = pixelsHigh-1; y >= 0; y--)
        {
            for(int x = 0; x < pixelsWide; x++)
            {
                ptr = basePtr + (y * pixelsWide * samplesPerPixel) + (x * samplesPerPixel);
                
                if(ptr[3] != 0)
                {
                    max->y = y;
                    y = -1;
                    break;
                }
            }
        }
        
        // Find the minimum x
        for(int x = 0; x < pixelsWide; x++)
        {
            for(int y = 0; y < pixelsHigh; y++)
            {
                ptr = basePtr + (y * pixelsWide * samplesPerPixel) + (x * samplesPerPixel);
                
                if(ptr[3] != 0)
                {
                    min->x = x;
                    x = pixelsWide;
                    break;
                }
            }
        }
        
        // Find the maximum x
        for(int x = pixelsWide-1; x >= 0; x--)
        {
            for(int y = 0; y < pixelsHigh; y++)
            {
                ptr = basePtr + (y * pixelsWide * samplesPerPixel) + (x * samplesPerPixel);
                
                if(ptr[3] != 0)
                {
                    max->x = x;
                    x = -1;
                    break;
                }
            }
        }
        
        [self dropMemory];
    }
}



typedef struct
{
    unsigned char* data;
    int size;
    int offset;
}tImageSource;

static void pngReadCallback(png_structp png_ptr, png_bytep data, png_size_t length)
{
    tImageSource* isource = (tImageSource*)png_get_io_ptr(png_ptr);
    
    if((int)(isource->offset + length) <= isource->size)
    {
        memcpy(data, isource->data+isource->offset, length);
        isource->offset += length;
    }
    else
    {
        png_error(png_ptr, "pngReaderCallback failed");
    }
}

- (void) dropMemory
{
    [storePixelData release];
    storePixelData = NULL;
}

- (CGSize) size
{
    return CGSizeMake(pixelsWide, pixelsHigh);
}

- (void) makeTransparentRect:(CGRect)rect
{
    NSData *data = [self pixelData];
    unsigned char *ptr = (unsigned char*)[data bytes];
    long rowSize = pixelsWide * 4;
    for (int x=rect.origin.x; x<rect.origin.x+rect.size.width; x++)
    {
        for (int y=pixelsHigh-rect.origin.y-rect.size.height; y<pixelsHigh-rect.origin.y; y++)
        {
            *(ptr + y*rowSize + x*4 + 3) = 0;
            //            *(ptr + y*rowSize + x*4 + 3) = 128;
            //            *(ptr + y*rowSize + x*4 + 0) = 255;
        }
    }
}

- (NSData *) pixelData
{
    if(storePixelData)
        return storePixelData;
    
    
    
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    // NSImage sucks in regards to premultiplication of alpha.  So, lets save this out to PNG
    // then load using libpng, and read the raw bytes that way
    NSData * pngData = [NSData dataWithContentsOfFile:sourceFile];
    
    const void * pData = [pngData bytes];
    int nDatalen = [pngData length];
    
    //bool CCImage::_initWithPngData(void * pData, int nDatalen)
    {
        // length of bytes to check if it is a valid png file
#define PNGSIGSIZE  8
        bool bRet = false;
        png_byte        header[PNGSIGSIZE]   = {0};
        png_structp     png_ptr     =   0;
        png_infop       info_ptr    = 0;
        
        int m_nWidth;
        int m_nHeight;
        int m_nBitsPerComponent;
        int m_bHasAlpha;
        int m_nChannels;
        unsigned char * m_pData = NULL;
        
        do
        {
            // png header len is 8 bytes
            if(nDatalen < PNGSIGSIZE)
                break;
            
            // check the data is png or not
            memcpy(header, pData, PNGSIGSIZE);
            if(png_sig_cmp(header, 0, PNGSIGSIZE))
                break;
            
            // init png_struct
            png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, 0, 0, 0);
            if(! png_ptr)
                break;
            
            // init png_info
            info_ptr = png_create_info_struct(png_ptr);
            if(!info_ptr)
                break;
            
            // set the read call back function
            tImageSource imageSource;
            imageSource.data    = (unsigned char*)pData;
            imageSource.size    = nDatalen;
            imageSource.offset  = 0;
            png_set_read_fn(png_ptr, &imageSource, pngReadCallback);
            
            // read png header info
            
            // read png file info
            png_read_info(png_ptr, info_ptr);
            
            m_nWidth = png_get_image_width(png_ptr, info_ptr);
            m_nHeight = png_get_image_height(png_ptr, info_ptr);
            m_nBitsPerComponent = png_get_bit_depth(png_ptr, info_ptr);
            png_uint_32 channels = png_get_channels(png_ptr, info_ptr);
            png_uint_32 color_type = png_get_color_type(png_ptr, info_ptr);
            
            // only support color type: PNG_COLOR_TYPE_RGB, PNG_COLOR_TYPE_RGB_ALPHA PNG_COLOR_TYPE_PALETTE
            // and expand bit depth to 8
            if(color_type == PNG_COLOR_TYPE_RGB ||
               color_type == PNG_COLOR_TYPE_RGB_ALPHA)
            {
                
                
                if (m_nBitsPerComponent == 16)
                {
                    png_set_strip_16(png_ptr);
                    m_nBitsPerComponent = 8;
                }
                
                m_nChannels = 3;
                m_bHasAlpha = (color_type & PNG_COLOR_MASK_ALPHA) ? true : false;
                if (m_bHasAlpha)
                {
                    m_nChannels = channels = 4;
                }
                
                // read png data
                // m_nBitsPerComponent will always be 8
                m_pData = (unsigned char *)malloc(m_nWidth * m_nHeight * channels);
                memset(m_pData, 255, m_nWidth * m_nHeight * channels);
                
                png_bytep* row_pointers = (png_bytep*)malloc(sizeof(png_bytep)*m_nHeight);
                if (row_pointers)
                {
                    const unsigned int stride = m_nWidth * channels;
                    for (unsigned short i = 0; i < m_nHeight; ++i)
                    {
                        png_uint_32 q = i * stride;
                        row_pointers[i] = (png_bytep)m_pData + q;
                    }
                    png_read_image(png_ptr, row_pointers);
                    
                    free(row_pointers);
                    bRet = true;
                }
            }
        } while (0);
        
        if(m_pData)
        {
            pixelsWide = m_nWidth;
            pixelsHigh = m_nHeight;
            samplesPerPixel = m_nChannels;
            
            // create a sample set for quick analysis...
            if(SHOULD_SAMPLE())
            {
                srand(kSampleSeed);
                int totalSize = (m_nWidth * m_nHeight * m_nChannels);
                for(int i = 0; i < kSampleSize; i++)
                {
                    int k = rand() % totalSize;
                    sampleSet[i] = m_pData[k];
                }
            }
            
            @autoreleasepool
            {
                storePixelData = [[NSData dataWithBytesNoCopy:m_pData length:(m_nWidth * m_nHeight * m_nChannels) freeWhenDone:YES] retain];
            }
        }
    }
    
    [pool release];
    
    
    return storePixelData;
}

@end
