//
//  FCImage.m
//  FrameCleaner
//
//  Created by Quinn McHenry on 7/7/14.
//  Copyright (c) 2014 Small Planet. All rights reserved.
//

#import "FCImage.h"
#import "NSDataAdditions.h"
#import "png.h"

@implementation FCImage

#define SKIPPIX 4
+ (void) dumpData:(NSData*)data size:(CGSize)size {
    unsigned char * ptr = (unsigned char*)[data bytes];
    for (int i=0;i<size.height;i+=SKIPPIX) {
        for (int j=0;j<size.width;j+=SKIPPIX) {
            printf("%s", (*ptr+*(ptr+1)+*(ptr+2) > 0 ? "*" : " "));
            ptr+=3*SKIPPIX;
        }
        int increment = 3*size.width*(SKIPPIX-1);
        ptr+=increment;
        printf("\n");
    }
    printf("\n");
}

+ (void) writeMaskImageFromData:(NSData *)data size:(CGSize)size toPath:(NSString *)path {

    BOOL hasAlpha = YES;
    int samples = 4;

    unsigned char * ptr = (unsigned char*)[data bytes];
    for (int i=0;i<size.height;i++) {
        for (int j=0;j<size.width;j++) {
            if (*ptr+*(ptr+1)+*(ptr+2) > 0 ) {
                *ptr = 255;
                *(ptr+1) = 0;
                *(ptr+2) = 0;
                *(ptr+3) = 128;
            } else {
                *ptr = 0;
                *(ptr+1) = 0;
                *(ptr+2) = 0;
                *(ptr+3) = 0;
            }
            ptr+=samples;
        }
    }
    
    
    unsigned char * bufferPtr = (unsigned char *)[data bytes];

    NSBitmapImageRep * bitmap = [[NSBitmapImageRep alloc]
                                  initWithBitmapDataPlanes:&bufferPtr
                                                pixelsWide:size.width
                                                pixelsHigh:size.height
                                             bitsPerSample:8
                                           samplesPerPixel:samples
                                                  hasAlpha:hasAlpha
                                                  isPlanar:NO
                                            colorSpaceName:NSDeviceRGBColorSpace
                                              bitmapFormat:NSAlphaNonpremultipliedBitmapFormat
                                               bytesPerRow:size.width*samples
                                              bitsPerPixel:8*samples];


    NSData *pngData = [bitmap representationUsingType:NSPNGFileType properties:[NSDictionary dictionary]];
    [pngData writeToFile:path atomically:NO];

}

- (id) initWithSource:(NSString *)sourcePath {
    self = [super init];
    if(self) {
        self.sourceFile = sourcePath;
        NSData * stdoutData = NULL;
        RunTask(@"/sbin/md5", @[@"-q", sourcePath], NULL, NULL, NULL, &stdoutData, NULL);
        self.md5 = [[NSString alloc] initWithData:stdoutData encoding:NSUTF8StringEncoding];
    }
    return self;
}


- (void) cropPixelsWithMin:(CGPoint)min andMax:(CGPoint)max {
    
}

#pragma mark - Exporters

- (void) exportImageWithFormat:(FCImageExportFormat)format toFileName:(NSString*)fileName queue:(NSOperationQueue*)_queue cropped:(BOOL)cropped toMin:(CGPoint)min max:(CGPoint)max {
    // We want to prepend the width and height to the pixel data, unsigned shorts for each
    width = 0;
    height = 0;
    pixels = nil;
    
    if(cropped) {
        width = max.x - min.x;
        height = max.y - min.y;
        pixels = [self croppedPixelsWithMin:min andMax:max];
    } else {
        pixels = [self pixelData];
        width = pixelsWide;
        height = pixelsHigh;
    }
    
    NSString *fullFileName = [fileName stringByAppendingPathExtension:[self extensionForExportFormat:format]];

    switch(format) {
        case PNG:
            [self exportPNGTo:fullFileName withQueue:_queue];
            break;
        case LZ4:
            [self exportLZ4To:fullFileName withQueue:_queue];
            break;
        case PVR_Photo:
            [self exportPVRPhotoTo:fullFileName withQueue:_queue];
            break;
        case PVR_Gradient:
            [self exportPVRGradientTo:fullFileName withQueue:_queue];
            break;
        case PNG_Quant_256:
            [self exportPNGQuantTo:fullFileName withQueue:_queue withTableSize:256];
            break;
        case PNG_Quant_128:
            [self exportPNGQuantTo:fullFileName withQueue:_queue withTableSize:128];
            break;
        case PNG_Quant_64:
            [self exportPNGQuantTo:fullFileName withQueue:_queue withTableSize:64];
            break;
        case SP1:
            [self exportSP1To:fullFileName withQueue:_queue withTableSize:64];
            break;
    }
}

- (NSString *) extensionForExportFormat:(FCImageExportFormat)format {
    switch(format) {
        case PNG:
        case PNG_Quant_256:
        case PNG_Quant_128:
        case PNG_Quant_64:
        case SP1:
            return @"png";
            break;
        case LZ4:
            return @"lz4";
            break;
        case PVR_Photo:
        case PVR_Gradient:
            return @"pvr";
            break;
    }
    return @"";
}

- (void) exportLZ4To:(NSString *)exportPath withQueue:(NSOperationQueue *)queue {
    
    [queue addOperationWithBlock:^{
        
        @autoreleasepool {
            NSMutableData * data = [NSMutableData data];
            
            [data appendBytes:&width length:2];
            [data appendBytes:&height length:2];
            [data appendData:pixels];
            
            [[data lz4Deflate] writeToFile:exportPath atomically:NO];
        }
    }];
}

- (void) exportPNGTo:(NSString *)exportPath withQueue:(NSOperationQueue *)queue {
    [queue addOperationWithBlock:^{
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
            
            NSString * tempPath = [exportPath stringByAppendingPathExtension:@"orig"];
            
            [pngData writeToFile:tempPath atomically:NO];
            
            // Run through PNG crush...
            NSString * launchPath = [NSString stringWithFormat:@"%@/pngcrush", [[NSBundle mainBundle] resourcePath]];
            NSArray * arguments = @[@"-q", @"-iphone", @"-f", @"0", tempPath, exportPath];
            
            RunTask(launchPath, arguments, NULL, NULL, NULL, NULL, NULL);
            
            [[NSFileManager defaultManager] removeItemAtPath:tempPath error:NULL];
        }
    }];
}

- (void) exportPNGQuantTo:(NSString *)exportPath
                withQueue:(NSOperationQueue *)queue
            withTableSize:(int)tableSize
{
    [queue addOperationWithBlock:^{
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
            
//            [bitmap release];
            
            [pngData writeToFile:exportPath atomically:NO];
            
            // Run through PNG crush...
            NSString * launchPath = [NSString stringWithFormat:@"%@/pngnq", [[NSBundle mainBundle] resourcePath]];
            NSArray * arguments = @[@"-s", @"1", @"-n", [NSString stringWithFormat:@"%d", tableSize],exportPath];
            
            RunTask(launchPath, arguments, NULL, NULL, NULL, NULL, NULL);
            
            
            [[NSFileManager defaultManager] removeItemAtPath:exportPath error:NULL];
            
            NSString * exportedPath = [NSString stringWithFormat:@"%@-nq8.png", [exportPath stringByDeletingPathExtension]];
            [[NSFileManager defaultManager] moveItemAtPath:exportedPath toPath:exportPath error:NULL];
            
        }
    }];
}

- (void) exportPVRGradientTo:(NSString *)exportPath withQueue:(NSOperationQueue *)queue
{
//    [queue addOperationWithBlock:^{
//        @autoreleasepool {
//            int altSize;
//            NSData * pvrData = [PVRUtility CompressDataLossy:pixels
//                                                      OfSize:NSMakeSize(width, height)
//                                                 AltTileSize:&altSize
//                                               WithWeighting:@"--channel-weighting-linear"
//                                                 WithSamples:samplesPerPixel];
//            
//            [pvrData writeToFile:exportPath atomically:NO];
//        }
//    }];
}

- (void) exportPVRPhotoTo:(NSString *)exportPath withQueue:(NSOperationQueue *)queue
{
//    [queue addOperationWithBlock:^{
//        @autoreleasepool {
//            int altSize;
//            NSData * pvrData = [PVRUtility CompressDataLossy:pixels
//                                                      OfSize:NSMakeSize(width, height)
//                                                 AltTileSize:&altSize
//                                               WithWeighting:@"--channel-weighting-perceptual"
//                                                 WithSamples:samplesPerPixel];
//            
//            [pvrData writeToFile:exportPath atomically:NO];
//        }
//    }];
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
    [queue addOperationWithBlock:^{
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
            
//            [bitmap release];
            
            NSString * tempPath = [exportPath stringByAppendingPathExtension:@"orig"];
            
            [pngData writeToFile:tempPath atomically:NO];
            
            // Run through PNG crush...
            NSString * launchPath = [NSString stringWithFormat:@"%@/pngnq", [[NSBundle mainBundle] resourcePath]];
            NSArray * arguments = @[@"-s", @"1", @"-n", [NSString stringWithFormat:@"%d", tableSize], tempPath, exportPath];
            
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
    if([self.md5 isEqualToString:[other md5]])
    {
        return YES;
    }
    
    if(self.compareUsingMD5)
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
    if([self.md5 isEqualToString:[other md5]])
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
                if(abs(ptr[i] - ptr2[i]) > 20)
                    return NO;
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

- (CGRect) trimmedFrameWithinRect:(CGRect)startingFrame {
    CGRect frame;
    @autoreleasepool
    {
        NSData * pixelDataA = [self pixelData];
        const unsigned char * basePtr = (const unsigned char *)[pixelDataA bytes];
        const unsigned char * ptr;
        CGPoint min, max;
        min.x = startingFrame.origin.x;
        min.y = startingFrame.origin.y;
        max.x = min.x + startingFrame.size.width;
        max.y = min.y + startingFrame.size.height;
        BOOL found = NO;
        
        // Find the minimum y
        if (min.y < max.y) {
            for(NSInteger y = min.y; y < max.y; y++) {
                for(NSInteger x = min.x; x < max.x; x++) {
                    ptr = basePtr + (y * pixelsWide * samplesPerPixel) + (x * samplesPerPixel);
                    if(ptr[3] != 0) {
                        min.y = y;
                        y = max.y;
                        found = YES;
                        break;
                    }
                }
            }
        }
        
        // Find the maximum y
        if (min.y < max.y) {
            for(NSInteger y = max.y-1; y >= min.y; y--) {
                for(NSInteger x = min.x; x < max.x; x++) {
                    ptr = basePtr + (y * pixelsWide * samplesPerPixel) + (x * samplesPerPixel);
                    if(ptr[3] != 0) {
                        max.y = y;
                        y = min.y-1;
                        found = YES;
                        break;
                    }
                }
            }
        }
        
        // Find the minimum x
        if (min.x < max.x) {
            for(NSInteger x = min.x; x < max.x; x++) {
                for(NSInteger y = min.y; y < max.y; y++) {
                    ptr = basePtr + (y * pixelsWide * samplesPerPixel) + (x * samplesPerPixel);
                    if(ptr[3] != 0) {
                        min.x = x;
                        x = max.x;
                        found = YES;
                        break;
                    }
                }
            }
        }
        
        // Find the maximum x
        if (min.x < max.x) {
            for(NSInteger x = max.x-1; x >= min.x; x--) {
                for(NSInteger y = min.y; y < max.y; y++) {
                    ptr = basePtr + (y * pixelsWide * samplesPerPixel) + (x * samplesPerPixel);
                    if(ptr[3] != 0) {
                        max.x = x;
                        x = min.x-1;
                        found = YES;
                        break;
                    }
                }
            }
        }
        
        pixelDataA = nil;
        if (!found) {
            frame = CGRectZero;
        } else {
            CGRect r1 = CGRectMake(min.x, min.y, 1, 1);
            CGRect r2 = CGRectMake(max.x, max.y, 1, 1);
            frame = CGRectUnion(r1, r2);
        }
    }
    return frame;
}

- (CGRect) trimmedFrame {
    [self pixelData];
    CGRect fullFrame = CGRectMake(0,0,pixelsWide,pixelsHigh);
    return [self trimmedFrameWithinRect:fullFrame];
}

typedef struct
{
    unsigned char* data;
    NSUInteger size;
    NSUInteger offset;
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
    storePixelData = nil;
}

- (CGSize) size
{
    return CGSizeMake(pixelsWide, pixelsHigh);
}

- (void) setSize:(CGSize)newSize {
    pixelsWide = newSize.width;
    pixelsHigh = newSize.height;
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

- (void) setStorePixelData:(NSData *)data {
    storePixelData = data;
}

- (void) setSamplesPerPixel:(NSUInteger)samples {
    samplesPerPixel = samples;
}

- (NSData *) pixelData
{
    if(storePixelData) {
        return storePixelData;
    }
    
    @autoreleasepool {
    
        // NSImage sucks in regards to premultiplication of alpha.  So, lets save this out to PNG
        // then load using libpng, and read the raw bytes that way
        NSData * pngData = [NSData dataWithContentsOfFile:self.sourceFile];
        
        const void * pData = [pngData bytes];
        NSUInteger nDatalen = [pngData length];
        
        //bool CCImage::_initWithPngData(void * pData, int nDatalen)
        {
            // length of bytes to check if it is a valid png file
    #define PNGSIGSIZE  8
            bool bRet = false;
            png_byte        header[PNGSIGSIZE]   = {0};
            png_structp     png_ptr     =   0;
            png_infop       info_ptr    = 0;
            
            NSUInteger m_nWidth = 0;
            NSUInteger m_nHeight = 0;
            int m_nBitsPerComponent;
            int m_bHasAlpha;
            int m_nChannels = 0;
            unsigned char * m_pData = NULL;
            
            do {
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
                if(color_type == PNG_COLOR_TYPE_RGB || color_type == PNG_COLOR_TYPE_RGB_ALPHA) {
                    
                    if (m_nBitsPerComponent == 16) {
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
                        const unsigned int stride = ((int)(m_nWidth * channels));
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
            
            if(m_pData) {
                pixelsWide = m_nWidth;
                pixelsHigh = m_nHeight;
                samplesPerPixel = m_nChannels;
                
                // create a sample set for quick analysis...
                if(SHOULD_SAMPLE()) {
                    srand(kSampleSeed);
                    NSUInteger totalSize = (m_nWidth * m_nHeight * m_nChannels);
                    for(int i = 0; i < kSampleSize; i++) {
                        int k = rand() % totalSize;
                        sampleSet[i] = m_pData[k];
                    }
                }
                
                @autoreleasepool {
                    storePixelData = [NSData dataWithBytesNoCopy:m_pData length:(m_nWidth * m_nHeight * m_nChannels) freeWhenDone:YES];
                }
            }
        }
    }
    return storePixelData;
}

@end


extern NSInteger RunTask(NSString *launchPath, NSArray *arguments, NSString *workingDirectoryPath, NSDictionary *environment, NSData *stdinData, NSData **stdoutDataPtr, NSData **stderrDataPtr)
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:launchPath]) {
        return -1;
    }
    
    NSTask *task = [[NSTask alloc] init];
    
    [task setLaunchPath:launchPath];
    [task setArguments:arguments];
    
    // Configure the environment
    
    if (environment) {
        NSMutableDictionary *mutableEnv = [environment mutableCopy];
        [mutableEnv setObject:@"true" forKey:@"COPY_EXTENDED_ATTRIBUTES_DISABLE"];
        [task setEnvironment:mutableEnv];
        //        [mutableEnv release];
    } else {
        // Make sure COPY_EXTENDED_ATTRIBUTES_DISABLE is set in the current environment, which will be inherited by the task
        setenv("COPY_EXTENDED_ATTRIBUTES_DISABLE", "true", 1);
    }
    
    if (workingDirectoryPath) {
        [task setCurrentDirectoryPath:workingDirectoryPath];
    } else {
        [task setCurrentDirectoryPath:@"/tmp"];
    }
    
    NSPipe *stdinPipe = nil;
    NSPipe *stdoutPipe = nil;
    NSPipe *stderrPipe = nil;
    
    if (stdinData) {
        stdinPipe = [[NSPipe alloc] init];
        [task setStandardInput:stdinPipe];
    } else {
        [task setStandardInput:[NSFileHandle fileHandleWithNullDevice]];
    }
	
    if (stdoutDataPtr != NULL) {
        stdoutPipe = [[NSPipe alloc] init];
        [task setStandardOutput:stdoutPipe];
    } else {
        [task setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
    }
    
    if (stderrDataPtr != NULL) {
        stderrPipe = [[NSPipe alloc] init];
        [task setStandardError:stderrPipe];
    } else {
        [task setStandardError:[NSFileHandle fileHandleWithNullDevice]];
    }
    
    [task launch];
    
    if (stdinPipe) {
        NS_DURING
        if ([stdinData length] > 0) {
            [[stdinPipe fileHandleForWriting] writeData:stdinData];
        }
		[[stdinPipe fileHandleForWriting] closeFile];
        NS_HANDLER
        NS_ENDHANDLER
    }
    
    NSData *stdoutData = nil;
    NSData *stderrData = nil;
	
    if (stdoutPipe) {
        NS_DURING
        stdoutData = [[stdoutPipe fileHandleForReading] readDataToEndOfFile];
        NS_HANDLER
        NS_ENDHANDLER
    }
    
    if (stderrPipe) {
        NS_DURING
        stderrData = [[stderrPipe fileHandleForReading] readDataToEndOfFile];
        NS_HANDLER
        NS_ENDHANDLER
    }
	
    @try
    {
        if([task isRunning])
        {
            [task waitUntilExit];
        }
    }
    @catch(NSException *e)
    {
        
    }
	
    NSInteger status = [task terminationStatus];
	
    //    [task release];
    task = nil;
	
    if (stdoutDataPtr != NULL) {
        *stdoutDataPtr = stdoutData;
    }
    
    if (stderrDataPtr != NULL) {
        *stderrDataPtr = stderrData;
    }
    
    return status;
}
