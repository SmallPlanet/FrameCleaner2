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

@implementation SPDocument



#pragma mark -

- (void) resetRegions {
    [self.regionsView reset];
}

- (void) loadFrames {
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.directoryPath error:NULL];
    self.allFiles = [NSMutableArray array];
    for (NSString *file in contents) {
        if ([file hasSuffix:@".png"]) {
            [self.allFiles addObject:file];
        }
    }
    self.allImages = nil;
    self.maskView.image = nil;
    self.imageSize = CGSizeZero;
    [self.regionsView reset];
    
    // show first image
    if (self.allFiles.count > 0) {
        NSString *filePath = [self.directoryPath stringByAppendingPathComponent:self.allFiles[0]];
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

- (void) processFrames {
    globalFrame = CGRectZero;
    
    if (!self.allImages) {
        self.allImages = [NSMutableArray array];
        for (NSString *filename in self.allFiles) {
            NSString *filePath = [self.directoryPath stringByAppendingPathComponent:filename];
            if ([filePath hasSuffix:@".png"]) {
                FCImage *image = [[FCImage alloc] initWithSource:filePath];
                if (image) {
                    [self.allImages addObject:image];
                }
            }
        }
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
            } else {
                NSData *diff = [firstImage subtract:image];
                unsigned char * ptr1 = (unsigned char*)[self.subregionData bytes];
                unsigned char * ptr2 = (unsigned char*)[diff bytes];
                
                for(int i=0; i<[self.subregionData length]; i++) {
                    if (*ptr2 > *ptr1) {
                        *ptr1 = *ptr2;
                    }
                    ptr1++;
                    ptr2++;
                }
            }
        }
//        [FCImage dumpData:self.subregionData size:firstImage.size];
        [FCImage writeMaskImageFromData:self.subregionData size:firstImage.size toPath:@"/tmp/mask.png"];
        self.maskView.image = [[NSImage alloc] initWithContentsOfFile:@"/tmp/mask.png"];
    }
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

- (NSArray *) subregions {
    return self.regionsView.regions;
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

- (void) exportFrames {
    NSString *baseFileName = [[self.firstImage.sourceFile lastPathComponent] stringByDeletingPathExtension];
    baseFileName = [baseFileName stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789"]];
    
    // Create the export directory
    NSString *exportDirectory = [self.directoryPath stringByAppendingPathComponent:@"export"];
    
    [[NSFileManager defaultManager] removeItemAtPath:exportDirectory error:NULL];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:exportDirectory
                              withIntermediateDirectories:NO
                                               attributes:NULL
                                                    error:NULL];

    
    NSString *regionsSnippet = @"";

    // base image if subregions
    if ([self subregionsCount] > 0) {
        CGPoint min = CGPointZero;
        CGPoint max = CGPointMake(self.firstImage.size.width, self.firstImage.size.height);
        FCImage *baseImage = [[FCImage alloc] initWithSource:self.firstImage.sourceFile];
        for (NSView *region in [self subregions])
        {
            [baseImage makeTransparentRect:NSRectToCGRect(region.frame)];
//            [region expandBoundsBy:1.f toMaxSize:firstImage.size];
        }
        NSString *fileName = [baseFileName stringByAppendingString:@"base"];
        NSString *fullFileName = [exportDirectory stringByAppendingPathComponent:fileName];
        [baseImage exportImageWithFormat:self.exportMatrix.selectedRow toFileName:fullFileName queue:self.queue cropped:YES toMin:min max:max];
        
        fileName = [fileName stringByAppendingPathExtension:[baseImage extensionForExportFormat:self.exportMatrix.selectedRow]];
        regionsSnippet = [regionsSnippet stringByAppendingFormat:@"<Image bounds=\"0,0,%d,%d\" urlPath=\"bundle://%@\">\n", (int)(self.imageSize.width), (int)(self.imageSize.height), fileName];
    }
    
    NSMutableArray *processedImages = [NSMutableArray array];
    NSMutableArray *uniqueImages = [NSMutableArray array];
    NSInteger imageIndex = 0;
    int currentRegion = 0;
    CGPoint min, max;
    BOOL subregions = NO;
    do {
        imageIndex = 0;
        
        SPBorderedView *region = nil;
        NSString *suffix = @"";
        NSRect cropFrame;
        if ([self subregionsCount] > 0) {
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
            regionsSnippet = [regionsSnippet stringByAppendingFormat:@"\t<Image bounds=\"%d,%d,%d,%d\" urlPath=\"%@\">\n", (int)(cropFrame.origin.x), (int)(cropFrame.origin.y), (int)(cropFrame.size.width), (int)(cropFrame.size.height), [NSString stringWithFormat:@"bundle://%@",fileName]];
        }
        
        [processedImages removeAllObjects];
        [uniqueImages removeAllObjects];

        for(FCImage *newImage in self.allImages) {
            @autoreleasepool {
                if (subregions) {
//                    [transWindow continueProgressBarMessage:[NSString stringWithFormat:@"Region %d/%d %@", currentRegion, [subregions count], [newImage.sourceFile lastPathComponent]]
//                                                  withValue:((float)imageIndex/(float)[allFiles count])];
                }
                else
                {
//                    [transWindow continueProgressBarMessage:[NSString stringWithFormat:@"Processing %@", [newImage.sourceFile lastPathComponent]]
//                                                  withValue:((float)imageIndex/(float)[allFiles count])];
                }

                FCImage *duplicateOfImage = NULL;
                
                newImage.index = imageIndex++;
                
                if([self shouldRemoveDuplicateFrames]) {
                    // Check to see if another frame is like this frame.
                    for(FCImage * existingImage in uniqueImages) {
                        @autoreleasepool {
                            if (subregions) {
                                if ([newImage compare:existingImage pixelsWithMin:min andMax:max]) {
                                    NSLog(@"DUPLICATE: %@ and %@", [newImage.sourceFile lastPathComponent], [existingImage.sourceFile lastPathComponent]);
                                    duplicateOfImage = existingImage;
                                    [newImage dropMemory];
                                    [existingImage dropMemory];
                                    break;
                                }
                            }
                            else if([newImage compare:existingImage]) {
                                NSLog(@"DUPLICATE: %@ and %@", [newImage.sourceFile lastPathComponent], [existingImage.sourceFile lastPathComponent]);
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
                }
                else {
                    [uniqueImages addObject:newImage];
                }
                
                [processedImages addObject:newImage];
            }
        }
//
//        // Translate the indices in processedImages to their uniqueImages equivalents
//        for(FCImage * image in processedImages)
//        {
//            FCImage * otherImage = [processedImages objectAtIndex:image.index];
//            image.index = [uniqueImages indexOfObject:otherImage];
//            [image dropMemory];
//        }
//        
//        NSMutableString * frameSequence = [NSMutableString string];
//        for(int i = 0; i < [processedImages count]; i++)
//        {
//            FCImage * image = [processedImages objectAtIndex:i];
//            BOOL didConversion = NO;
//            
//            // Detect runs of the same number...
//            for(int j = i+1; j < [processedImages count]; j++)
//            {
//                FCImage * nextImage = [processedImages objectAtIndex:j];
//                
//                if(nextImage.index != image.index || j+1 >= [processedImages count])
//                {
//                    if(j-i > 1)
//                    {
//                        [frameSequence appendFormat:@"%d*%d,", (int)image.index, j-i];
//                        i = j-1;
//                        didConversion = YES;
//                    }
//                    break;
//                }
//            }
//            if(didConversion) continue;
//            
//            // Detect runs of incremental number...
//            for(int j = i+1; j < [processedImages count]; j++)
//            {
//                FCImage * nextImage = [processedImages objectAtIndex:j];
//                FCImage * prevImage = [processedImages objectAtIndex:j-1];
//                
//                if(nextImage.index != prevImage.index+1 || j+1 >= [processedImages count])
//                {
//                    if(prevImage.index-image.index > 1)
//                    {
//                        [frameSequence appendFormat:@"%d-%d,", (int)image.index, (int)prevImage.index];
//                        i = j-1;
//                        didConversion = YES;
//                    }
//                    break;
//                }
//            }
//            if(didConversion) continue;
//            
//            
//            
//            [frameSequence appendFormat:@"%d,", (int)image.index];
//        }
//        
//        // Export all of the images
//        
//        for(FCImage * image in uniqueImages)
//        {
//            NSString * fileName = [[[image sourceFile] lastPathComponent] stringByDeletingPathExtension];
//            
//            if (findSubregionsMax > 0)
//            {
//                fileName = [fileName stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789"]];
//                fileName = [baseFileName stringByAppendingString:suffix];
//                fileName = [exportDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%04d", fileName, (int)image.index]];
//            }
//            else if(gShouldRemoveDuplicates)
//            {
//                fileName = [fileName stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789"]];
//                fileName = [exportDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%04d", fileName, (int)image.index]];
//            }
//            else
//            {
//                fileName = [exportDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@", fileName]];
//            }
//            
//            [self exportImage:image toFileName:fileName queue:queue withExportMatrix:[exportMatrix selectedRow]];
//        }
//        
//        while([queue operationCount])
//        {
//            usleep(50000);
//            
//            [transWindow continueProgressBarMessage:[NSString stringWithFormat:@"Exporting Images..."]
//                                          withValue:1.0f - ((float)[queue operationCount]/(float)[uniqueImages count])];
//        }
//        
//        
//        if(findSubregionsMax > 0)
//        {
//            NSString *pathFormat = [NSString stringWithFormat:@"%@%@#", baseFileName, suffix];
//            pathFormat = [pathFormat stringByAppendingPathExtension:[self extensionForExportMatrix:[exportMatrix selectedRow]]];
//            regionsSnippet = [regionsSnippet stringByAppendingFormat:@"\t\t<FrameAnimation framerate=\"12\" sequence=\"%@\" pathFormat=\"bundle://%@\" digits=\"4\" />\n\t</Image>\n", frameSequence, pathFormat];
//        }
//        else if (gShouldRemoveDuplicates)
//        {
//            NSString *bounds = [NSString stringWithFormat:@"%d,%d,%d,%d", (int)(globalMin.x), (int)(globalMin.y), (int)(globalMax.x-globalMin.x), (int)(globalMax.y-globalMin.y)];
//            
//            [bounds writeToFile:[exportDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"bounds.txt"]]
//                     atomically:NO
//                       encoding:NSUTF8StringEncoding
//                          error:NULL];
//            
//            [frameSequence writeToFile:[exportDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"sequence.txt"]]
//                            atomically:NO
//                              encoding:NSUTF8StringEncoding
//                                 error:NULL];
//        }
        currentRegion++;
    } while (currentRegion < [self subregionsCount]);
    
}

#pragma mark - Toolbar item callbacks

- (IBAction) loadCallback:(id)sender {
    [self showLoadFramesSheet];
}

- (IBAction) processCallback:(id)sender {
    [self processFrames];
}

- (IBAction) editCallback:(id)sender {
    NSLog(@"iV.f: %@  (%.0f, %0.f)", NSStringFromRect(self.regionsView.frame), self.imageSize.width, self.imageSize.height);
    NSLog(@"rV.f: %@", NSStringFromRect(self.regionsView.frame));

    [self optimizeRegions];
}

- (IBAction) resetCallback:(id)sender {
    [self resetRegions];
}

- (IBAction) exportCallback:(id)sender {
    [self exportFrames];
}

- (BOOL) shouldRemoveDuplicateFrames {
    return self.removeDuplicateFrames.state;
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

//    NSLayoutConstraint *cw = [NSLayoutConstraint constraintWithItem:_imageView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:_regionsView attribute:NSLayoutAttributeWidth multiplier:1.f constant:0.f];
//    NSLayoutConstraint *ch = [NSLayoutConstraint constraintWithItem:_imageView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:_regionsView attribute:NSLayoutAttributeHeight multiplier:1.f constant:0.f];
//    [_regionsView.superview addConstraint:cw];
//    [_regionsView.superview addConstraint:ch];
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
    NSException *exception = [NSException exceptionWithName:@"UnimplementedMethod" reason:[NSString stringWithFormat:@"%@ is unimplemented", NSStringFromSelector(_cmd)] userInfo:nil];
    @throw exception;
    return nil;
}

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
