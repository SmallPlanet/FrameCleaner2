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
        FCImage *tmpImage = [[FCImage alloc] initWithSource:filePath];
        [tmpImage pixelData];
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:filePath];
        image.size = tmpImage.size;
        self.imageSize = tmpImage.size;
        self.imageView.image = image;
//        [self.imageView sizeToFit];
        self.imageView.frame = NSMakeRect(0, 0, image.size.width, image.size.height);
        NSLog(@"iV b4: %@  (%.0f, %0.f)", NSStringFromRect(self.regionsView.frame), image.size.width, image.size.height);
        NSLog(@"rV b4: %@", NSStringFromRect(self.regionsView.frame));
        self.regionsView.frame = self.imageView.frame;
        NSLog(@"rV ar: %@", NSStringFromRect(self.regionsView.frame));
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
    return [self.maxSubregions selectedItem].tag;
}

- (CGRect) viewFrameFromRegion:(CGRect)region {
    return CGRectMake(region.origin.x, self.imageSize.height - region.origin.y - region.size.height, region.size.width, region.size.height);
}

- (CGRect) regionFrameFromView:(CGRect)frame {
    return CGRectMake(frame.origin.x, self.imageSize.height - frame.origin.y - frame.size.height, frame.size.width, frame.size.height);
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
    
}

- (IBAction) exportCallback:(id)sender {
    
}



#pragma mark - Document lifetime

- (id)init
{
    self = [super init];
    if (self) {
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
