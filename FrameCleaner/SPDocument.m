//
//  SPDocument.m
//  FrameCleaner
//
//  Created by Quinn McHenry on 7/7/14.
//  Copyright (c) 2014 Small Planet. All rights reserved.
//

#import "SPDocument.h"
#import "FCImage.h"
#import "SPBorderedView.h"
#import "NSMutableArray+Shuffle.h"

@implementation SPDocument

#pragma mark -

- (void) resetRegions {
    [self.regionsView reset];
}

- (void) resetZones {
    [self.timelineView reset];
}

- (NSString *)filepathAtIndex:(NSUInteger)index {
    return [self.directoryPath stringByAppendingPathComponent:self.allFiles[index]];
}

- (void) loadFrames {
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.directoryPath error:NULL];
    self.allFiles = [NSMutableArray array];
    for (NSString *file in contents) {
        if ([file hasSuffix:@".png"]) {
            [self.allFiles addObject:file];
        }
    }
    [self loadImages];
    self.maskView.image = nil;
    self.imageSize = CGSizeZero;
    [self.regionsView reset];
    
    // show first image
    if (self.allFiles.count > 0) {
        NSString *filePath = [self filepathAtIndex:0];
        self.firstImage = [[FCImage alloc] initWithSource:filePath];
        [self.firstImage pixelData];
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:filePath];
        image.size = self.firstImage.size;
        self.imageSize = self.firstImage.size;
        self.imageView.image = image;
        self.imageView.frame = NSMakeRect(0, 0, image.size.width, image.size.height);
        self.regionsView.frame = self.imageView.frame;
    }
    [self windowForSheet].title = [NSString stringWithFormat:@"%@ - %ld frames", [self.directoryPath lastPathComponent], self.allFiles.count];    
}

- (void) showLoadFramesSheet {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles=NO;
    panel.canCreateDirectories=YES;
    panel.canChooseDirectories=YES;
    
    __weak typeof(panel) bpanel = panel;
    [panel beginSheetModalForWindow:self.windowForSheet completionHandler:^(NSInteger result) {
        if (result == 1 && bpanel.URLs.count > 0) {
            self.directoryPath = [[bpanel.URLs objectAtIndex:0] path];
            [self performSelector:@selector(loadFrames) withObject:nil afterDelay:0];
        }
    }];

}

- (void) drawMask {
    //        [FCImage dumpData:self.subregionData size:firstImage.size];
    if (!self.maskImageTmpFilename) {
        self.maskImageTmpFilename = [self temporaryFilename];
    }
    if (!self.subregionData) {
        return;
    }
    [FCImage writeMaskImageFromData:self.subregionData size:self.imageSize toPath:self.maskImageTmpFilename];
    self.maskView.image = [[NSImage alloc] initWithContentsOfFile:self.maskImageTmpFilename];
}

- (void) loadImages {
    if (!self.allImages) {
        self.allImages = [NSMutableArray array];
    }
    [self.allImages removeAllObjects];
    for (NSString *filename in self.allFiles) {
        NSString *filePath = [self.directoryPath stringByAppendingPathComponent:filename];
        if ([filePath hasSuffix:@".png"]) {
            FCImage *image = [[FCImage alloc] initWithSource:filePath];
            if (image) {
                image.diffCount = 1;
                [self.allImages addObject:image];
            }
        }
    }
    [self.timelineView setFCImageFrames:self.allImages];
}

- (void) play {
    playbackIndex = 0;
    if (!playbackCache) {
        playbackCache = [NSMutableArray array];
    }
    [playbackCache removeAllObjects];
    for (int i=0; i<self.allFiles.count; i++) {
        NSImage *img = [[NSImage alloc] initWithContentsOfFile:[self filepathAtIndex:i]];
        img.size = self.firstImage.size;
        [playbackCache addObject:img];
    }
    self.playbackTimer = [NSTimer scheduledTimerWithTimeInterval:1.f/[self frameRate] target:self selector:@selector(playUpdate:) userInfo:nil repeats:YES];
}

- (void) playUpdate:(NSTimer *)timer {
    if (playbackIndex < playbackCache.count) {
        self.imageView.image = [playbackCache objectAtIndex:playbackIndex++];
    } else {
        [self.playbackTimer invalidate];
        [playbackCache removeAllObjects];
        playbackIndex = -1;
    }
    [self.timelineView setCurrentFrameIndex:playbackIndex];
}

- (void) showFrameAtIndex:(NSInteger)index {
    if (index > 0 && index < self.allImages.count) {
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:[self filepathAtIndex:index]];
        image.size = self.firstImage.size;
        self.imageView.image = image;
    }
}

- (void) processFrames {
    globalFrame = CGRectZero;
    
    if (!self.allImages) {
        [self loadImages];
    }
    
    for (FCImage *image in self.allImages) {
        CGRect trimmedFrame = [image trimmedFrame];
        if (trimmedFrame.origin.x >= 0.f) {
            if ([self.allImages indexOfObject:image] == 0) {
                globalFrame = trimmedFrame;
            } else {
                globalFrame = CGRectUnion(globalFrame, trimmedFrame);
            }
        }
    }
    
    if (YES || [self subregionsCount] > 0) {
        self.subregionData = nil;
        FCImage *firstImage = nil;
        for (FCImage *image in self.allImages) {
            if (!firstImage) {
                firstImage = [[FCImage alloc] initWithSource:[self.directoryPath stringByAppendingPathComponent:self.allFiles[0]]];
                self.subregionData = [NSMutableData dataWithLength:[[firstImage pixelData] length]];
                image.diffCount = 0;
            } else {
                NSInteger diffCount = 0;
                NSData *diff = [firstImage subtract:image];
                unsigned char * ptr1 = (unsigned char*)[self.subregionData bytes];
                unsigned char * ptr2 = (unsigned char*)[diff bytes];
                
                for(int i=0; i<[self.subregionData length]; i++) {
                    if (*ptr2 > 0) {
                        diffCount++;
                    }
                    if (*ptr2 > *ptr1) {
                        *ptr1 = *ptr2;
                    }
                    ptr1++;
                    ptr2++;
                }
                image.diffCount = diffCount;
            }
        }
        [self drawMask];
    }
    [self.timelineView setFCImageFrames:self.allImages];
}

- (NSInteger) subregionsCount {
    return self.regionsView.regions.count;
//    return [self.maxSubregions selectedItem].tag;
}

- (CGRect) viewFrameFromRegion:(CGRect)region {
    return CGRectMake(region.origin.x, self.imageSize.height - region.origin.y - region.size.height, region.size.width, region.size.height);
}

- (CGRect) regionFrameFromView:(CGRect)frame {
    return CGRectMake(frame.origin.x, self.imageSize.height - frame.origin.y - frame.size.height, frame.size.width, frame.size.height);
}

- (NSMutableArray *) subregions {
    return self.regionsView.regions;
}

// SUBREGION_THRESHOLD compare stored difference of each pixel channel to this, if lower ignore the diff
#define SUBREGION_THRESHOLD 0
// SUBREGION_INSET (negative) expands the bounds of an existing rect when searching for determining if a point should be inside a region
#define SUBREGION_INSET -1
// regions with fewer than MIN_POINTS_PER_SUBREGION will be rejected. 1 means keep all
#define MIN_POINTS_PER_SUBREGION 1
// largest edge allowed when building small subregions
#define EDGE_THRESHOLD 40
// subregion padding to overlap the cropped images over the knocked out background, needed for proper rendering when scaled down
//#define SUBREGION_PADDING 1

//#define INSET(r) CGRectInset(r,2,2)

- (void) autogenerateMaxSubregions:(NSUInteger)max
{
    NSData *data = self.subregionData;
    CGSize size = self.imageSize;
    NSMutableArray *subregions = [self subregions];
    unsigned char *ptr = (unsigned char*)[data bytes];
    
    for (int r=0; r<size.height; r++) {
        for (int c=0; c<size.width; c++) {
            if (abs(*ptr) +abs(*(ptr+1)) + abs(*(ptr+2)) + abs(*(ptr+3)) > SUBREGION_THRESHOLD) {
                CGPoint point = CGPointMake(1.f*c,1.f*(size.height - r - 1));
                CGFloat minArea = -1;
                SPBorderedView *minRegion = nil;
                for (SPBorderedView *region in self.subregions) {
                    if ([region containsPoint:point withInset:SUBREGION_INSET] && [region maxSideWithPoint:point] < EDGE_THRESHOLD) {
                        CGFloat newArea = [region areaWithPoint:point];
                        if (minArea < 0 || minArea > newArea) {
                            minRegion = region;
                            minArea = newArea;
                        }
                    }
                }
                if (minArea > 0) {
                    [minRegion addPoint:point];
                } else {
                    SPBorderedView *region = [[SPBorderedView alloc] init];
                    [region addPoint:point];
                    [self.regionsView addRegion:region];
                }
            }
            ptr+=4;
        }
    }
    
    NSMutableSet *set = [NSMutableSet setWithArray:subregions];
    
//     Initial pass through regions to find regions entirely contained in other regions
    for (SPBorderedView *region in subregions)
    {
        if ([region numberOfPoints] < MIN_POINTS_PER_SUBREGION)
        {
            [set removeObject:region];
        }
        else
        {
            for (SPBorderedView *cregion in subregions)
            {
                if ([set containsObject:cregion] && [set containsObject:region] && cregion != region)
                {
                    if (CGRectContainsRect([cregion bounds], [region bounds]))
                    {
                        [set removeObject:region];
                        break;
                    }
                }
            }
        }
    }
    
    // Pass through regions to find some to combine that yield smaller areas
    int reduce = [set count]-max;
    int loopmax = [set count]-1;
    //    for (int c=0; c<loopmax; c++)
    //    {
    //        NSMutableArray *allObjects = [[set allObjects] mutableCopy];
    //        [allObjects shuffle];
    //        for (FCRegion *r1 in allObjects)
    //        {
    //            if ([set containsObject:r1])
    //            {
    //                for (int compare=[allObjects indexOfObject:r1]+1; compare < [allObjects count]; compare++)
    //                {
    //                    FCRegion *r2 = [allObjects objectAtIndex:compare];
    //                    if ([set containsObject:r2])
    //                    {
    //                        CGFloat comboArea = [r1 unionAreaWithBounds:[r2 bounds]];
    //                        CGFloat sumArea = [r1 area] + [r2 area];
    //                        if (sumArea > comboArea)
    //                        {
    //                            [r1 mergeWithRegion:r2];
    //                            [set removeObject:r2];
    //                        }
    //                    }
    //                }
    //            }
    //        }
    //    }
    
    // main optimization loop -- reduce to find the bare minimum
    reduce = [set count]-max;
    loopmax = [set count]-1;
    for (int c=0; c<loopmax; c++)
    {
        NSMutableArray *allObjects = [[set allObjects] mutableCopy];
        [allObjects shuffle];
        CGFloat minArea = -1;
        SPBorderedView *min1=nil, *min2=nil;
        for (SPBorderedView *r1 in allObjects)
        {
            for (int compare=[allObjects indexOfObject:r1]+1; compare < [allObjects count]; compare++)
            {
                SPBorderedView *r2 = [allObjects objectAtIndex:compare];
                CGFloat comboArea = [r1 unionAreaWithFrame:[r2 cgrect]];
                if (c < reduce && (comboArea < minArea || minArea < 0))
                {
                    minArea = comboArea;
                    min1 = r1;
                    min2 = r2;
                }
            }
        }
        if (min1 && min2)
        {
            [min1 mergeWithRegion:min2];
            [set removeObject:min2];
        }
    }
    
    // Another pass through remaining regions to find some to combine that yield smaller areas
    reduce = [set count]-max;
    loopmax = [set count]-1;
    for (int c=0; c<loopmax; c++)
    {
        NSMutableArray *allObjects = [[set allObjects] mutableCopy];
        [allObjects shuffle];
        for (SPBorderedView *r1 in allObjects)
        {
            for (int compare=[allObjects indexOfObject:r1]+1; compare < [allObjects count]; compare++)
            {
                SPBorderedView *r2 = [allObjects objectAtIndex:compare];
                CGFloat comboArea = [r1 unionAreaWithFrame:[r2 cgrect]];
                CGFloat sumArea = [r1 area] + [r2 area];
                if ([set containsObject:r1] && [set containsObject:r2] && sumArea > comboArea)
                {
                    [r1 mergeWithRegion:r2];
                    [set removeObject:r2];
                }
            }
        }
    }
}


- (void) optimizeRegions {
    FCImage *diffImage = [[FCImage alloc] init];
    [diffImage setStorePixelData:self.subregionData];
    diffImage.size = self.imageSize;
    [diffImage setSamplesPerPixel:4];
    for (SPBorderedView *view in self.regionsView.regions) {
        CGRect originalRegion = NSRectToCGRect(view.frame);
        CGRect optimalRegion = [diffImage trimmedFrameWithinRect:[self regionFrameFromView:originalRegion]];
        view.frame = NSRectFromCGRect([self viewFrameFromRegion:optimalRegion]);
    }
}

- (void) setProgressTopMessage:(NSString *)message {
    self.progressTopLabel.stringValue = message;
    [self.progressTopLabel displayIfNeeded];
    [self.progressPanel makeKeyAndOrderFront:self];
}

- (void) setProgressTop:(double)value {
    [self.progressTopIndicator setDoubleValue:value];
    [self.progressTopIndicator displayIfNeeded];
    [self.progressPanel makeKeyAndOrderFront:self];
}

- (void) setProgressTopHidden:(BOOL)hidden {
    self.progressTopLabel.hidden = hidden;
    [self.progressTopLabel displayIfNeeded];
    self.progressTopIndicator.hidden = hidden;
    [self.progressTopIndicator displayIfNeeded];
    [self.progressTopIndicator.superview displayIfNeeded];
}

- (void) setProgressMessage:(NSString *)message {
    self.progressLabel.stringValue = message;
    [self.progressLabel displayIfNeeded];
    [self.progressPanel makeKeyAndOrderFront:self];
}

- (void) setProgress:(double)value {
    [self.progressIndicator setDoubleValue:value];
    [self.progressIndicator displayIfNeeded];
    [self.progressPanel makeKeyAndOrderFront:self];
}

- (NSInteger) frameRate {
    NSInteger frameRate = [self.framerateField intValue];
    if (frameRate <= 0) {
        frameRate = DEFAULT_FRAMERATE;
    }
    return frameRate;
}

- (void) exportFrames {
    [self setProgress:0.0];
    [self setProgressMessage:@"Reticulating splines"];
    [self.progressPanel setIsVisible:YES];
    BOOL imageBatchExport = self.exportForImageBatch.state == NSOnState;
    NSString *bundle = (imageBatchExport ? @"" : @"bundle://");
    BOOL subregions = ([self subregionsCount] > 0);
    [self setProgressTopHidden:!subregions];

    NSString *baseFileName = [[self.firstImage.sourceFile lastPathComponent] stringByDeletingPathExtension];
    baseFileName = [baseFileName stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789"]];
    NSMutableString * frameSequence = [NSMutableString string];
    
    // Create the export directory
    NSString *exportDirectory = [self.directoryPath stringByAppendingPathComponent:@"export"];
    [[NSFileManager defaultManager] removeItemAtPath:exportDirectory error:NULL];
    [[NSFileManager defaultManager] createDirectoryAtPath:exportDirectory
                              withIntermediateDirectories:NO
                                               attributes:NULL
                                                    error:NULL];
    NSString *regionsSnippet = @"";

    // base image if subregions
    if (subregions) {
        CGPoint min = CGPointZero;
        CGPoint max = CGPointMake(self.firstImage.size.width, self.firstImage.size.height);
        FCImage *baseImage = [[FCImage alloc] initWithSource:self.firstImage.sourceFile];
        for (NSView *region in [self subregions])
        {
            CGRect holeRect = NSRectToCGRect(region.frame);
            if (holeRect.size.width > 2.f) {
                holeRect.size.width -= 2.f;
                holeRect.origin.x += 1;
            }
            if (holeRect.size.height > 2.f) {
                holeRect.size.height -= 2.f;
                holeRect.origin.y += 1;
            }
            if (holeRect.size.height > 1.f && holeRect.size.width > 1.f) {
                [baseImage makeTransparentRect:holeRect];
            }
        }
        NSString *fileName = [baseFileName stringByAppendingString:@"base"];
        NSString *fullFileName = [exportDirectory stringByAppendingPathComponent:fileName];
        [baseImage exportImageWithFormat:self.exportMatrix.selectedRow toFileName:fullFileName queue:self.queue cropped:YES toMin:min max:max];
        
        fileName = [fileName stringByAppendingPathExtension:[baseImage extensionForExportFormat:self.exportMatrix.selectedRow]];
        regionsSnippet = [regionsSnippet stringByAppendingFormat:@"<Image bounds=\"0,0,%d,%d\" urlPath=\"%@%@\">\n", (int)(self.imageSize.width), (int)(self.imageSize.height), bundle, fileName];
    }
    
    NSMutableArray *processedImages = [NSMutableArray array];
    NSMutableArray *uniqueImages = [NSMutableArray array];
    NSInteger imageIndex = 0;
    int currentRegion = 0;
    CGPoint min = globalFrame.origin;
    CGPoint max = CGPointMake(globalFrame.size.width + min.x, globalFrame.size.height + min.y);
    do {
        [uniqueImages removeAllObjects];
        imageIndex = 0;
        SPBorderedView *region = nil;
        NSString *suffix = @"";
        NSRect cropFrame;
        if (subregions) {
            double doneness = (1.0+currentRegion)/(1.0*[self subregionsCount]);
            [self setProgressTop:doneness];
            [self setProgressTopMessage:[NSString stringWithFormat:@"Processing region %ld/%ld", (long)currentRegion+1, (long)[self subregionsCount]]];
            subregions = YES;
            region = [self.subregions objectAtIndex:currentRegion];
            cropFrame = region.frame;
            CGSize imgSize = [self imageSize];
            min.x = cropFrame.origin.x;
            min.y = imgSize.height - cropFrame.origin.y - cropFrame.size.height;
            max.x = cropFrame.origin.x + cropFrame.size.width;
            max.y = min.y + cropFrame.size.height;
            suffix = [NSString stringWithFormat:@"region%02d_",currentRegion];
            NSString *fileName = [baseFileName stringByAppendingFormat:@"%@0000",suffix];
            fileName = [fileName stringByAppendingPathExtension:[self.firstImage extensionForExportFormat:[self.exportMatrix selectedRow]]];
            regionsSnippet = [regionsSnippet stringByAppendingFormat:@"\t<Image bounds=\"%d,%d,%d,%d\" urlPath=\"%@%@\">\n", (int)(cropFrame.origin.x), (int)(cropFrame.origin.y), (int)(cropFrame.size.width), (int)(cropFrame.size.height), bundle, fileName];
        }
        
        NSMutableArray *iterator = [NSMutableArray array];
        if (self.timelineView.zones.count > 0) {
            for (SPBorderedView *zone in self.timelineView.zones) {
                [iterator addObjectsFromArray:zone.data];
            }
        } else {
            [iterator addObjectsFromArray:self.allImages];
        }
        
        [processedImages removeAllObjects];
        for (FCImage *newImage in iterator) {
            @autoreleasepool {
                [self setProgress:((double)imageIndex/(double)[self.allFiles count])];
                if (subregions) {
                    [self setProgressMessage:[NSString stringWithFormat:@"Region %d/%ld %@", currentRegion+1, [self subregionsCount], [newImage.sourceFile lastPathComponent]]];
                } else {
                    [self setProgressMessage:[NSString stringWithFormat:@"Processing %@", [newImage.sourceFile lastPathComponent]]];
                }

                FCImage *duplicateOfImage = NULL;
                
                newImage.index = imageIndex++;
                
                if([self shouldRemoveDuplicateFrames]) {
                    // Check to see if another frame is like this frame.
                    for(FCImage * existingImage in uniqueImages) {
                        @autoreleasepool {
                            if (subregions) {
                                if ([newImage compare:existingImage pixelsWithMin:min andMax:max]) {
                                    // NSLog(@"DUPLICATE: %@ and %@", [newImage.sourceFile lastPathComponent], [existingImage.sourceFile lastPathComponent]);
                                    duplicateOfImage = existingImage;
                                    [newImage dropMemory];
                                    [existingImage dropMemory];
                                    break;
                                }
                            }
                            else if([newImage compare:existingImage]) {
                                // NSLog(@"DUPLICATE: %@ and %@", [newImage.sourceFile lastPathComponent], [existingImage.sourceFile lastPathComponent]);
                                duplicateOfImage = existingImage;
                                [newImage dropMemory];
                                [existingImage dropMemory];
                                break;
                            }
                            [newImage dropMemory];
                            [existingImage dropMemory];
                        }
                    }
                }

                if(duplicateOfImage) {
                    newImage.index = duplicateOfImage.index;
                } else {
                    [uniqueImages addObject:newImage];
                }
                [processedImages addObject:newImage];
            }
        }

        // Translate the indices in processedImages to their uniqueImages equivalents
        for(FCImage * image in processedImages) {
            FCImage * otherImage = [processedImages objectAtIndex:image.index];
            image.index = [uniqueImages indexOfObject:otherImage];
            [image dropMemory];
        }
        
        [iterator removeAllObjects];
        if (self.timelineView.zones.count > 0) {
            for (SPBorderedView *zone in self.timelineView.zones) {
                [iterator addObject:[NSMutableArray arrayWithArray:zone.data]];
            }
        } else {
            [iterator addObject:self.allImages];
        }
        
        BOOL shorten = YES;
        for (NSMutableArray *zoneImages in iterator) {
            [frameSequence setString:@""];
            for(int i = 0; i < [zoneImages count]; i++) {
                FCImage * image = [zoneImages objectAtIndex:i];
                BOOL didConversion = NO;
                
                if (shorten) {
                    // Detect runs of the same number...
                    for(int j = i+1; j < [zoneImages count]; j++) {
                        FCImage * nextImage = [zoneImages objectAtIndex:j];
                        if (nextImage.index < 0) {
                            NSLog(@"yikes");
                        }
                        if(nextImage.index != image.index || j+1 >= [zoneImages count]) {
                            if(j-i > 1) {
                                [frameSequence appendFormat:@"%d*%d,", (int)image.index, j-i];
                                i = j-1;
                                didConversion = YES;
                            }
                            break;
                        }
                    }
                    if(didConversion) {
                        continue;
                    }
                    // Detect runs of incremental number...
                    for(int j = i+1; j < [zoneImages count]; j++) {
                        FCImage * nextImage = [zoneImages objectAtIndex:j];
                        FCImage * prevImage = [zoneImages objectAtIndex:j-1];
                        
                        if(nextImage.index != prevImage.index+1 || j+1 >= [zoneImages count]) {
                            if(prevImage.index-image.index > 1) {
                                [frameSequence appendFormat:@"%d-%d,", (int)image.index, (int)prevImage.index];
                                i = j-1;
                                didConversion = YES;
                            }
                            break;
                        }
                    }
                    if(didConversion) {
                        continue;
                    }
                }
                [frameSequence appendFormat:@"%d,", (int)image.index];
            }
            
            if(subregions) {
                NSString *pathFormat = [NSString stringWithFormat:@"%@%@#", baseFileName, suffix];
                pathFormat = [pathFormat stringByAppendingPathExtension:[self.firstImage extensionForExportFormat:self.exportMatrix.selectedRow]];
                regionsSnippet = [regionsSnippet stringByAppendingFormat:@"\t\t<FrameAnimation subscribe=\"note%lu\" framerate=\"%ld\" sequence=\"%@\" pathFormat=\"%@%@\" digits=\"4\" />\n", (unsigned long)[iterator indexOfObject:zoneImages], [self frameRate], frameSequence, bundle, pathFormat];
                NSLog(@"regionsSnippet = %@", regionsSnippet);
            }
        }
    
        // Export all of the images
        for(FCImage * image in uniqueImages) {
            NSString * fileName = [[[image sourceFile] lastPathComponent] stringByDeletingPathExtension];
            
            if (subregions) {
                fileName = [fileName stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789"]];
                fileName = [baseFileName stringByAppendingString:suffix];
                fileName = [exportDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%04d", fileName, (int)image.index]];
            } else if([self shouldRemoveDuplicateFrames]) {
                fileName = [fileName stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789"]];
                fileName = [exportDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%04d", fileName, (int)image.index]];
            } else {
                fileName = [exportDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@", fileName]];
            }
            
            [image exportImageWithFormat:self.exportMatrix.selectedRow toFileName:fileName queue:self.queue cropped:YES toMin:min max:max];
        }
        
        while([self.queue operationCount])
        {
            usleep(50000);
            NSLog(@"progress = %f",((double)[self.queue operationCount]/(double)[uniqueImages count]));
            [self setProgress:1.0f - ((double)([self.queue operationCount]+1)/(double)[uniqueImages count])];
        }
        
        if (subregions) {
            regionsSnippet = [regionsSnippet stringByAppendingString:@"\t</Image>\n"];
        }
        
    } while (++currentRegion < [self subregionsCount]);
    
    if(subregions) {
        regionsSnippet = [regionsSnippet stringByAppendingString:@"</Image>"];
        [regionsSnippet writeToFile:[exportDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"regions.xml"]]
                         atomically:NO
                           encoding:NSUTF8StringEncoding
                              error:NULL];
        
        [frameSequence writeToFile:[exportDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"sequence.txt"]]
                        atomically:NO
                          encoding:NSUTF8StringEncoding
                             error:NULL];
    } else if ([self shouldRemoveDuplicateFrames]) {
        NSString *bounds = [NSString stringWithFormat:@"%d,%d,%d,%d", (int)(min.x), (int)(min.y), (int)(max.x-min.x), (int)(max.y-min.y)];
        
        [bounds writeToFile:[exportDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"bounds.txt"]]
                 atomically:NO
                   encoding:NSUTF8StringEncoding
                      error:NULL];
        
        [frameSequence writeToFile:[exportDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"sequence.txt"]]
                        atomically:NO
                          encoding:NSUTF8StringEncoding
                             error:NULL];
    }
    
    [self.progressPanel setIsVisible:NO];
}

#pragma mark - Toolbar item callbacks

- (IBAction) loadCallback:(id)sender {
    [self showLoadFramesSheet];
}

- (IBAction) playCallback:(id)sender {
    [self play];
}

- (IBAction) processCallback:(id)sender {
    [self processFrames];
}

- (IBAction) generateCallback:(id)sender {
    [self autogenerateMaxSubregions:100];
}

- (IBAction) toggleCallback:(id)sender {
    self.maskView.hidden = !self.maskView.isHidden;
    self.regionsView.hidden = self.maskView.isHidden;
}

- (IBAction) editCallback:(id)sender {
    NSLog(@"iV.f: %@  (%.0f, %0.f)", NSStringFromRect(self.regionsView.frame), self.imageSize.width, self.imageSize.height);
    NSLog(@"rV.f: %@", NSStringFromRect(self.regionsView.frame));

    [self optimizeRegions];
    [self.regionsView optimize];
}

- (IBAction) resetCallback:(id)sender {
    [self resetRegions];
}

- (IBAction) resetZonesCallback:(id)sender {
    [self resetZones];
}

- (IBAction) exportCallback:(id)sender {
    [self exportFrames];
}

- (BOOL) shouldRemoveDuplicateFrames {
    return self.removeDuplicateFrames.state;
}

- (NSString *) temporaryFilename {
    NSString *pathComponent = [NSString stringWithFormat:@"framecleaner_%@", [self.directoryPath lastPathComponent]];
    NSString *tempFileTemplate = [NSTemporaryDirectory() stringByAppendingPathComponent:pathComponent];
    const char *tempFileTemplateCString = [tempFileTemplate fileSystemRepresentation];
    char *tempFileNameCString = (char *)malloc(strlen(tempFileTemplateCString) + 1);
    strcpy(tempFileNameCString, tempFileTemplateCString);
    int fileDescriptor = mkstemp(tempFileNameCString);
    if (fileDescriptor == -1) {
        // handle file creation failure
    }
    return [[NSFileManager defaultManager] stringWithFileSystemRepresentation:tempFileNameCString length:strlen(tempFileNameCString)];
}

#pragma mark - Document lifetime

- (id)init
{
    self = [super init];
    if (self) {
        self.queue = [[NSOperationQueue alloc] init];
        self.queue.maxConcurrentOperationCount = 1;
    }
    return self;
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"SPDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];
    self.hasUndoManager = YES;

/*    if (NSAppKitVersionNumber > NSAppKitVersionNumber10_9) {
        NSWindow *window = [self windowForSheet];
        NSView *mainView = [[window.contentView subviews] objectAtIndex:0];
        NSView *firstView = [[mainView subviews] objectAtIndex:0];
        NSVisualEffectView *blur = [[NSVisualEffectView alloc] initWithFrame:mainView.frame];
        
        blur.material = NSVisualEffectMaterialLight;
        blur.blendingMode = NSVisualEffectBlendingModeBehindWindow;
        [mainView addSubview:blur positioned:NSWindowBelow relativeTo:firstView];

//        NSLayoutConstraint *c1 = [NSLayoutConstraint constraintWithItem:blur attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:blur.superview attribute:NSLayoutAttributeWidth multiplier:1.0 constant:0.f];
//        [c1 setPriority:500];
//        [mainView addConstraint:c1];
//        NSLayoutConstraint *c2 = [NSLayoutConstraint constraintWithItem:mainView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:mainView.superview attribute:NSLayoutAttributeWidth multiplier:1.0 constant:0.f];
//        [c2 setPriority:1000];
//        [mainView.superview addConstraint:c2];
//
//        NSLayoutConstraint *cL = [NSLayoutConstraint constraintWithItem:blur attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:firstView attribute:NSLayoutAttributeLeft multiplier:1.f constant:0.f];
//        NSLayoutConstraint *cR = [NSLayoutConstraint constraintWithItem:blur attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:firstView attribute:NSLayoutAttributeRight multiplier:1.f constant:0.f];
//        NSLayoutConstraint *cT = [NSLayoutConstraint constraintWithItem:blur attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:firstView attribute:NSLayoutAttributeTop multiplier:1.f constant:0.f];
//        NSLayoutConstraint *cB = [NSLayoutConstraint constraintWithItem:blur attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:firstView attribute:NSLayoutAttributeBottom multiplier:1.f constant:0.f];
//        [firstView addConstraints:@[cL, cR, cT, cB]];
    }*/
    
    if (self.settings) {
        [self.regionsView.superview setNeedsLayout:YES];
        [self performSelector:@selector(setDocumentSettings:) withObject:self.settings afterDelay:0];
    }
    self.imageView.layer.zPosition = 0;
    self.maskView.layer.zPosition = 10;
    self.regionsView.layer.zPosition = 20;
    self.timelineView.document = self;
    self.regionsView.document = self;
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

- (NSDictionary *)documentSettings {
    return @{@"directoryPath": self.directoryPath,
             @"shouldTrimImages": @(self.shouldTrimImages),
             @"removeDuplicateFrames": @(self.removeDuplicateFrames.state == NSOnState),
             @"exportForImageBatch": @(self.exportForImageBatch.state == NSOnState),
             @"compareWithMD5": @(self.compareWithMD5),
             @"exportFormatIndex": @(self.exportMatrix.selectedRow),
             @"frameRate": self.framerateField.stringValue,
             @"regions": [self.regionsView regionsArrayForPlist],
             @"zones": [self.timelineView zonesArrayForPlist]};
}

- (void)setDocumentSettings:(NSDictionary *)settings {
    self.directoryPath = settings[@"directoryPath"];
    self.shouldTrimImages = [settings[@"shouldTrimImages"] boolValue];
    self.removeDuplicateFrames.state = ([settings[@"removeDuplicateFrames"] boolValue] ? NSOnState : NSOffState);
    self.exportForImageBatch.state = ([settings[@"exportForImageBatch"] boolValue] ? NSOnState : NSOffState);
    self.compareWithMD5 = [settings[@"shouldTrimImages"] boolValue];
    if (settings[@"frameRate"]) {
        self.framerateField.stringValue = settings[@"frameRate"];
    }
    [self.exportMatrix selectCellAtRow:[settings[@"exportFormatIndex"] integerValue] column:0];
    [self loadFrames];
    [self.regionsView setRegionsArrayFromPlist:settings[@"regions"]];
    [self.timelineView setZonesArrayFromPlist:settings[@"zones"]];
    [self drawMask];
}

- (NSFileWrapper *)fileWrapperOfType:(NSString *)typeName error:(NSError **)outError {
    NSData *settingsData = [NSKeyedArchiver archivedDataWithRootObject:[self documentSettings]];
    NSFileWrapper *settingsWrapper = [[NSFileWrapper alloc] initRegularFileWithContents:settingsData];
    NSFileWrapper *maskWrapper = [[NSFileWrapper alloc] initRegularFileWithContents:self.subregionData];

    NSFileWrapper *mainWrapper = [[NSFileWrapper alloc] initDirectoryWithFileWrappers:@{@"settings": settingsWrapper, @"subregionData": maskWrapper}];
    return mainWrapper;
}

- (BOOL)readFromFileWrapper:(NSFileWrapper *)fileWrapper ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError {
    NSFileWrapper *settingsWrapper = [[fileWrapper fileWrappers] objectForKey:@"settings"];
    self.settings = [NSKeyedUnarchiver unarchiveObjectWithData:[settingsWrapper regularFileContents]];
    self.subregionData = [[[[fileWrapper fileWrappers] objectForKey:@"subregionData"] regularFileContents] mutableCopy];
    return YES;
}

//- (BOOL)writeToURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError {
//    NSArray *regionsArray = [self.regionsView regionsArrayForPlist];
//    [regionsArray writeToURL:[url URLByAppendingPathComponent:@"regions.plist"] atomically:YES];
//    return YES;
//}

//- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
//{
//    // Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
//    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
//    NSException *exception = [NSException exceptionWithName:@"UnimplementedMethod" reason:[NSString stringWithFormat:@"%@ is unimplemented", NSStringFromSelector(_cmd)] userInfo:nil];
//    @throw exception;
//    return nil;
//}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning NO.
    // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
    // If you override either of these, you should also override -isEntireFileLoaded to return NO if the contents are lazily loaded.
    NSException *exception = [NSException exceptionWithName:@"UnimplementedMethod" reason:[NSString stringWithFormat:@"%@ is unimplemented", NSStringFromSelector(_cmd)] userInfo:nil];
    @throw exception;
    return YES;
}

@end
