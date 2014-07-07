//
//  SPDocument.m
//  FrameCleaner
//
//  Created by Quinn McHenry on 7/7/14.
//  Copyright (c) 2014 Small Planet. All rights reserved.
//

#import "SPDocument.h"
#import "FCImage.h"

@implementation SPDocument



#pragma mark -


- (void) exportImage:(FCImage*)image toFileName:(NSString*)fileName queue:(NSOperationQueue*)_queue withExportMatrix:(NSInteger)selectedRow
{
    switch(selectedRow)
    {
        case 0:
            [image exportPNGTo:fileName
                     withQueue:_queue];
            break;
        case 1:
            [image exportLZ4To:fileName
                     withQueue:_queue];
            break;
        case 2:
            [image exportPVRPhotoTo:fileName
                          withQueue:_queue];
            break;
        case 3:
            [image exportPVRGradientTo:fileName
                             withQueue:_queue];
            break;
        case 4:
            [image exportPNGQuantTo:fileName
                          withQueue:_queue
                      withTableSize:256];
            break;
        case 5:
            [image exportPNGQuantTo:fileName
                          withQueue:_queue
                      withTableSize:128];
            break;
        case 6:
            [image exportPNGQuantTo:fileName
                          withQueue:_queue
                      withTableSize:64];
            break;
        case 7:
            [image exportSP1To:fileName
                     withQueue:_queue
                 withTableSize:64];
            break;
    }
    
}

- (NSString *) extensionForExportMatrix:(NSInteger)selectedRow
{
    switch(selectedRow)
    {
        case 0:
        case 4:
        case 5:
        case 6:
        case 7:
            return @"png";
            break;
        case 1:
            return @"lz4";
            break;
        case 2:
        case 3:
            return @"pvr";
            break;
    }
    return @"";
}

- (void) loadFrames {
    self.allFiles = [NSMutableArray arrayWithArray:[[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.directoryPath error:NULL]];
}

- (void) showLoadFramesSheet {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles=NO;
    panel.canCreateDirectories=YES;
    panel.canChooseDirectories=YES;
    
    __weak typeof(panel) bpanel = panel;
    [panel beginSheetModalForWindow:self.windowForSheet completionHandler:^(NSInteger result) {
        if (result == 1 && bpanel.URLs.count > 0) {
            self.directoryPath = [bpanel.URLs objectAtIndex:0];
            [self loadFrames];
        }
    }];

}

#pragma mark - Toolbar item callbacks

- (IBAction) loadCallback:(id)sender {
    [self showLoadFramesSheet];
}

- (IBAction) processCallback:(id)sender {
    
}

- (IBAction) editCallback:(id)sender {
    
}

- (IBAction) exportCallback:(id)sender {
    
}



#pragma mark - Document lifetime

- (id)init
{
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
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
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
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
